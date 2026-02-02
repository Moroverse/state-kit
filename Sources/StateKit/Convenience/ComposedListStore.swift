// ComposedListStore.swift
// Copyright (c) 2026 Moroverse
// Created by Daniel Moro on 2026-02-02.

/// A namespace providing convenience typealiases for common decorator stack combinations.
///
/// The decorator pattern in StateKit creates deeply nested generic types. This namespace
/// provides short aliases for the most common compositions:
///
/// ```swift
/// // Before:
/// SelectableListStore<PaginatedListStore<SearchableListStore<Paginated<Article>, ArticleQuery, any Error>, Article>>
///
/// // After:
/// ComposedListStore<Article, ArticleQuery, any Error>.Full
/// ```
///
/// ### Available Compositions
///
/// | Typealias              | Decorators                              |
/// |------------------------|-----------------------------------------|
/// | ``SearchablePaginated``| Searchable + Paginated                  |
/// | ``Full``               | Searchable + Paginated + Selectable     |
/// | ``PaginatedOnly``      | Paginated                               |
/// | ``PaginatedSelectable``| Paginated + Selectable                  |
/// | ``SearchableSelectable``| Searchable + Selectable                |
public enum ComposedListStore<
    Element: Identifiable & Sendable,
    Query: Sendable & Equatable,
    Failure: Error
> {
    /// A searchable and paginated list store.
    ///
    /// Equivalent to:
    /// ```swift
    /// PaginatedListStore<SearchableListStore<Paginated<Element>, Query, Failure>, Element>
    /// ```
    public typealias SearchablePaginated = PaginatedListStore<
        SearchableListStore<Paginated<Element>, Query, Failure>, Element
    >

    /// A searchable, paginated, and selectable list store — the full decorator stack.
    ///
    /// Equivalent to:
    /// ```swift
    /// SelectableListStore<PaginatedListStore<SearchableListStore<Paginated<Element>, Query, Failure>, Element>>
    /// ```
    public typealias Full = SelectableListStore<
        PaginatedListStore<
            SearchableListStore<Paginated<Element>, Query, Failure>, Element
        >
    >

    /// A paginated list store without search.
    ///
    /// Equivalent to:
    /// ```swift
    /// PaginatedListStore<ListStore<Paginated<Element>, Query, Failure>, Element>
    /// ```
    public typealias PaginatedOnly = PaginatedListStore<
        ListStore<Paginated<Element>, Query, Failure>, Element
    >

    /// A paginated and selectable list store without search.
    ///
    /// Equivalent to:
    /// ```swift
    /// SelectableListStore<PaginatedListStore<ListStore<Paginated<Element>, Query, Failure>, Element>>
    /// ```
    public typealias PaginatedSelectable = SelectableListStore<
        PaginatedListStore<ListStore<Paginated<Element>, Query, Failure>, Element>
    >

    /// A searchable and selectable list store without pagination.
    ///
    /// Equivalent to:
    /// ```swift
    /// SelectableListStore<SearchableListStore<[Element], Query, Failure>>
    /// ```
    public typealias SearchableSelectable = SelectableListStore<
        SearchableListStore<[Element], Query, Failure>
    >
}
