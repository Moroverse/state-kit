// ListModel.swift
// Copyright (c) 2025 Moroverse
// Created by Daniel Moro on 2025-07-06 04:16 GMT.

import DeveloperToolsSupport
import Foundation
import Observation

/**
 Represents the various states of an asynchronous list loading operation.

 `ListLoadingState` is an indirect enum that tracks the progression of loading a collection,
 from empty state through loading, completion, or error states. This enum is specifically
 designed for collections and includes support for pagination through the `loadMoreState`
 parameter in the `loaded` case.

 ### States:

 - `empty`: The initial state before any loading begins or when no results are found
 - `inProgress`: Currently loading with an active task
 - `loaded`: Successfully loaded with the resulting collection and pagination state
 - `error`: Failed to load with error information

 ### Usage Example:

 ```swift
 switch listLoadingState {
 case let .empty(label, image):
     // Show empty state UI for lists (e.g., "No items found")
 case let .inProgress(task, previousState):
     // Show loading indicator for list content
 case let .loaded(collection, loadMoreState):
     // Display the loaded collection
     // Handle pagination based on loadMoreState
 case let .error(message, previousState):
     // Show error message, can fall back to previous state
 }
 ```

 - Note: This enum is `indirect` because it contains recursive references to `Self` in the `previousState` parameters.
 - Note: The generic `Model` type must conform to `RandomAccessCollection` to support efficient list operations.
 */
public indirect enum ListLoadingState<Model> where Model: RandomAccessCollection {
    /// The initial empty state before any loading operation begins, or when no results are found.
    ///
    /// This state is used both for the initial state and when a search/load operation returns no results.
    ///
    /// - Parameters:
    ///   - label: A localized string resource describing the empty state (e.g., "No items found")
    ///   - image: A system image name to display alongside the empty state message
    case empty(label: LocalizedStringResource, image: String)
    
    /// The loading state when an asynchronous list loading operation is in progress.
    ///
    /// - Parameters:
    ///   - task: The active `Task` performing the loading operation for the collection
    ///   - previousState: The state that was active before loading began, allowing for state recovery
    case inProgress(Task<Model, Error>, previousState: Self)
    
    /// The successful completion state containing the loaded collection and pagination information.
    ///
    /// - Parameters:
    ///   - collection: The successfully loaded collection of type `Model`
    ///   - loadMoreState: The current state of pagination, indicating whether more items can be loaded
    case loaded(Model, loadMoreState: LoadMoreState<Model>)
    
    /// The error state when list loading fails.
    ///
    /// - Parameters:
    ///   - message: A localized string resource describing the error
    ///   - previousState: The state that was active before the error occurred, enabling fallback behavior
    case error(LocalizedStringResource, previousState: Self)
}

extension ListLoadingState: Equatable where Model: Equatable {}

/**
 `LoadMoreState` is an enum that tracks the availability and progress of loading
 additional items in a paginated collection. This enum works in conjunction with
 `ListLoadingState` to provide comprehensive pagination support.

 ### States:

 - `unavailable`: No more items are available to load (end of pagination) or collection does not support pagination
 - `inProgress`: Currently loading additional items
 - `ready`: More items are available and ready to be loaded

 ### Usage Example:

 ```swift
 switch loadMoreState {
 case .unavailable:
 // Hide "Load More" button - no more items available
 case let .inProgress(task):
 // Show loading indicator for additional items
 // Optionally await the task: try await task.value
 case .ready:
 // Show "Load More" button - more items available
 }
 ```

 - Note: The generic `Model` type must conform to `RandomAccessCollection` to support efficient pagination operations.
 */
public enum LoadMoreState<Model> where Model: RandomAccessCollection {
    /// Pagination is not available for this collection.
    ///
    /// This state indicates that the collection does not support pagination
    /// or has reached its end with no additional items available.
    case unavailable

    /// Currently loading additional items for pagination.
    case inProgress(Task<Model, Error>)

    /// More items are available and ready to be loaded.
    case ready
}

extension LoadMoreState: Equatable {}

/**
 A model for managing asynchronous loading and state management of a collection based on queries.

 Use the `ListModel` class to asynchronously load and manage state for a collection of models,
 based on specified queries.
 This class supports pagination and debouncing of queries to ensure smooth user interactions.

 ### Usage Example:

 ```swift
 // Define a loader function
 let loader: ModelLoader<MyQuery, MyModel> = { query in
 // Perform asynchronous loading of models based on the provided query
 }

 // Create an instance of ListModel
 let listModel = ListModel(loader: loader, queryBuilder: { query in
 // Construct a query based on input
 })

 // Load initial data
 await listModel.load()

 // Perform a search
 await listModel.onSearch("search query")
 */
