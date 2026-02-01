// CursorPaginationCache.swift
// Copyright (c) 2025 Moroverse
// Created by Daniel Moro on 2025-04-06 16:31 GMT.

actor CursorPaginationCache<Element, Key: Hashable & Sendable, Cursor: Hashable & Sendable> where Element: Identifiable & Sendable, Element.ID: Sendable {
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

    func cachedElement(with id: Element.ID) -> Element? {
        storage.cachedElement(with: id)
    }
}
