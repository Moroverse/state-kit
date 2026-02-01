// CursorCacheStorage.swift
// Copyright (c) 2026 Moroverse
// Created by Daniel Moro on 2025-04-06 16:31 GMT.

/// Shared, non-isolated storage for cursor-based pagination caches.
///
/// Both `CursorPaginationCache` (actor) and `MainActorCursorPaginationCache` (@MainActor class)
/// delegate to this type for all data operations. Isolation is provided by the wrapper.
final class CursorCacheStorage<Element: Identifiable, Key: Hashable, Cursor: Hashable> {
    private var cache: [Element] = []
    private var idIndex: [Element.ID: Int] = [:]
    private var key: Key?
    private(set) var lastCursor: Cursor?

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
        rebuildIndex()
        return cache
    }

    @discardableResult
    func updateCache(
        differenceBuilder: (_ cache: [Element]) -> Difference<Element>
    ) -> (key: Key, lastCursor: Cursor?, elements: [Element])? {
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

        return (key, lastCursor, cache)
    }

    func cachedElement(with id: Element.ID) -> Element? {
        guard let index = idIndex[id] else { return nil }
        return cache[index]
    }

    private func rebuildIndex() {
        idIndex = Dictionary(uniqueKeysWithValues: cache.enumerated().map { ($1.id, $0) })
    }
}

extension CursorCacheStorage: @unchecked Sendable where Element: Sendable, Key: Sendable, Cursor: Sendable {}
