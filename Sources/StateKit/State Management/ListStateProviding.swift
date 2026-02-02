// ListStateProviding.swift
// Copyright (c) 2026 Moroverse
// Created by Daniel Moro on 2026-02-01 03:54 GMT.

import Foundation

/// Protocol defining the observable state interface for list views.
///
/// Views should depend on this protocol rather than concrete store types,
/// enabling ViewModels to provide list state without requiring pagination,
/// search, or selection capabilities.
///
/// ``ListStore`` conforms to this protocol regardless of initialization mode.
///
/// ### Usage Example:
///
/// ```swift
/// struct MyListView<Provider: ListStateProviding>: View {
///     @Bindable var provider: Provider
///
///     var body: some View {
///         switch provider.state {
///         case .idle:
///             Text("Ready to load")
///         case .loaded(let items, _):
///             List(items) { item in ... }
///         // ...
///         }
///     }
/// }
/// ```
@MainActor
public protocol ListStateProviding<Model, Failure>: AnyObject, Observable {
    associatedtype Model: RandomAccessCollection
        where Model.Element: Identifiable & Sendable, Model: Sendable
    associatedtype Failure: Error

    var state: ListLoadingState<Model, Failure> { get }
    var emptyStateConfiguration: EmptyStateConfiguration { get }
    func load(forceReload: Bool) async
}

public extension ListStateProviding {
    func element(at index: Int) -> Model.Element? {
        state.element(at: index)
    }
}

/// Protocol for list providers that support pagination (load-more).
///
/// Extends ``ListStateProviding`` directly — pagination is orthogonal to search and selection.
/// Combine with other protocols as needed: `PaginatedListProviding & SearchableListProviding`.
/// ``PaginatedListStore`` conforms to this protocol via the `.paginated()` decorator.
@MainActor
public protocol PaginatedListProviding: ListStateProviding {
    func loadMore() async throws
}

/// Protocol for list providers that support text search with debouncing.
///
/// Extends ``ListStateProviding`` directly — search is orthogonal to pagination and selection.
/// Combine with other protocols as needed: `SearchableListProviding & PaginatedListProviding`.
@MainActor
public protocol SearchableListProviding: ListStateProviding {
    func search(_ query: String) async
    func cancelSearch()
}

/// Protocol for list providers that support item selection.
///
/// Extends ``ListStateProviding`` directly — selection is orthogonal to pagination and search.
/// Combine with other protocols as needed: `SelectableListProviding & PaginatedListProviding`.
@MainActor
public protocol SelectableListProviding: ListStateProviding {
    var selection: Model.Element.ID? { get }
    func select(_ id: Model.Element.ID?)
}

// MARK: - ListStore Conformances

extension ListStore: ListStateProviding {}
