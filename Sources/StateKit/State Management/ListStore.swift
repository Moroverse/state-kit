// ListStore.swift
// Copyright (c) 2025 Moroverse
// Created by Daniel Moro on 2025-04-06 16:31 GMT.

import Clocks
import DeveloperToolsSupport
import Foundation
import Observation

/// Represents the source of an image for empty state display.
public enum ImageSource: Equatable, Sendable {
    case system(String)
    case asset(ImageResource)
}

/// An opaque handle to a loading operation that can be cancelled.
///
/// Hides the underlying `Task` while providing cancellation capability,
/// similar to Combine's `AnyCancellable`. Consumers can cancel the operation
/// without accessing the raw `Task` or being able to `await` its value.
///
/// ### Usage Example:
///
/// ```swift
/// case let .inProgress(cancellable, _):
///     cancellable.cancel()
/// ```
public final class Cancellable: Hashable, Sendable {
    private let id: UUID
    private let onCancel: @Sendable () -> Void

    init(id: UUID = UUID(), onCancel: @escaping @Sendable () -> Void) {
        self.id = id
        self.onCancel = onCancel
    }

    /// Cancels the underlying loading operation.
    public func cancel() {
        onCancel()
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: Cancellable, rhs: Cancellable) -> Bool {
        lhs.id == rhs.id
    }
}

/// Represents the various states of an asynchronous list loading operation.
///
/// `ListLoadingState` is an indirect enum that tracks the progression of loading a collection,
/// from idle state through loading, completion, or error states.
///
/// The `Failure` generic parameter preserves the concrete error type, following
/// the `Result<Success, Failure>` pattern.
///
/// ### States:
///
/// - `idle`: Initial state before any loading has been triggered
/// - `empty`: A load completed successfully but returned no results
/// - `inProgress`: Currently loading with a cancellable handle
/// - `loaded`: Successfully loaded with the resulting collection
/// - `error`: Failed to load with typed error information
///
/// - Note: This enum is `indirect` because it contains recursive references to `Self` in the `previousState` parameters.
public indirect enum ListLoadingState<Model, Failure: Error> where Model: RandomAccessCollection {

    /// The initial state before any loading operation has been triggered.
    case idle

    /// The state when a load operation completed successfully but returned no results.
    ///
    /// - Parameters:
    ///   - label: A localized string resource describing the empty state (e.g., "No items found")
    ///   - image: An image source to display alongside the empty state message
    case empty(label: LocalizedStringResource, image: ImageSource)

    /// The loading state when an asynchronous list loading operation is in progress.
    ///
    /// - Parameters:
    ///   - cancellable: A `Cancellable` handle that can be used to abort the operation
    ///   - previousState: The state that was active before loading began, allowing for state recovery
    case inProgress(Cancellable, previousState: Self)

    /// The successful completion state containing the loaded collection and pagination information.
    ///
    /// - Parameters:
    ///   - collection: The successfully loaded collection of type `Model`
    ///   - loadMoreState: The current state of pagination, indicating whether more items can be loaded
    case loaded(Model, loadMoreState: LoadMoreState<Model>)

    /// The error state when list loading fails.
    ///
    /// - Parameters:
    ///   - failure: The typed error that caused the failure
    ///   - previousState: The state that was active before the error occurred, enabling fallback behavior
    case error(Failure, previousState: Self)
}

extension ListLoadingState: Equatable where Model: Equatable, Failure: Equatable {}

/// The state of pagination for a loaded collection.
public enum LoadMoreState<Model> where Model: RandomAccessCollection {
    /// Pagination is not available for this collection.
    case unavailable

    /// Currently loading additional items for pagination.
    case inProgress(Cancellable)

    /// More items are available and ready to be loaded.
    case ready
}

extension LoadMoreState: Equatable {}

/**
 A store for managing asynchronous loading and state management of a collection based on a query.

 `ListStore` is an `@Observable` class that manages the loading state, debounced search,
 query caching, pagination, and optional selection for a collection of items.

 ### Type Parameters:

 - `Model`: A `RandomAccessCollection` of `Identifiable` & `Sendable` elements
 - `Query`: A `Sendable` & `Equatable` type representing the query
 - `Failure`: An `Error` type representing the kind of errors that can occur

 ### Usage Example:

 ```swift
 let store = ListStore<[MyItem], MyQuery, MyError>(
     loader: myLoader,
     queryBuilder: myQueryBuilder
 )

 await store.load()
 ```

 - Note: This class is `@MainActor` and should be used from the main thread.
 */
