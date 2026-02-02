// OffsetPaginatorCache.swift
// Copyright (c) 2026 Moroverse
// Created by Daniel Moro on 2025-04-06 16:31 GMT.

actor OffsetPaginationCache<Element: Identifiable & Sendable, Key: Hashable & Sendable> where Element.ID: Sendable {
    struct CacheState {
        let key: Key
        let offset: Int
        let hasMore: Bool
        let elements: [Element]
    }

    private var cache: [Element] = []
    private var idIndex: [Element.ID: Int] = [:]
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
        rebuildIndex()
        return cache
    }

    @discardableResult
    func updateCache(
        differenceBuilder: (_ cache: [Element]) -> Difference<Element>
    ) -> CacheState? {
        guard let key else { return nil }

        let difference = differenceBuilder(cache)

        let deletionIndices = difference.deletions
            .compactMap { idIndex[$0] }
            .sorted(by: >)
        for index in deletionIndices {
            cache.remove(at: index)
        }

        // Rebuild after deletions shifted indices
        if !deletionIndices.isEmpty {
            rebuildIndex()
        }

        for update in difference.updates {
            if let index = idIndex[update.id] {
                cache[index] = update
            }
        }

        for insertion in difference.insertions {
            idIndex[insertion.id] = cache.count
            cache.append(insertion)
        }

        return CacheState(key: key, offset: offset, hasMore: hasMore, elements: cache)
    }

    var currentOffset: Int {
        offset
    }

    func cachedElement(for id: Element.ID) -> Element? {
        guard let index = idIndex[id] else { return nil }
        return cache[index]
    }

    private func rebuildIndex() {
        idIndex = Dictionary(uniqueKeysWithValues: cache.enumerated().map { ($1.id, $0) })
    }
}
