// DetailStore.swift
// Copyright (c) 2026 Moroverse
// Created by Daniel Moro on 2025-04-06 16:31 GMT.

import Foundation
import Observation

/**
 Represents the various states of an asynchronous loading operation for a single model.

 `LoadingState` tracks the progression of loading a single model (detail view),
 while ``ListLoadingState`` is its collection-oriented counterpart that additionally
 carries ``LoadMoreState`` for pagination.

 Both share the same state machine pattern: `idle → inProgress → loaded | empty | error`.

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
    /// The view layer should read ``EmptyStateConfiguration`` from the store
    /// to obtain presentational details (label, image) when encountering this state.
    case empty

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

extension LoadingState {
    /// Handles a thrown error by ignoring cancellation and transitioning to error state for typed failures.
    mutating func handleLoadingError(_ error: Error) {
        guard !(error is CancellationError) else { return }
        if let failure = error as? Failure {
            self = .error(failure, previousState: self)
        }
    }
}

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
public final class DetailStore<Model: Sendable, Query: Sendable & Equatable, Failure: Error> {
    public var state: LoadingState<Model, Failure>

    @ObservationIgnored
    public let emptyStateConfiguration: EmptyStateConfiguration

    @ObservationIgnored
    private let loadingEngine: DetailLoadingEngine<Model, Query, Failure>

    @ObservationIgnored
    private var queryProvider: QueryProvider<Query>

    /**
     Initializes a new instance of `DetailStore`.

     - Parameters:
       - emptyStateConfiguration: Configuration for empty state labels and images. Default is `.default`.
       - loader: A closure responsible for loading a single model asynchronously based on a query.
       - queryProvider: A closure responsible for providing the query to load the single model asynchronously.
     */
    public init(
        emptyStateConfiguration: EmptyStateConfiguration = .default,
        loader: @escaping DataLoader<Query, Model>,
        queryProvider: @escaping QueryProvider<Query>
    ) {
        self.emptyStateConfiguration = emptyStateConfiguration
        state = .idle
        self.queryProvider = queryProvider
        loadingEngine = DetailLoadingEngine(loader: loader)
    }

    /**
     Loads a single model asynchronously based on the provided query.
     */
    public func load() async {
        do {
            let query = try queryProvider()
            _ = try await loadingEngine.loadModel(
                query: query,
                currentState: state,
                setState: { self.state = $0 }
            )
        } catch {
            state.handleLoadingError(error)
        }
    }

    /// Cancels any in-progress loading operation.
    public func cancel() {
        if case let .inProgress(cancellable, _) = state {
            cancellable.cancel()
        }
    }
}
