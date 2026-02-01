// CursorPaginatorPage.swift
// Copyright (c) 2025 Moroverse
// Created by Daniel Moro on 2025-04-06 16:31 GMT.

/// Shared page-building logic for cursor-based paginators.
///
/// Both `CursorPaginator` (actor) and `MainActorCursorPaginator` (@MainActor class) use this
/// to construct `Paginated` results, eliminating duplication of the page-building logic.
enum CursorPaginatorPage {
    enum Error: Swift.Error {
        case paginatorDeallocated
    }

    static func makePage<Element: Identifiable & Sendable, Query: Hashable & Sendable, Cursor: Hashable & Sendable>(
        query: Query,
        lastCursor: Cursor?,
        items: [Element],
        loadMore: @escaping @Sendable (Query, Cursor) async throws -> Paginated<Element>
    ) -> Paginated<Element> {
        if let lastCursor {
            Paginated(
                items: items,
                loadMore: {
                    try await loadMore(query, lastCursor)
                }
            )
        } else {
            Paginated(items: items)
        }
    }
}
