// LastIDPaginationCache.swift
// Copyright (c) 2025 Moroverse
// Created by Daniel Moro on 2025-02-15 15:24 GMT.

actor LastIDPaginationCache<Element, Key: Hashable & Sendable> where Element: Identifiable & Sendable, Element.ID: Sendable {
    private var cache: [Element] = []
    private var key: Key?
    private var lastCursor: Element.ID?

    @discardableResult
    func updateCache(
        key: Key,
        lastCursor: Element.ID?,
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
    ) -> (key: Key, lastCursor: Element.ID?, elements: [Element])? {
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
