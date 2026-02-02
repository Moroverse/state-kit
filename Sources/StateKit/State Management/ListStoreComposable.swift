// ListStoreComposable.swift
// Copyright (c) 2026 Moroverse
// Created by Daniel Moro on 2026-02-01 10:12 GMT.

import Foundation

/// Protocol providing access to the root ``ListStore`` for decorator stores
/// that need state mutation (pagination) or loading engine wiring.
///
/// You don't conform to this protocol directly — it powers the fluent API
/// (`.paginated()`, `.selectable()`) on all store types.
/// ``ListStore/coreStore`` returns `self`; wrappers return their base's `coreStore`.
@MainActor
public protocol ListStoreComposable: ListStateProviding {
    associatedtype Query: Sendable & Equatable
    var coreStore: ListStore<Model, Query, Failure> { get }
}

// MARK: - Conformances

extension ListStore: ListStoreComposable {
    public var coreStore: ListStore<Model, Query, Failure> {
        self
    }
}

extension SearchableListStore: ListStoreComposable {
    public var coreStore: ListStore<Model, Query, Failure> {
        base
    }
}

extension PaginatedListStore: ListStoreComposable where Base: ListStoreComposable {
    public typealias Query = Base.Query
    public var coreStore: ListStore<Model, Query, Failure> {
        base.coreStore
    }
}

extension SelectableListStore: ListStoreComposable where Base: ListStoreComposable {
    public typealias Query = Base.Query
    public var coreStore: ListStore<Model, Query, Failure> {
        base.coreStore
    }
}

// MARK: - Factory Methods

public extension ListStoreComposable {
    /// Wraps this store with pagination support.
    ///
    /// Only available when `Model` is `Paginated<Element>`, ensuring pagination is type-safe
    /// rather than relying on runtime type-casting.
    ///
    /// - Returns: A ``PaginatedListStore`` wrapping this store.
    func paginated<Element: Identifiable & Sendable>() -> PaginatedListStore<Self, Element>
        where Model == Paginated<Element> {
        let engine = PaginationEngine<Element, Failure>()
        coreStore.loadingEngine.loadMoreStateResolver = engine.loadMoreState
        return PaginatedListStore(
            base: self,
            paginationEngine: engine,
            setState: { self.coreStore.state = $0 },
            invalidateCache: { self.coreStore.loadingEngine.invalidateCache() }
        )
    }
}

public extension ListStoreComposable {
    /// Wraps this store with selection support.
    ///
    /// - Parameters:
    ///   - selection: An optional initial selection ID. Default is `nil`.
    /// - Returns: A ``SelectableListStore`` wrapping this store.
    func selectable(
        selection: Model.Element.ID? = nil
    ) -> SelectableListStore<Self> {
        SelectableListStore(base: self, selection: selection)
    }
}

// MARK: - Searchable (ListStore only)

public extension ListStore {
    /// Wraps this store with debounced search support.
    ///
    /// - Parameters:
    ///   - queryBuilder: A closure that builds a query from a search string.
    ///   - loadingConfiguration: Configuration for debounce delay and clock. Default is `.default`.
    /// - Returns: A ``SearchableListStore`` wrapping this store.
    func searchable(
        queryBuilder: @escaping QueryBuilder<Query>,
        loadingConfiguration: LoadingConfiguration = .default
    ) -> SearchableListStore<Model, Query, Failure> {
        SearchableListStore(
            base: self,
            queryBuilder: queryBuilder,
            loadingConfiguration: loadingConfiguration
        )
    }
}
