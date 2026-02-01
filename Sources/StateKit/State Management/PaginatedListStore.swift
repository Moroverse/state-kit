// PaginatedListStore.swift
// Copyright (c) 2026 Moroverse
// Created by Daniel Moro on 2026-02-01 10:12 GMT.

import Foundation
import Observation

/// A decorator that adds load-more pagination to any ``ListStateProviding`` store.
///
/// `PaginatedListStore` wraps a base store and adds the `loadMore()` method
/// for pagination. It conforms to ``ListStateProviding`` and ``PaginatedListProviding``.
///
/// ### Usage:
///
/// ```swift
/// let store = ListStore(loader: api.fetch, queryFactory: { .default })
///     .searchable(queryBuilder: { term in Query(term: term) })
///     .paginated()
/// ```
///
/// - Note: This class is `@MainActor` and should be used from the main thread.
@MainActor
@Observable
public final class PaginatedListStore<Base: ListStateProviding>
    where Base.Model.Element: Identifiable & Sendable {
    /// The underlying store being wrapped.
    public let base: Base

    @ObservationIgnored
    private let paginationEngine: PaginationEngine<Base.Model, Base.Failure>

    @ObservationIgnored
    private let setState: (ListLoadingState<Base.Model, Base.Failure>) -> Void

    @ObservationIgnored
    private let invalidateCache: () -> Void

    init(
        base: Base,
        paginationEngine: PaginationEngine<Base.Model, Base.Failure>,
        setState: @escaping (ListLoadingState<Base.Model, Base.Failure>) -> Void,
        invalidateCache: @escaping () -> Void
    ) {
        self.base = base
        self.paginationEngine = paginationEngine
        self.setState = setState
        self.invalidateCache = invalidateCache
    }

    // MARK: - ListStateProviding

    public var state: ListLoadingState<Base.Model, Base.Failure> {
        base.state
    }

    public func load(forceReload: Bool = false) async {
        await base.load(forceReload: forceReload)
    }

    // MARK: - PaginatedListProviding

    /// Loads the next page of results.
    ///
    /// This method delegates to the pagination engine which manages the load-more lifecycle,
    /// including state transitions and cache invalidation on error.
    public func loadMore() async throws {
        try await paginationEngine.loadMore(
            currentState: base.state,
            setState: setState,
            invalidateCache: invalidateCache
        )
    }
}

// MARK: - Protocol Conformances

extension PaginatedListStore: ListStateProviding {}
extension PaginatedListStore: PaginatedListProviding {}

// MARK: - Conditional Conformances

extension PaginatedListStore: SearchableListProviding where Base: SearchableListProviding {
    public func search(_ query: String) async {
        await base.search(query)
    }

    public func cancelSearch() async {
        await base.cancelSearch()
    }
}

extension PaginatedListStore: SelectableListProviding where Base: SelectableListProviding {
    public var selection: Base.Model.Element.ID? {
        base.selection
    }

    public func select(_ id: Base.Model.Element.ID?) {
        base.select(id)
    }

    public var canHandleSelection: Bool {
        base.canHandleSelection
    }
}
