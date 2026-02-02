// SelectableListStore.swift
// Copyright (c) 2026 Moroverse
// Created by Daniel Moro on 2026-02-01 10:12 GMT.

import Foundation
import Observation

/// A decorator that adds item selection to any ``ListStateProviding`` store.
///
/// `SelectableListStore` wraps a base store and adds selection tracking.
/// It conforms to ``ListStateProviding`` and ``SelectableListProviding``.
///
/// ### Usage:
///
/// ```swift
/// let store = ListStore(loader: api.fetch, queryProvider: { .default })
///     .searchable(queryBuilder: { term in Query(term: term) })
///     .paginated()
///     .selectable()
/// ```
///
/// - Note: This class is `@MainActor` and should be used from the main thread.
@MainActor
@Observable
public final class SelectableListStore<Base: ListStateProviding>
    where Base.Model.Element: Identifiable & Sendable {
    /// The underlying store being wrapped.
    public let base: Base

    private var _selectedID: Base.Model.Element.ID?

    /// Initializes a selectable wrapper around a base store.
    ///
    /// - Parameters:
    ///   - base: The base store to wrap.
    ///   - selection: An optional initial selection ID. Default is `nil`.
    init(
        base: Base,
        selection: Base.Model.Element.ID? = nil
    ) {
        self.base = base
        _selectedID = selection
    }

    // MARK: - ListStateProviding

    public var state: ListLoadingState<Base.Model, Base.Failure> {
        base.state
    }

    public func load(forceReload: Bool = false) async {
        await base.load(forceReload: forceReload)
    }

    // MARK: - SelectableListProviding

    /// The currently selected element's ID, if any.
    public var selection: Base.Model.Element.ID? {
        _selectedID
    }

    /// Selects the element with the given ID.
    ///
    /// - Parameter id: The ID of the element to select, or `nil` to clear the selection.
    public func select(_ id: Base.Model.Element.ID?) {
        _selectedID = id
    }
}

// MARK: - Protocol Conformances

extension SelectableListStore: ListStateProviding {}
extension SelectableListStore: SelectableListProviding {}

// MARK: - Conditional Conformances

extension SelectableListStore: SearchableListProviding where Base: SearchableListProviding {
    public func search(_ query: String) async {
        await base.search(query)
    }

    public func cancelSearch() {
        base.cancelSearch()
    }
}

extension SelectableListStore: PaginatedListProviding where Base: PaginatedListProviding {
    public func loadMore() async throws {
        try await base.loadMore()
    }
}
