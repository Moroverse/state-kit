// ListStoreComposable.swift
// Copyright (c) 2025 Moroverse
// Created by Daniel Moro on 2026-02-01 GMT.

import Foundation

/// Internal protocol providing access to the root ``ListStore`` for wrappers
/// that need state mutation (pagination) or loading engine wiring.
///
/// All store types conform: ``ListStore/coreStore`` returns `self`,
/// wrappers return their base's `coreStore`.
@MainActor
protocol ListStoreComposable: ListStateProviding {
    associatedtype Query: Sendable & Equatable
    var coreStore: ListStore<Model, Query, Failure> { get }
}

// MARK: - Conformances

extension ListStore: ListStoreComposable {
    var coreStore: ListStore<Model, Query, Failure> { self }
}

extension SearchableListStore: ListStoreComposable {
    var coreStore: ListStore<Model, Query, Failure> { listStore }
}

extension PaginatedListStore: ListStoreComposable where Base: ListStoreComposable {
    typealias Query = Base.Query
    var coreStore: ListStore<Model, Query, Failure> { base.coreStore }
}

extension SelectableListStore: ListStoreComposable where Base: ListStoreComposable {
    typealias Query = Base.Query
    var coreStore: ListStore<Model, Query, Failure> { base.coreStore }
}

// MARK: - Factory Methods

extension ListStoreComposable {
    /// Wraps this store with pagination support.
    ///
    /// - Returns: A ``PaginatedListStore`` wrapping this store.
    public func paginated() -> PaginatedListStore<Self> {
        let engine = PaginationEngine<Model, Failure>(
            emptyStateConfiguration: coreStore.emptyStateConfiguration
        )
        coreStore.loadingEngine.loadMoreStateResolver = engine.loadMoreState
        return PaginatedListStore(
            base: self,
            paginationEngine: engine,
            setState: { self.coreStore.state = $0 },
            invalidateCache: { self.coreStore.loadingEngine.invalidateCache() }
        )
    }

    /// Wraps this store with selection support.
    ///
    /// - Parameters:
    ///   - selection: An optional initial selection ID. Default is `nil`.
    ///   - onSelectionChange: An optional callback triggered when selection changes.
    /// - Returns: A ``SelectableListStore`` wrapping this store.
    public func selectable(
        selection: Model.Element.ID? = nil,
        onSelectionChange: ((Model.Element?) -> Void)? = nil
    ) -> SelectableListStore<Self> {
        SelectableListStore(base: self, selection: selection, onSelectionChange: onSelectionChange)
    }
}

// MARK: - Searchable (ListStore only)

extension ListStore {
    /// Wraps this store with debounced search support.
    ///
    /// - Parameters:
    ///   - queryBuilder: A closure that builds a query from a search string.
    ///   - loadingConfiguration: Configuration for debounce delay and clock. Default is `.default`.
    /// - Returns: A ``SearchableListStore`` wrapping this store.
    public func searchable(
        queryBuilder: @escaping QueryBuilder<Query>,
        loadingConfiguration: LoadingConfiguration = .default
    ) -> SearchableListStore<Model, Query, Failure> {
        SearchableListStore(
            listStore: self,
            queryBuilder: queryBuilder,
            loadingConfiguration: loadingConfiguration
        )
    }
}
