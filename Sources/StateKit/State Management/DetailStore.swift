// DetailStore.swift
// Copyright (c) 2025 Moroverse
// Created by Daniel Moro on 2024-08-07 18:45 GMT.

import Foundation
import Observation

/**
 Represents the various states of an asynchronous loading operation for a single model.

 `LoadingState` is an indirect enum that tracks the progression of loading a model,
 from idle state through loading, completion, or error states. The enum maintains
 previous states to allow for proper state transitions and recovery.

 ### States:

 - `idle`: Initial state before any loading has been triggered
 - `empty`: A load completed but no data was found
 - `inProgress`: Currently loading with a cancellable handle
 - `loaded`: Successfully loaded with the resulting model
 - `error`: Failed to load with typed error information

 - Note: This enum is `indirect` because it contains recursive references to `Self` in the `previousState` parameters.
 */
public indirect enum LoadingState<Model, Failure: Error> {
    /// The initial state before any loading operation has been triggered.
    case idle

    /// The state when a load completed but no data was found.
    ///
    /// - Parameters:
    ///   - label: A localized string resource describing the empty state (e.g., "No results")
    ///   - image: A system image name to display alongside the empty state message
    case empty(label: LocalizedStringResource, image: String)

    /// The loading state when an asynchronous operation is in progress.
    ///
    /// - Parameters:
    ///   - cancellable: A `Cancellable` handle that can be used to abort the operation
    ///   - previousState: The state that was active before loading began, allowing for state recovery
    case inProgress(Cancellable, previousState: Self)

    /// The successful completion state containing the loaded model.
    ///
    /// - Parameter model: The successfully loaded model of type `Model`
    case loaded(Model)

    /// The error state when loading fails.
    ///
    /// - Parameters:
    ///   - failure: The typed error that caused the failure
    ///   - previousState: The state that was active before the error occurred, enabling fallback behavior
    case error(Failure, previousState: Self)
}

extension LoadingState: Equatable where Model: Equatable, Failure: Equatable {}

/**
 A store for managing asynchronous loading and state management of a single model based on a query.

 Use the `DetailStore` class to asynchronously load and manage the state for a single model,
 based on a provided query.

 ### Usage Example:

 ```swift
 let store = DetailStore<MyModel, MyQuery, MyError>(
     loader: myLoader,
     queryProvider: myQueryProvider
 )

 await store.load()
 ```
 */
@MainActor
@Observable
public class DetailStore<Model, Query, Failure: Error> where Model: Sendable, Query: Sendable & Equatable {
    public var state: LoadingState<Model, Failure>

    private let emptyContentLabel: LocalizedStringResource
    private let emptyContentImageResource: String
    private let loader: DataLoader<Query, Model>
    @ObservationIgnored
    private var queryProvider: QueryProvider<Query>
    @ObservationIgnored
    private var cachedQuery: Query?
    @ObservationIgnored
    private var currentTask: Task<Model, Error>?

    /**
     Initializes a new instance of `DetailStore`.

     - Parameters:
       - emptyContentLabel: A localized label for the empty state. Default is "No results".
       - emptyContentImageResource: A system image name for the empty state. Default is "magnifyingglass".
       - loader: A closure responsible for loading a single model asynchronously based on a query.
       - queryProvider: A closure responsible for providing the query to load the single model asynchronously.
     */
    public init(
        emptyContentLabel: LocalizedStringResource = "No results",
        emptyContentImageResource: String = "magnifyingglass",
        loader: @escaping DataLoader<Query, Model>,
        queryProvider: @escaping QueryProvider<Query>
    ) {
        self.emptyContentLabel = emptyContentLabel
        self.emptyContentImageResource = emptyContentImageResource
        self.state = .idle
        self.loader = loader
        self.queryProvider = queryProvider
    }

    /**
     Loads a single model asynchronously based on the provided query.
     */
    public func load() async {
        let oldState = state

        do {
            _ = try await loadModel(oldState: oldState)
        } catch is CancellationError {
            state = oldState
        } catch {
            if let failure = error as? Failure {
                state = .error(failure, previousState: oldState)
            }
        }
    }

    func loadModel(oldState: LoadingState<Model, Failure>) async throws -> Model {
        let query = try queryProvider()
        if let cachedQuery, cachedQuery == query {
            switch state {
            case let .loaded(model):
                return model

            case .inProgress:
                if let currentTask {
                    return try await currentTask.value
                }

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
            state = .loaded(model)
            return model
        } catch {
            currentTask = nil
            state = .empty(label: emptyContentLabel, image: emptyContentImageResource)
            cachedQuery = nil
            throw error
        }
    }

    public func cancel() {
        if case let .inProgress(cancellable, _) = state {
            cancellable.cancel()
        }
    }
}

/// An actor that manages loading and caching of models based on queries.
actor DataLoaderActor<Query, Model> where Model: Sendable, Query: Hashable & Sendable {
    private let loader: DataLoader<Query, Model>

    private enum State {
        case inProgress(Task<Model, Error>)
        case ready(Model)
    }

    private var cache: [Query: State] = [:]

    init(loader: @escaping DataLoader<Query, Model>) {
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
