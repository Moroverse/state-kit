// OffsetPaginatorCache.swift
// Copyright (c) 2025 Moroverse
// Created by Daniel Moro on 2025-04-06 16:31 GMT.

actor OffsetPaginationCache<Element, Key: Hashable & Sendable> where Element: Identifiable & Sendable, Element.ID: Sendable {
    private var cache: [Element] = []
    private var key: Key?
    private var offset: Int = 0
    private var hasMore: Bool = true

    @discardableResult
    func updateCache(
        key: Key,
        offset: Int,
        hasMore: Bool,
        elements: [Element]
    ) -> [Element] {
        if self.key != key {
            self.key = key
            cache = elements
        } else {
            cache += elements
        }
        self.offset = offset
        self.hasMore = hasMore
        return cache
    }

    @discardableResult
    func updateCache(
        differenceBuilder: (_ cache: [Element]) -> Difference<Element>
    ) -> (key: Key, offset: Int, hasMore: Bool, elements: [Element])? { // swiftlint:disable:this large_tuple
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

        return (key, offset, hasMore, cache)
    }

    func cachedElement(with id: Element.ID) -> Element? {
        cache.first(where: { $0.id == id })
    }
}
