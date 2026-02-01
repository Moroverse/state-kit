// ListStateProviding.swift
// Copyright (c) 2025 Moroverse
// Created by Daniel Moro on 2026-01-31 GMT.

import Foundation

/// Protocol defining the observable state interface for list views.
///
/// Views should depend on this protocol rather than concrete `ListStore`,
/// enabling ViewModels to provide list state without inheriting all of
/// `ListStore`'s features (pagination, selection, debouncing, etc.).
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
    func load(forceReload: Bool) async
    func loadMore() async throws
    func element(at index: Int) -> Model.Element?
}

/// Protocol for list providers that support text search with debouncing.
@MainActor
public protocol SearchableListProviding: ListStateProviding {
    func search(_ query: String) async
    func cancelSearch() async
}

/// Protocol for list providers that support item selection.
@MainActor
public protocol SelectableListProviding: ListStateProviding {
    var selection: Model.Element.ID? { get set }
    var canHandleSelection: Bool { get }
}

// MARK: - ListStore Conformances

extension ListStore: ListStateProviding {}
extension ListStore: SearchableListProviding {}
extension ListStore: SelectableListProviding {}
