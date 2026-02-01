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
/// `ListLoadingState` tracks the progression of loading a collection (list view),
/// while ``LoadingState`` is its single-model counterpart for detail views.
///
/// `ListLoadingState` extends the base pattern with ``LoadMoreState`` in its
/// `.loaded` case to support pagination — the key reason for keeping these types separate.
///
/// Both share the same state machine pattern: `idle → inProgress → loaded | empty | error`.
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
    case loaded(Model, loadMoreState: LoadMoreState)

    /// The error state when list loading fails.
    ///
    /// - Parameters:
    ///   - failure: The typed error that caused the failure
    ///   - previousState: The state that was active before the error occurred, enabling fallback behavior
    case error(Failure, previousState: Self)
}

extension ListLoadingState: Equatable where Model: Equatable, Failure: Equatable {}

/// The state of pagination for a loaded collection.
public enum LoadMoreState {
    /// Pagination is not available for this collection.
    case unavailable

    /// Currently loading additional items for pagination.
    case inProgress(Cancellable)

    /// More items are available and ready to be loaded.
    case ready
}

extension LoadMoreState: Equatable {}

/**
 The base store for managing asynchronous loading of a collection of items.

 `ListStore` handles core loading, caching, and cancellation. Additional capabilities
 (search, pagination, selection) are added by wrapping with decorator types.

 ### Composition via Fluent API:

 ```swift
 // Simple list:
 let store = ListStore(loader: api.fetch, queryFactory: { .default })

 // Searchable + paginated:
 let store = ListStore(loader: api.fetch, queryFactory: { .default })
     .searchable(queryBuilder: { term in Query(term: term) })
     .paginated()

 // Full-featured:
 let store = ListStore(loader: api.fetch, queryFactory: { .default })
     .searchable(queryBuilder: { term in Query(term: term) })
     .paginated()
     .selectable(onSelectionChange: { item in handle(item) })
 ```

 ### Type Parameters:

 - `Model`: A `RandomAccessCollection` of `Identifiable` & `Sendable` elements
 - `Query`: A `Sendable` & `Equatable` type representing the query
 - `Failure`: An `Error` type representing the kind of errors that can occur

 - Note: This class is `@MainActor` and should be used from the main thread.
 */
@MainActor
@Observable
public final class ListStore<Model: RandomAccessCollection, Query: Sendable, Failure: Error>
    where Model: Sendable, Query: Sendable & Equatable, Model.Element: Identifiable, Model.Element: Sendable {

    public var state: ListLoadingState<Model, Failure>

    // MARK: - Engines

    @ObservationIgnored
    var loadingEngine: LoadingEngine<Model, Query, Failure>

    // MARK: - Query Factory

    @ObservationIgnored
    private let queryFactory: QueryProvider<Query>

    // MARK: - Configuration

    @ObservationIgnored
    let emptyStateConfiguration: EmptyStateConfiguration

    /**
     Initializes a `ListStore` for loading a collection.

     - Parameters:
       - emptyStateConfiguration: Configuration for empty state labels and images. Default is `.default`.
       - loader: A closure responsible for loading models asynchronously based on a query.
       - queryFactory: A closure responsible for constructing the query.
     */
    public init(
        emptyStateConfiguration: EmptyStateConfiguration = .default,
        loader: @escaping DataLoader<Query, Model>,
        queryFactory: @escaping QueryProvider<Query>
    ) {
        self.emptyStateConfiguration = emptyStateConfiguration
        self.state = .idle
        self.queryFactory = queryFactory
        self.loadingEngine = LoadingEngine(
            loader: loader,
            emptyStateConfiguration: emptyStateConfiguration,
            loadMoreStateResolver: { _ in .unavailable }
        )
    }

    // MARK: - Loading

    /**
     Loads models asynchronously based on the current query factory, with an option to force reload.

     - Parameter forceReload: A boolean flag to force reloading even if the query is cached. Default is false.
     */
    public func load(forceReload: Bool = false) async {
        do {
            let query = try queryFactory()
            try await loadingEngine.loadModel(
                query: query,
                forceReload: forceReload,
                currentState: state,
                setState: { self.state = $0 }
            )
        } catch is CancellationError {
        } catch {
            if let failure = error as? Failure {
                state = .error(failure, previousState: state)
            } else {
                assertionFailure("Unhandled error type in ListStore.load(): \(error)")
            }
        }
    }

    /**
     Loads models asynchronously based on the provided query, with an option to force reload.

     - Parameters:
       - query: The query used to load models asynchronously.
       - forceReload: A boolean flag to force reloading even if the query is cached. Default is false.
     - Returns: The loaded model.
     - Throws: `CancellationError` if the task was cancelled, or the loader's error.
     */
    @discardableResult
    public func loadModel(query: Query, forceReload: Bool = false) async throws -> Model {
        try await loadingEngine.loadModel(
            query: query,
            forceReload: forceReload,
            currentState: state,
            setState: { self.state = $0 }
        )
    }

    // MARK: - Cancel

    /// Cancels any in-progress loading operation.
    public func cancel() {
        if case let .inProgress(cancellable, _) = state {
            cancellable.cancel()
        }
    }

    // MARK: - Element Access

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
}
