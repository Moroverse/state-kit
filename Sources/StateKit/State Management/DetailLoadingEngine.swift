// DetailLoadingEngine.swift
// Copyright (c) 2026 Moroverse
// Created by Daniel Moro on 2026-02-02 06:39 GMT.

import Foundation

/// Internal engine that encapsulates core loading, caching, and task management logic for detail stores.
///
/// `DetailLoadingEngine` manages the load/cache/cancel lifecycle for single-model loading.
/// All observable state remains on the `@Observable` store classes — this engine only manages
/// the non-observable internals and computes state transitions.
///
/// This is the single-model counterpart of ``LoadingEngine``, which handles collection loading.
@MainActor
final class DetailLoadingEngine<Model: Sendable, Query: Sendable & Equatable, Failure: Error> {
    private let loader: DataLoader<Query, Model>

    private(set) var cachedQuery: Query?
    private(set) var currentTask: Task<Model, Error>?

    init(loader: @escaping DataLoader<Query, Model>) {
        self.loader = loader
    }

    /// Attempts to load a model for the given query, managing caching and task lifecycle.
    ///
    /// - Parameters:
    ///   - query: The query to load.
    ///   - currentState: The current loading state (read from the store).
    ///   - setState: A closure the engine calls to update the store's observable state.
    /// - Returns: The loaded model.
    /// - Throws: `CancellationError` if the task was cancelled, or the loader's error.
    func loadModel(
        query: Query,
        currentState: LoadingState<Model, Failure>,
        setState: (LoadingState<Model, Failure>) -> Void
    ) async throws -> Model {
        if let cachedQuery, cachedQuery == query {
            switch currentState {
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
            setState(.loaded(model))
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
