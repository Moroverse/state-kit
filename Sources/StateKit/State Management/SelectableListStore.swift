// SelectableListStore.swift
// Copyright (c) 2025 Moroverse
// Created by Daniel Moro on 2026-02-01 GMT.

import Foundation
import Observation

/// A decorator that adds item selection to any ``ListStateProviding`` store.
///
/// `SelectableListStore` wraps a base store and adds selection tracking
/// with an optional callback. It conforms to ``ListStateProviding`` and
/// ``SelectableListProviding``.
///
/// ### Usage:
///
/// ```swift
/// let store = ListStore(loader: api.fetch, queryFactory: { .default })
///     .searchable(queryBuilder: { term in Query(term: term) })
///     .paginated()
///     .selectable(onSelectionChange: { item in handle(item) })
/// ```
///
/// - Note: This class is `@MainActor` and should be used from the main thread.
@MainActor
@Observable
public final class SelectableListStore<Base: ListStateProviding>
    where Base.Model.Element: Identifiable & Sendable {

    /// The underlying store being wrapped.
    public let base: Base

    private var selectionManager: CallbackSelectionManager<Base.Model.Element>

    /// Initializes a selectable wrapper around a base store.
    ///
    /// - Parameters:
    ///   - base: The base store to wrap.
    ///   - selection: An optional initial selection ID. Default is `nil`.
    ///   - onSelectionChange: An optional callback triggered when selection changes.
    public init(
        base: Base,
        selection: Base.Model.Element.ID? = nil,
        onSelectionChange: ((Base.Model.Element?) -> Void)? = nil
    ) {
        self.base = base
        let manager = CallbackSelectionManager(onSelectionChange: onSelectionChange)
        manager.selectedID = selection
        self.selectionManager = manager
    }

    // MARK: - ListStateProviding

    public var state: ListLoadingState<Base.Model, Base.Failure> {
        base.state
    }

    public func load(forceReload: Bool = false) async {
        await base.load(forceReload: forceReload)
    }

    public func element(at index: Int) -> Base.Model.Element? {
        base.element(at: index)
    }

    // MARK: - SelectableListProviding

    /// The currently selected element's ID, if any.
    public var selection: Base.Model.Element.ID? {
        selectionManager.selectedID
    }

    /// Selects the element with the given ID.
    ///
    /// If the store is in a `.loaded` state, this also triggers the selection callback
    /// (if one was provided at initialization).
    ///
    /// - Parameter id: The ID of the element to select, or `nil` to clear the selection.
    public func select(_ id: Base.Model.Element.ID?) {
        selectionManager.selectedID = id

        if case let .loaded(model, _) = base.state {
            selectionManager.handleSelection(from: model)
        }
    }

    /// Whether this store can handle selection (i.e., has a callback configured).
    public var canHandleSelection: Bool {
        selectionManager.canHandleSelection
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

    public func cancelSearch() async {
        await base.cancelSearch()
    }
}

extension SelectableListStore: PaginatedListProviding where Base: PaginatedListProviding {
    public func loadMore() async throws {
        try await base.loadMore()
    }
}
