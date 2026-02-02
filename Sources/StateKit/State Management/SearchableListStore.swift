// SearchableListStore.swift
// Copyright (c) 2026 Moroverse
// Created by Daniel Moro on 2026-02-01 10:12 GMT.

import Clocks
import Foundation
import Observation

/// A decorator that adds debounced search to a ``ListStore``.
///
/// `SearchableListStore` wraps a ``ListStore`` and adds the ability to search
/// with automatic debouncing. It conforms to ``ListStateProviding`` and
/// ``SearchableListProviding``.
///
/// ### Usage:
///
/// ```swift
/// let store = ListStore(loader: api.fetch, queryProvider: { .default })
///     .searchable(queryBuilder: { term in Query(term: term) })
/// ```
///
/// - Note: This class is `@MainActor` and should be used from the main thread.
@MainActor
@Observable
public final class SearchableListStore<Model: RandomAccessCollection & Sendable, Query: Sendable & Equatable, Failure: Error>
    where Model.Element: Identifiable, Model.Element: Sendable {
    /// The underlying list store that performs actual loading.
    public let base: ListStore<Model, Query, Failure>

    @ObservationIgnored
    private var searchEngine: SearchEngine<Model, Query, Failure>

    /// Initializes a searchable wrapper around a ``ListStore``.
    ///
    /// - Parameters:
    ///   - base: The base list store to wrap.
    ///   - queryBuilder: A closure that builds a query from a search string.
    ///   - loadingConfiguration: Configuration for debounce delay and clock. Default is `.default`.
    public init(
        base: ListStore<Model, Query, Failure>,
        queryBuilder: @escaping QueryBuilder<Query>,
        loadingConfiguration: LoadingConfiguration = .default
    ) {
        self.base = base
        searchEngine = SearchEngine(
            queryBuilder: queryBuilder,
            loadingConfiguration: loadingConfiguration,
            loadModel: { [weak base] query, forceReload in
                guard let base else { throw SearchEngine<Model, Query, Failure>.SearchEngineError.instanceDeallocated }
                return try await base.loadModel(query: query, forceReload: forceReload)
            }
        )
    }

    // MARK: - ListStateProviding

    public var state: ListLoadingState<Model, Failure> {
        base.state
    }

    public var emptyStateConfiguration: EmptyStateConfiguration {
        base.emptyStateConfiguration
    }

    public func load(forceReload: Bool = false) async {
        do {
            let query = try searchEngine.buildQuery()
            _ = try await searchEngine.debouncedLoad(query: query, forceReload: forceReload)
        } catch {
            base.state.handleLoadingError(error)
        }
    }

    // MARK: - SearchableListProviding

    /// Initiates a search with the provided query string.
    ///
    /// Updates the internal query string and triggers a debounced load.
    ///
    /// - Parameter query: The search query string to perform.
    public func search(_ query: String) async {
        searchEngine.updateQueryString(query)
        do {
            let query = try searchEngine.buildQuery()
            _ = try await searchEngine.debouncedLoad(query: query, forceReload: false)
        } catch {
            base.state.handleLoadingError(error)
        }
    }

    /// Cancels any ongoing search or load operations.
    public func cancelSearch() {
        if case let .inProgress(cancellable, _) = base.state {
            cancellable.cancel()
        }
    }

    // MARK: - Additional

    /// Updates the query builder closure used to construct queries from search strings.
    ///
    /// - Parameter builder: The new query builder closure.
    public func updateQueryBuilder(_ builder: @escaping QueryBuilder<Query>) {
        searchEngine.updateQueryBuilder(builder)
    }

    /// Cancels any in-progress loading operation.
    public func cancel() {
        base.cancel()
    }
}

// MARK: - Protocol Conformances

extension SearchableListStore: ListStateProviding {}
extension SearchableListStore: SearchableListProviding {}
