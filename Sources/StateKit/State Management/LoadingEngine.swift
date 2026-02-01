// LoadingEngine.swift
// Copyright (c) 2025 Moroverse
// Created by Daniel Moro on 2026-02-01 GMT.

import Foundation

/// Internal engine that encapsulates core loading, caching, and task management logic.
///
/// `LoadingEngine` is shared by both `BasicListStore` and `ListStore` to avoid
/// duplicating the load/cache/cancel lifecycle. All observable state remains on the
/// `@Observable` store classes — this engine only manages the non-observable internals
/// and computes state transitions.
@MainActor
final class LoadingEngine<Model: RandomAccessCollection, Query: Sendable & Equatable, Failure: Error>
    where Model: Sendable, Model.Element: Identifiable & Sendable {

    private let loader: DataLoader<Query, Model>
    private let emptyStateConfiguration: EmptyStateConfiguration
    var loadMoreStateResolver: (Model) -> LoadMoreState

    private(set) var cachedQuery: Query?
    private(set) var currentTask: Task<Model, Error>?

    init(
        loader: @escaping DataLoader<Query, Model>,
        emptyStateConfiguration: EmptyStateConfiguration,
        loadMoreStateResolver: @escaping (Model) -> LoadMoreState
    ) {
        self.loader = loader
        self.emptyStateConfiguration = emptyStateConfiguration
        self.loadMoreStateResolver = loadMoreStateResolver
    }

    /// Attempts to load a model for the given query, managing caching and task lifecycle.
    ///
    /// - Parameters:
    ///   - query: The query to load.
    ///   - forceReload: Whether to bypass the cache.
    ///   - currentState: The current loading state (read from the store).
    ///   - setState: A closure the engine calls to update the store's observable state.
    /// - Returns: The loaded model.
    /// - Throws: `CancellationError` if the task was cancelled, or the loader's error.
    @discardableResult
    func loadModel(
        query: Query,
        forceReload: Bool,
        currentState: ListLoadingState<Model, Failure>,
        setState: (ListLoadingState<Model, Failure>) -> Void
    ) async throws -> Model {
        if !forceReload, let cachedQuery, cachedQuery == query {
            switch currentState {
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

        let oldState = currentState

        let task = Task { [loader] in
            try Task.checkCancellation()
            let model = try await loader(query)
            try Task.checkCancellation()
            return model
        }

        currentTask = task
        cachedQuery = query
        let cancellable = Cancellable { task.cancel() }
        setState(.inProgress(cancellable, previousState: oldState))

        do {
            let model = try await task.value
            currentTask = nil
            if Task.isCancelled {
                throw CancellationError()
            }
            if model.isEmpty {
                setState(.empty(label: emptyStateConfiguration.label, image: emptyStateConfiguration.image))
            } else {
                setState(.loaded(model, loadMoreState: loadMoreStateResolver(model)))
            }
            return model
        } catch let error as CancellationError {
            currentTask = nil
            setState(oldState)
            throw error
        } catch {
            currentTask = nil
            setState(oldState)
            cachedQuery = nil
            throw error
        }
    }

    /// Resets the cached query, forcing the next load to fetch fresh data.
    func invalidateCache() {
        cachedQuery = nil
    }
}
