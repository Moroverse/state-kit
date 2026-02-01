// SearchEngine.swift
// Copyright (c) 2026 Moroverse
// Created by Daniel Moro on 2026-02-01 05:29 GMT.

import Clocks
import Foundation

/// Internal engine that encapsulates search coordination with debounce.
///
/// Manages the `latestQueryString`, `queryBuilder`, and `Debounce` actor.
/// Used by `ListStore` only — `BasicListStore` has no search capability.
@MainActor
final class SearchEngine<Model: RandomAccessCollection & Sendable, Query: Sendable & Equatable, Failure: Error>
    where Model.Element: Identifiable & Sendable {
    enum SearchEngineError: LocalizedError, CustomStringConvertible {
        case instanceDeallocated

        var description: String {
            switch self {
            case .instanceDeallocated:
                "SearchEngine's owning ListStore was deallocated"
            }
        }
    }

    private(set) var latestQueryString = ""
    private(set) var queryBuilder: QueryBuilder<Query>

    /// The debounce actor. Initialized lazily on first access.
    private var _debounce: Debounce<Query, Bool, Model>?

    private let loadingConfiguration: LoadingConfiguration
    let loadModel: @MainActor @Sendable (Query, Bool) async throws -> Model

    init(
        queryBuilder: @escaping QueryBuilder<Query>,
        loadingConfiguration: LoadingConfiguration,
        loadModel: @MainActor @escaping @Sendable (Query, Bool) async throws -> Model
    ) {
        self.queryBuilder = queryBuilder
        self.loadingConfiguration = loadingConfiguration
        self.loadModel = loadModel
    }

    /// Builds a query from the current `latestQueryString`.
    func buildQuery() throws -> Query {
        try queryBuilder(latestQueryString)
    }

    /// Updates the latest query string (called by `search()`).
    func updateQueryString(_ query: String) {
        latestQueryString = query
    }

    /// Updates the query builder closure.
    func updateQueryBuilder(_ builder: @escaping QueryBuilder<Query>) {
        queryBuilder = builder
    }

    /// Executes a debounced load for the given query.
    ///
    /// - Parameters:
    ///   - query: The query to load.
    ///   - forceReload: Whether to bypass caching.
    /// - Returns: The loaded model.
    func debouncedLoad(query: Query, forceReload: Bool) async throws -> Model {
        let debounce = getOrCreateDebounce()
        return try await debounce(query, forceReload)
    }

    private func getOrCreateDebounce() -> Debounce<Query, Bool, Model> {
        if let existing = _debounce {
            return existing
        }
        let loadModel = loadModel
        let debounce = Debounce<Query, Bool, Model>(
            call: { @Sendable query, forceReload in
                try await loadModel(query, forceReload)
            },
            after: loadingConfiguration.debounceDelay,
            clock: loadingConfiguration.clock
        )
        _debounce = debounce
        return debounce
    }
}