@MainActor
@Observable
open class ListModel<Model: RandomAccessCollection, Query: Sendable>
    where Model: Sendable, Query: Sendable & Equatable, Model.Element: Identifiable, Model.Element: Sendable {
    enum ListModelError: LocalizedError {
        case invalidModel
        case instanceDeallocated
    }

    public var state: ListLoadingState<Model>

    private let emptyContentLabel: LocalizedStringResource
    private let emptyContentImageResource: String
    public var selection: Model.Element.ID? {
        get { selectionManager.selectedID }
        set {
            selectionManager.selectedID = newValue
            
            // ListModel decides WHEN to call SelectionManager based on state
            if case let .loaded(model, _) = state {
                selectionManager.handleSelection(from: model)
            }
        }
    }

    public var canHandleSelection: Bool {
        selectionManager.canHandleSelection
    }

    private var selectionManager: any SelectionManager<Model.Element>
    private let loader: ModelLoader<Query, Model>
    @ObservationIgnored
    private lazy var loadModelDebounce: Debounce<Query, Bool, Model> = Debounce(
        call: { @Sendable [weak self] query, forceReload in
            guard let self else {
                throw ListModelError.instanceDeallocated
            }
            return try await loadModel(query: query, forceReload: forceReload)
        },
        after: .seconds(0.5),
        clock: clock
    )

    private let queryBuilder: QueryBuilder<Query>
    private let clock: any Clock<Duration>
    @ObservationIgnored
    private var cachedQuery: Query?
    @ObservationIgnored
    private var latestQueryString = ""


    /**
     Initializes a new instance of `ListModel`.

     - Parameters:
     - clock: An optional clock implementation to use for debouncing queries. Default is `ContinuousClock()`.
     - loader: A closure responsible for loading models asynchronously based on a query.
     - queryBuilder: A closure responsible for constructing a query based on input.

     Use this initializer to create a new instance of `ListModel`
     for managing asynchronous loading and state management of a collection.

     */
    public init(
        selection: Model.Element.ID? = nil,
        emptyContentLabel: LocalizedStringResource = "No results",
        emptyContentImageResource: String = "magnifyingglass",
        clock: any Clock<Duration> = ContinuousClock(),
        loader: @escaping ModelLoader<Query, Model>,
        queryBuilder: @escaping QueryBuilder<Query>,
        onSelectionChange: ((Model.Element?) -> Void)? = nil
    ) {
        state = .empty(label: emptyContentLabel, image: emptyContentImageResource)
        self.loader = loader
        self.queryBuilder = queryBuilder
        self.clock = clock
        self.selectionManager = CallbackSelectionManager(onSelectionChange: onSelectionChange)
        self.emptyContentLabel = emptyContentLabel
        self.emptyContentImageResource = emptyContentImageResource
        self.selection = selection
    }

    /**
     Loads models asynchronously based on the current query, with an option to force reload.

     - Parameter forceReload: A boolean flag to force reloading even if the query is cached. Default is false.

     Use this method to asynchronously load models based on the current query set by the `queryBuilder`.
     Set `forceReload` to true to bypass the cache and force a new load.

     */
    public func load(forceReload: Bool = false) async {
        await load(
            query: queryBuilder(latestQueryString),
            forceReload: forceReload
        )
    }

    /**
     Loads models asynchronously based on the provided query, with an option to force reload.

     - Parameters:
     - query: The query used to load models asynchronously.
     - forceReload: A boolean flag to force reloading even if the query is cached. Default is false.

     Use this method to asynchronously load models based on the provided query.
     Set `forceReload` to true to bypass the cache and force a new load.

     */
    public func load(query: Query, forceReload: Bool = false) async {
        do {
            _ = try await loadModelDebounce(query, forceReload)
        } catch is CancellationError {
        } catch {
            state = .error("\(error.localizedDescription)", previousState: state)
        }
    }

    @discardableResult
    public func loadModel(query: Query, forceReload: Bool = false) async throws -> Model {
        if !forceReload, let cachedQuery, cachedQuery == query {
            switch state {
            case let .loaded(model, _):
                return model

            case let .inProgress(task, _):
                return try await task.value

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

        cachedQuery = query
        state = .inProgress(task, previousState: oldState)

        do {
            let model = try await task.value
            if Task.isCancelled {
                throw CancellationError()
            }
            if model.isEmpty {
                state = .empty(label: emptyContentLabel, image: emptyContentImageResource)
            } else {
                state = .loaded(model, loadMoreState: loadMoreState(for: model))
            }
            return model
        } catch let error as CancellationError {
            state = oldState
            throw error
        } catch {
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
                                throw ListModelError.invalidModel
                            }
                            return typedResult
                        } catch {
                            throw error
                        }
                    }
                    try await perform(action: action)
                }

            case let .inProgress(task):
                _ = try await task.value

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

        state = .loaded(model, loadMoreState: .inProgress(task))

        do {
            let model = try await task.value
            state = .loaded(model, loadMoreState: loadMoreState(for: model))
        } catch {
            state = .empty(label: emptyContentLabel, image: emptyContentImageResource)
            cachedQuery = nil
            throw error
        }
    }

    /**
     Initiates a search asynchronously based on the provided query.

     - Parameter query: The search query to perform.

     Use this method to perform a search operation asynchronously based on the provided query.
     The query is constructed using the `queryBuilder` closure.

     */
    public func search(_ query: String) async {
        latestQueryString = query
        let query = queryBuilder(latestQueryString)
        await load(query: query)
    }

    /**
     Retrieves the model element at the specified index.

     - Parameter index: The index of the model element to retrieve.

     - Returns: The model element at the specified index, if available; otherwise, `nil`.

     Use this method to retrieve the model element at a specific index from the loaded models.
     Returns `nil` if the model state is not `.loaded`.

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

     Use this method to cancel any ongoing search or load operations
     and reset the state to initiate a new load operation.

     */
    public func cancelSearch() async {
        if case let .inProgress(task, _) = state {
            task.cancel()
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
