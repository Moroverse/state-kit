// PaginationEngine.swift
// Copyright (c) 2026 Moroverse
// Created by Daniel Moro on 2026-02-01 05:29 GMT.

import Foundation

/// Internal engine that encapsulates pagination (load-more) logic.
///
/// Used by ``PaginatedListStore`` to manage the `loadMore()` lifecycle.
///
/// `PaginationEngine` is constrained to `Paginated<Element>` models, ensuring at compile time
/// that pagination features are only available when the underlying model supports them.
@MainActor
final class PaginationEngine<Element: Identifiable & Sendable, Failure: Error> {
    typealias Model = Paginated<Element>

    private(set) var loadMoreTask: Task<Model, Error>?

    init() {}

    /// Determines the load-more state for the given model.
    ///
    /// Returns `.ready` if the model has a `loadMore` closure, otherwise returns `.unavailable`.
    func loadMoreState(for model: Model) -> LoadMoreState {
        if model.loadMore != nil {
            .ready
        } else {
            .unavailable
        }
    }

    /// Executes a load-more operation based on the current state.
    ///
    /// - Parameters:
    ///   - currentState: The current loading state (read from the store).
    ///   - setState: A closure the engine calls to update the store's observable state.
    ///   - invalidateCache: A closure that can reset the loading engine's cache.
    func loadMore(
        currentState: ListLoadingState<Model, Failure>,
        setState: (ListLoadingState<Model, Failure>) -> Void,
        invalidateCache: () -> Void
    ) async throws {
        switch currentState {
        case let .loaded(model, loadMoreState):
            switch loadMoreState {
            case .ready:
                if let paginatedLoadMore = model.loadMore {
                    let action: @Sendable () async throws -> Model = {
                        try await paginatedLoadMore()
                    }
                    try await perform(
                        action: action,
                        currentState: currentState,
                        setState: setState,
                        invalidateCache: invalidateCache
                    )
                }

            case .inProgress:
                if let loadMoreTask {
                    _ = try await loadMoreTask.value
                }

            default:
                break
            }

        default:
            break
        }
    }

    private func perform(
        action: @escaping @Sendable () async throws -> Model,
        currentState: ListLoadingState<Model, Failure>,
        setState: (ListLoadingState<Model, Failure>) -> Void,
        invalidateCache: () -> Void
    ) async throws {
        guard case let .loaded(model, _) = currentState else {
            return
        }

        let task = Task {
            try await action()
        }

        loadMoreTask = task
        let cancellable = Cancellable { task.cancel() }
        setState(.loaded(model, loadMoreState: .inProgress(cancellable)))

        do {
            let model = try await task.value
            loadMoreTask = nil
            setState(.loaded(model, loadMoreState: loadMoreState(for: model)))
        } catch {
            loadMoreTask = nil
            setState(.loaded(model, loadMoreState: .ready))
            throw error
        }
    }
}