@MainActor
@Observable
public final class ListStore<Model: RandomAccessCollection, Query: Sendable, Failure: Error>
    where Model: Sendable, Query: Sendable & Equatable, Model.Element: Identifiable, Model.Element: Sendable {
    enum ListStoreError: LocalizedError {
        case invalidModel
        case instanceDeallocated
    }

    public var state: ListLoadingState<Model, Failure>

    private let emptyStateConfiguration: EmptyStateConfiguration
    public var selection: Model.Element.ID? {
        get { selectionManager.selectedID }
        set {
            selectionManager.selectedID = newValue

            if case let .loaded(model, _) = state {
                selectionManager.handleSelection(from: model)
            }
        }
    }

    public var canHandleSelection: Bool {
        selectionManager.canHandleSelection
    }

    private var selectionManager: any SelectionManager<Model.Element>
    private let loader: DataLoader<Query, Model>
    @ObservationIgnored
    private lazy var loadModelDebounce: Debounce<Query, Bool, Model> = Debounce(
        call: { @Sendable [weak self] query, forceReload in
            guard let self else {
                throw ListStoreError.instanceDeallocated
            }
            return try await loadModel(query: query, forceReload: forceReload)
        },
        after: loadingConfiguration.debounceDelay,
        clock: loadingConfiguration.clock
    )

    private var queryBuilder: QueryBuilder<Query>
    @ObservationIgnored
    private var cachedQuery: Query?
    @ObservationIgnored
    private var latestQueryString = ""
    @ObservationIgnored
    private let loadingConfiguration: LoadingConfiguration
    @ObservationIgnored
    private var currentTask: Task<Model, Error>?
    @ObservationIgnored
    private var loadMoreTask: Task<Model, Error>?

    /**
     Initializes a new instance of `ListStore`.

     - Parameters:
       - selection: An optional initial selection ID. Default is `nil`.
       - loadingConfiguration: Configuration for debounce delay and clock. Default is `.default`.
       - emptyStateConfiguration: Configuration for empty state labels and images. Default is `.default`.
       - loader: A closure responsible for loading models asynchronously based on a query.
       - queryBuilder: A closure responsible for constructing a query from a search string.
       - onSelectionChange: An optional callback triggered when selection changes.
     */
    public init(
        selection: Model.Element.ID? = nil,
        loadingConfiguration: LoadingConfiguration = .default,
        emptyStateConfiguration: EmptyStateConfiguration = .default,
        loader: @escaping DataLoader<Query, Model>,
        queryBuilder: @escaping QueryBuilder<Query>,
        onSelectionChange: ((Model.Element?) -> Void)? = nil
    ) {
        self.loadingConfiguration = loadingConfiguration
        self.emptyStateConfiguration = emptyStateConfiguration
        state = .idle
        self.loader = loader
        self.queryBuilder = queryBuilder
        selectionManager = CallbackSelectionManager(onSelectionChange: onSelectionChange)
        self.selection = selection
    }

    /**
     Initializes a new instance of `ListStore` with a query factory.

     Use this initializer when the query does not depend on a search string.

     - Parameters:
       - selection: An optional initial selection ID. Default is `nil`.
       - loadingConfiguration: Configuration for debounce delay and clock. Default is `.default`.
       - emptyStateConfiguration: Configuration for empty state labels and images. Default is `.default`.
       - loader: A closure responsible for loading models asynchronously based on a query.
       - queryFactory: A closure responsible for constructing a query without a search string input.
       - onSelectionChange: An optional callback triggered when selection changes.
     */
    public init(
        selection: Model.Element.ID? = nil,
        loadingConfiguration: LoadingConfiguration = .default,
        emptyStateConfiguration: EmptyStateConfiguration = .default,
        loader: @escaping DataLoader<Query, Model>,
        queryFactory: @escaping QueryFactory<Query>,
        onSelectionChange: ((Model.Element?) -> Void)? = nil
    ) {
        self.loadingConfiguration = loadingConfiguration
        self.emptyStateConfiguration = emptyStateConfiguration
        state = .idle
        self.loader = loader
        self.queryBuilder = { _ in try queryFactory() }
        selectionManager = CallbackSelectionManager(onSelectionChange: onSelectionChange)
        self.selection = selection
    }

    /// Updates the query builder closure used to construct queries from search strings.
    ///
    /// - Parameter builder: The new query builder closure.
    public func updateQueryBuilder(_ builder: @escaping QueryBuilder<Query>) {
        self.queryBuilder = builder
    }

    /**
     Loads models asynchronously based on the current query, with an option to force reload.

     - Parameter forceReload: A boolean flag to force reloading even if the query is cached. Default is false.
     */
    public func load(forceReload: Bool = false) async {
        do {
            let query = try queryBuilder(latestQueryString)
            await load(
                query: query,
                forceReload: forceReload
            )
        } catch {
            if let failure = error as? Failure {
                state = .error(failure, previousState: state)
            }
        }
    }

    /**
     Loads models asynchronously based on the provided query, with an option to force reload.

     - Parameters:
       - query: The query used to load models asynchronously.
       - forceReload: A boolean flag to force reloading even if the query is cached. Default is false.
     */
    public func load(query: Query, forceReload: Bool = false) async {
        do {
            _ = try await loadModelDebounce(query, forceReload)
        } catch is CancellationError {
        } catch {
            if let failure = error as? Failure {
                state = .error(failure, previousState: state)
            }
        }
    }

    @discardableResult
    public func loadModel(query: Query, forceReload: Bool = false) async throws -> Model {
        if !forceReload, let cachedQuery, cachedQuery == query {
            switch state {
            case let .loaded(model, _):
                return model

            case .inProgress:
                if let currentTask {
                    return try await currentTask.value
                }

            default:
                break
            }
        }

        let oldState = state

        let task = Task {
            try Task.checkCancellation()
            let model = try await loader(query)
            try Task.checkCancellation()
            return model
        }

        currentTask = task
        cachedQuery = query
        let cancellable = Cancellable { task.cancel() }
        state = .inProgress(cancellable, previousState: oldState)

        do {
            let model = try await task.value
            currentTask = nil
            if Task.isCancelled {
                throw CancellationError()
            }
            if model.isEmpty {
                state = .empty(label: emptyStateConfiguration.label, image: emptyStateConfiguration.image)
            } else {
                state = .loaded(model, loadMoreState: loadMoreState(for: model))
            }
            return model
        } catch let error as CancellationError {
            currentTask = nil
            state = oldState
            throw error
        } catch {
            currentTask = nil
            state = oldState
            cachedQuery = nil
            throw error
        }
    }

    public func loadMore() async throws {
        switch state {
        case let .loaded(model, loadMoreState):
            switch loadMoreState {
            case .ready:
                if let paginated = model as? Paginated<Model.Element>,
                   let paginatedLoadMore = paginated.loadMore {
                    let action: @Sendable () async throws -> Model = {
                        do {
                            let result = try await paginatedLoadMore()
                            guard let typedResult = result as? Model else {
                                throw ListStoreError.invalidModel
                            }
                            return typedResult
                        } catch {
                            throw error
                        }
                    }
                    try await perform(action: action)
                }

            case .inProgress:
                if let loadMoreTask {
                    _ = try await loadMoreTask.value
                }

            default:
                break
            }

        default:
            break
        }
    }

    private func perform(action: @escaping @Sendable () async throws -> Model) async throws {
        guard case let .loaded(model, _) = state else {
            return
        }

        let task = Task {
            try await action()
        }

        loadMoreTask = task
        let cancellable = Cancellable { task.cancel() }
        state = .loaded(model, loadMoreState: .inProgress(cancellable))

        do {
            let model = try await task.value
            loadMoreTask = nil
            state = .loaded(model, loadMoreState: loadMoreState(for: model))
        } catch {
            loadMoreTask = nil
            state = .empty(label: emptyStateConfiguration.label, image: emptyStateConfiguration.image)
            cachedQuery = nil
            throw error
        }
    }

    /**
     Initiates a search asynchronously based on the provided query string.

     - Parameter query: The search query string to perform.
     */
    public func search(_ query: String) async {
        latestQueryString = query
        do {
            let query = try queryBuilder(latestQueryString)
            await load(query: query)
        } catch {
            if let failure = error as? Failure {
                state = .error(failure, previousState: state)
            }
        }
    }

    /**
     Retrieves the model element at the specified index.

     - Parameter index: The index of the model element to retrieve.
     - Returns: The model element at the specified index, if available; otherwise, `nil`.
     */
    public func element(at index: Int) -> Model.Element? {
        if case let .loaded(model, _) = state {
            let modelIndex = model.index(model.startIndex, offsetBy: index)
            guard modelIndex < model.endIndex else { return nil }
            return model[modelIndex]
        }

        return nil
    }

    /**
     Cancels any ongoing search or load operations.
     */
    public func cancelSearch() async {
        if case let .inProgress(cancellable, _) = state {
            cancellable.cancel()
        }
    }

    private func loadMoreState(for model: Model) -> LoadMoreState<Model> {
        if let paginated = model as? Paginated<Model.Element>,
           paginated.loadMore != nil {
            .ready
        } else {
            .unavailable
        }
    }
}
