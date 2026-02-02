// CursorPaginationCache.swift
// Copyright (c) 2026 Moroverse
// Created by Daniel Moro on 2025-04-06 16:31 GMT.

actor CursorPaginationCache<Element: Identifiable & Sendable, Key: Hashable & Sendable, Cursor: Hashable & Sendable> where Element.ID: Sendable {
    private let storage = CursorCacheStorage<Element, Key, Cursor>()

    @discardableResult
    func updateCache(
        key: Key,
        lastCursor: Cursor?,
        elements: [Element]
    ) -> [Element] {
        storage.updateCache(key: key, lastCursor: lastCursor, elements: elements)
    }

    @discardableResult
    func updateCache(
        differenceBuilder: (_ cache: [Element]) -> Difference<Element>
    ) -> (key: Key, lastCursor: Cursor?, elements: [Element])? {
        storage.updateCache(differenceBuilder: differenceBuilder)
    }

    func cachedElement(for id: Element.ID) -> Element? {
        storage.cachedElement(for: id)
    }
}
