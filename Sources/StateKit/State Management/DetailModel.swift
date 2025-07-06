// DetailModel.swift
// Copyright (c) 2025 Moroverse
// Created by Daniel Moro on 2024-08-07 18:45 GMT.

import Foundation
import Observation

/**
 Represents the various states of an asynchronous loading operation.

 `LoadingState` is an indirect enum that tracks the progression of loading a model,
 from empty state through loading, completion, or error states. The enum maintains
 previous states to allow for proper state transitions and recovery.

 ### States:

 - `empty`: The initial state before any loading begins
 - `inProgress`: Currently loading with an active task
 - `loaded`: Successfully loaded with the resulting model
 - `error`: Failed to load with error information

 ### Usage Example:

 ```swift
 switch loadingState {
 case let .empty(label, image):
     // Show empty state UI with label and image
 case let .inProgress(task, previousState):
     // Show loading indicator, can access previous state if needed
 case let .loaded(model):
     // Display the loaded model
 case let .error(message, previousState):
     // Show error message, can fall back to previous state
 }
 ```

 - Note: This enum is `indirect` because it contains recursive references to `Self` in the `previousState` parameters.
 */
public indirect enum LoadingState<Model> {
    /// The initial empty state before any loading operation begins.
    ///
    /// - Parameters:
    ///   - label: A localized string resource describing the empty state (e.g., "No results")
    ///   - image: A system image name to display alongside the empty state message
    case empty(label: LocalizedStringResource, image: String)
    
    /// The loading state when an asynchronous operation is in progress.
    ///
    /// - Parameters:
    ///   - task: The active `Task` performing the loading operation
    ///   - previousState: The state that was active before loading began, allowing for state recovery
    case inProgress(Task<Model, Error>, previousState: Self)
    
    /// The successful completion state containing the loaded model.
    ///
    /// - Parameter model: The successfully loaded model of type `Model`
    case loaded(Model)
    
    /// The error state when loading fails.
    ///
    /// - Parameters:
    ///   - message: A localized string resource describing the error
    ///   - previousState: The state that was active before the error occurred, enabling fallback behavior
    case error(LocalizedStringResource, previousState: Self)
}

extension LoadingState: Equatable where Model: Equatable {}

/**
 A model for managing asynchronous loading and state management of a single model based on a query.

 Use the `DetailModel` class to asynchronously load and manage the state for a single model,
 based on a provided query. This class handles loading, error handling, and cancellation of loading operations.

 ### Usage Example:

 ```swift
 // Define a loader function
 let loader: ModelLoader<MyQuery, MyModel> = { query in
 // Perform asynchronous loading of a single model based on the provided query
 }

 // Define a query provider function
 let queryProvider: QueryProvider<MyQuery> = {
 // Provide the query to load a specific model asynchronously
 }

 // Create an instance of DetailModel
 let detailModel = DetailModel(loader: loader, queryProvider: queryProvider)

 // Load the model
 await detailModel.load()
 */

@MainActor
@Observable
public class DetailModel<Model, Query> where Model: Sendable, Query: Sendable & Equatable {
    public var state: LoadingState<Model>

    private let emptyContentLabel: LocalizedStringResource
    private let emptyContentImageResource: String
    private let loader: ModelLoader<Query, Model>
    @ObservationIgnored
    private var queryProvider: QueryProvider<Query>
    @ObservationIgnored
    private var cachedQuery: Query?

    /**
     Initializes a new instance of `DetailModel`.

     - Parameters:
     - loader: A closure responsible for loading a single model asynchronously based on a query.
     - queryProvider: A closure responsible for providing the query to load the single model asynchronously.

     Use this initializer to create a new instance of `DetailModel` for managing asynchronous loading
     and state management of a single model.

     */
    public init(
        emptyContentLabel: LocalizedStringResource = "No results",
        emptyContentImageResource: String = "magnifyingglass",
        loader: @escaping ModelLoader<Query, Model>,
        queryProvider: @escaping QueryProvider<Query>
    ) {
        self.emptyContentLabel = emptyContentLabel
        self.emptyContentImageResource = emptyContentImageResource
        self.state = .empty(label: emptyContentLabel, image: emptyContentImageResource)
        self.loader = loader
        self.queryProvider = queryProvider
    }

    /**
     Loads a single model asynchronously based on the provided query.

     Use this method to asynchronously load a single model based on the query
     provided by the `queryProvider` closure.

     */
    public func load() async {
        let oldState = state

        do {
            _ = try await loadModel(oldState: oldState)
        } catch is CancellationError {
            state = oldState
        } catch {
            state = .error("\(error.localizedDescription)", previousState: oldState)
        }
    }

    func loadModel(oldState: LoadingState<Model>) async throws -> Model {
        let query = queryProvider()
        if let cachedQuery, cachedQuery == query {
            switch state {
            case let .loaded(model):
                return model

            case let .inProgress(task, _):
                return try await task.value

            default:
                break
            }
        }

        let task = Task { [loader] in
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
            state = .loaded(model)
            return model
        } catch {
            state = .empty(label: emptyContentLabel, image: emptyContentImageResource)
            cachedQuery = nil
            throw error
        }
    }

    public func cancel() {
        if case let .inProgress(task, _) = state {
            task.cancel()
        }
    }
}

/// An actor that manages loading and caching of models based on queries.
actor ModelLoaderActor<Query, Model> where Model: Sendable, Query: Hashable & Sendable {
    private let loader: ModelLoader<Query, Model>

    private enum State {
        case inProgress(Task<Model, Error>)
        case ready(Model)
    }

    private var cache: [Query: State] = [:]

    init(loader: @escaping ModelLoader<Query, Model>) {
        self.loader = loader
    }

    /// Loads a model for the given query, using caching when possible.
    ///
    /// - Parameter query: The query to load the model for.
    /// - Returns: The loaded model.
    /// - Throws: An error if the loading fails.
    func load(query: Query) async throws -> Model {
        if let cached = cache[query] {
            switch cached {
            case let .ready(model):
                return model

            case let .inProgress(task):
                return try await task.value
            }
        }

        let task = Task {
            try await loader(query)
        }

        cache[query] = .inProgress(task)

        do {
            let model = try await task.value
            cache[query] = .ready(model)
            return model
        } catch {
            cache[query] = nil
            throw error
        }
    }

    /// Invalidates the entire cache, removing all stored models.
    func invalidate() {
        cache = [:]
    }
}
