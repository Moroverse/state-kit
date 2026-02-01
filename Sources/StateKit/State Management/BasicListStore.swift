// BasicListStore.swift
// Copyright (c) 2025 Moroverse
// Created by Daniel Moro on 2026-02-01 GMT.

import Foundation
import Observation

/**
 A lightweight store for loading and displaying a collection without pagination, search, or selection.

 `BasicListStore` conforms only to ``ListStateProviding``. It provides the minimal
 loading lifecycle: `load()`, `element(at:)`, and observable `state`.

 For pagination, search, or selection, use ``ListStore`` instead.

 ### Type Parameters:

 - `Model`: A `RandomAccessCollection` of `Identifiable` & `Sendable` elements
 - `Query`: A `Sendable` & `Equatable` type representing the query
 - `Failure`: An `Error` type representing the kind of errors that can occur

 ### Usage Example:

 ```swift
 let store = BasicListStore<[MyItem], MyQuery, MyError>(
     loader: api.fetchItems,
     queryFactory: { MyQuery.default }
 )

 await store.load()
 ```

 - Note: This class is `@MainActor` and should be used from the main thread.
 */
@MainActor
@Observable
public final class BasicListStore<Model: RandomAccessCollection, Query: Sendable, Failure: Error>
    where Model: Sendable, Query: Sendable & Equatable, Model.Element: Identifiable, Model.Element: Sendable {

    public var state: ListLoadingState<Model, Failure>

    @ObservationIgnored
    private var loadingEngine: LoadingEngine<Model, Query, Failure>

    @ObservationIgnored
    private let queryFactory: QueryFactory<Query>

    /**
     Initializes a new instance of `BasicListStore`.

     - Parameters:
       - emptyStateConfiguration: Configuration for empty state labels and images. Default is `.default`.
       - loader: A closure responsible for loading models asynchronously based on a query.
       - queryFactory: A closure responsible for constructing the query.
     */
    public init(
        emptyStateConfiguration: EmptyStateConfiguration = .default,
        loader: @escaping DataLoader<Query, Model>,
        queryFactory: @escaping QueryFactory<Query>
    ) {
        self.state = .idle
        self.queryFactory = queryFactory
        self.loadingEngine = LoadingEngine(
            loader: loader,
            emptyStateConfiguration: emptyStateConfiguration,
            loadMoreStateResolver: { _ in .unavailable }
        )
    }

    /**
     Loads models asynchronously based on the query factory, with an option to force reload.

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
                assertionFailure("Unhandled error type in BasicListStore.load(): \(error)")
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

    /// Cancels any in-progress loading operation.
    public func cancel() {
        if case let .inProgress(cancellable, _) = state {
            cancellable.cancel()
        }
    }
}

// MARK: - BasicListStore Conformance

extension BasicListStore: ListStateProviding {}
