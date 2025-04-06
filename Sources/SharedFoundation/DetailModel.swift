// DetailModel.swift
// Copyright (c) 2025 Moroverse
// Created by Daniel Moro on 2024-08-07 18:45 GMT.

import Foundation
import Observation

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
    public var state: ContentState<Model> = .empty
    public var error: Error?

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
        loader: @escaping ModelLoader<Query, Model>,
        queryProvider: @escaping QueryProvider<Query>
    ) {
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
            state = oldState
            self.error = error
        }
    }

    func loadModel(oldState: ContentState<Model>) async throws -> Model {
        let query = queryProvider()
        if let cachedQuery, cachedQuery == query {
            switch state {
            case let .ready(model):
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
        state = .inProgress(task, currentState: oldState)

        do {
            let model = try await task.value
            if Task.isCancelled {
                throw CancellationError()
            }
            state = .ready(model)
            return model
        } catch {
            state = .empty
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
