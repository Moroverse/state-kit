// ListModel.swift
// Copyright (c) 2025 Moroverse
// Created by Daniel Moro on 2025-04-06 16:31 GMT.

import Foundation
import Observation

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

/// Represents the state of loading more items in a list.
public enum LoadMoreState<Model> {
    /// No more items to load.
    case empty
    /// Currently loading more items.
    case inProgress(Task<Model, Error>)
    /// Ready to load more items.
    case ready
}

extension LoadMoreState: Equatable {}

@MainActor
@Observable
open class ListModel<Model: RandomAccessCollection, Query: Sendable>
    where Model: Sendable, Query: Sendable & Equatable, Model.Element: Identifiable {
    enum ListModelError: LocalizedError {
        case invalidModel
        case instanceDeallocated
    }

    public var state: ContentState<Model> = .empty
    public var errorMessage: LocalizedStringResource?
    public var loadMoreState: LoadMoreState<Model> = .empty

    public var emptyContentLabel: LocalizedStringResource
    public var emptyContentImageName: String
    public var selection: Model.Element.ID? {
        didSet {
            if let selection, let onSelectionChange, case let .ready(model) = state {
                if let element = model.first(where: { $0.id == selection }) {
                    onSelectionChange(element)
                }
            }
        }
    }

    public var canHandleSelection: Bool {
        onSelectionChange != nil
    }

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

    private var onSelectionChange: ((Model.Element?) -> Void)?

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
        emptyContentImageName: String = "magnifyingglass",
        clock: any Clock<Duration> = ContinuousClock(),
        loader: @escaping ModelLoader<Query, Model>,
        queryBuilder: @escaping QueryBuilder<Query>,
        onSelectionChange: ((Model.Element?) -> Void)? = nil
    ) {
        self.loader = loader
        self.queryBuilder = queryBuilder
        self.clock = clock
        self.onSelectionChange = onSelectionChange
        self.emptyContentLabel = emptyContentLabel
        self.emptyContentImageName = emptyContentImageName
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
            errorMessage = "\(error.localizedDescription)"
        }
    }

    @discardableResult
    public func loadModel(query: Query, forceReload: Bool = false) async throws -> Model {
        if !forceReload, let cachedQuery, cachedQuery == query {
            switch state {
            case let .ready(model):
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
        state = .inProgress(task, currentState: oldState)

        do {
            let model = try await task.value
            if Task.isCancelled {
                throw CancellationError()
            }
            if model.isEmpty {
                state = .empty
            } else {
                updateReadyState(.ready(model))
            }
            return model
        } catch let error as CancellationError {
            updateReadyState(.empty)
            throw error
        } catch {
            updateReadyState(oldState)
            cachedQuery = nil
            throw error
        }
    }

    public func loadMore() async throws {
        switch loadMoreState {
        case .ready:
            if case let .ready(model) = state,
               let paginated = model as? Paginated<Model.Element>,
               let paginatedLoadMore = paginated.loadMore {
                try await perform(action: {
                    let result = try? await paginatedLoadMore()
                    guard let result = result as? Model else {
                        throw ListModelError.invalidModel
                    }
                    return result
                })
            }

        case let .inProgress(task):
            _ = try await task.value

        default:
            break
        }
    }

    private func perform(action: @escaping @Sendable () async throws -> Model) async throws {
        let task = Task {
            try await action()
        }

        loadMoreState = .inProgress(task)

        do {
            let model = try await task.value
            updateReadyState(.ready(model))
        } catch {
            updateReadyState(.empty)
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
    public func onSearch(_ query: String) async {
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
        if case let .ready(model) = state {
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

    private func updateReadyState(_ newReadyState: ContentState<Model>) {
        state = newReadyState
        makeLoadMoreModel()
    }

    private func makeLoadMoreModel() {
        if case let .ready(model) = state,
           let paginated = model as? Paginated<Model.Element>,
           paginated.loadMore != nil {
            loadMoreState = .ready
        } else {
            loadMoreState = .empty
        }
    }
}
