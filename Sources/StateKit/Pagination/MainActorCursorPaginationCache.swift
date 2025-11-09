// MainActorCursorPaginationCache.swift
// Copyright (c) 2025 Moroverse
// Created by Daniel Moro on 2025-04-06 16:31 GMT.

@MainActor
final class MainActorCursorPaginationCache<Element, Key: Hashable, Cursor: Hashable> where Element: Identifiable {
    private var cache: [Element] = []
    private var key: Key?
    private var lastCursor: Cursor?

    @discardableResult
    func updateCache(
        key: Key,
        lastCursor: Cursor?,
        elements: [Element]
    ) -> [Element] {
        if self.key != key {
            self.key = key
            cache = elements
        } else {
            cache += elements
        }
        self.lastCursor = lastCursor
        return cache
    }

    @discardableResult
    func updateCache(
        differenceBuilder: (_ cache: [Element]) -> Difference<Element>
    ) -> (key: Key, lastCursor: Cursor?, elements: [Element])? {
        guard let key else { return nil }

        let difference = differenceBuilder(cache)
        for deletion in difference.deletions {
            cache.removeAll { $0.id == deletion }
        }

        for update in difference.updates {
            if let index = cache.firstIndex(where: { $0.id == update.id }) {
                cache[index] = update
            }
        }

        for insertion in difference.insertions {
            cache.append(insertion)
        }

        return (key, lastCursor, cache)
    }

    func cachedElement(with id: Element.ID) -> Element? {
        cache.first(where: { $0.id == id })
    }
}
