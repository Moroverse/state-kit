// LastIDPaginationCacheTests.swift
// Copyright (c) 2025 Moroverse
// Created by Daniel Moro on 2025-07-31.

import Foundation
@testable import SharedFoundation
import SharedTesting
import Testing

@Suite
struct LastIDPaginationCacheTests {
    // MARK: - SUT Creation

    private func makeSUT() async -> LastIDPaginationCache<TestItem, TestKey> {
        let sut = LastIDPaginationCache<TestItem, TestKey>()
        await Test.trackForMemoryLeaks(sut)
        return sut
    }

    // MARK: - Test Cases

    @Test(.teardownTracking())
    func init_createsEmptyCache() async throws {
        let sut = await makeSUT()
        let result = await sut.updateCache { _ in
            Difference(insertions: [], deletions: [], updates: [])
        }

        #expect(result == nil)
    }

    @Test(.teardownTracking())
    func updateCache_withKey_addsElementsToEmptyCache() async throws {
        let sut = await makeSUT()
        let key = TestKey(value: "test-key")
        let items = [TestItem(id: "1", name: "Item 1"), TestItem(id: "2", name: "Item 2")]
        let lastCursor = items.last?.id

        let result = await sut.updateCache(key: key, lastCursor: lastCursor, elements: items)

        #expect(result.count == 2)
        #expect(result[0].id == "1")
        #expect(result[1].id == "2")
    }

    @Test(.teardownTracking())
    func updateCache_withSameKey_appendsElements() async throws {
        let sut = await makeSUT()
        let key = TestKey(value: "test-key")
        let firstItems = [TestItem(id: "1", name: "Item 1")]
        let secondItems = [TestItem(id: "2", name: "Item 2")]

        _ = await sut.updateCache(key: key, lastCursor: firstItems.last?.id, elements: firstItems)
        let result = await sut.updateCache(key: key, lastCursor: secondItems.last?.id, elements: secondItems)

        #expect(result.count == 2)
        #expect(result[0].id == "1")
        #expect(result[1].id == "2")
    }

    @Test(.teardownTracking())
    func updateCache_withDifferentKey_replacesExistingElements() async throws {
        let sut = await makeSUT()
        let firstKey = TestKey(value: "key-1")
        let secondKey = TestKey(value: "key-2")
        let firstItems = [TestItem(id: "1", name: "Item 1")]
        let secondItems = [TestItem(id: "2", name: "Item 2")]

        _ = await sut.updateCache(key: firstKey, lastCursor: firstItems.last?.id, elements: firstItems)
        let result = await sut.updateCache(key: secondKey, lastCursor: secondItems.last?.id, elements: secondItems)

        #expect(result.count == 1)
        #expect(result[0].id == "2")
    }

    @Test(.teardownTracking())
    func updateCache_withDifference_insertsNewElement() async throws {
        let sut = await makeSUT()
        let key = TestKey(value: "test-key")
        let initialItems = [TestItem(id: "1", name: "Item 1")]
        let newItem = TestItem(id: "2", name: "Item 2")

        _ = await sut.updateCache(key: key, lastCursor: initialItems.last?.id, elements: initialItems)
        let result = await sut.updateCache { _ in
            Difference(insertions: [newItem], deletions: [], updates: [])
        }

        #expect(result?.elements.count == 2)
        #expect(result?.elements[0].id == "1")
        #expect(result?.elements[1].id == "2")
        #expect(result?.key.value == "test-key")
    }

    @Test(.teardownTracking())
    func updateCache_withDifference_updatesExistingElement() async throws {
        let sut = await makeSUT()
        let key = TestKey(value: "test-key")
        let initialItems = [TestItem(id: "1", name: "Item 1")]
        let updatedItem = TestItem(id: "1", name: "Updated Item 1")

        _ = await sut.updateCache(key: key, lastCursor: initialItems.last?.id, elements: initialItems)
        let result = await sut.updateCache { _ in
            Difference(insertions: [], deletions: [], updates: [updatedItem])
        }

        #expect(result?.elements.count == 1)
        #expect(result?.elements[0].id == "1")
        #expect(result?.elements[0].name == "Updated Item 1")
    }

    @Test(.teardownTracking())
    func updateCache_withDifference_deletesExistingElement() async throws {
        let sut = await makeSUT()
        let key = TestKey(value: "test-key")
        let initialItems = [
            TestItem(id: "1", name: "Item 1"),
            TestItem(id: "2", name: "Item 2")
        ]

        _ = await sut.updateCache(key: key, lastCursor: initialItems.last?.id, elements: initialItems)
        let result = await sut.updateCache { _ in
            Difference(insertions: [], deletions: ["1"], updates: [])
        }

        #expect(result?.elements.count == 1)
        #expect(result?.elements[0].id == "2")
    }

    @Test(.teardownTracking())
    func updateCache_withCompleteDifference_performsAllOperations() async throws {
        let sut = await makeSUT()
        let key = TestKey(value: "test-key")
        let initialItems = [
            TestItem(id: "1", name: "Item 1"),
            TestItem(id: "2", name: "Item 2"),
            TestItem(id: "3", name: "Item 3")
        ]

        let newItem = TestItem(id: "4", name: "Item 4")
        let updatedItem = TestItem(id: "2", name: "Updated Item 2")

        _ = await sut.updateCache(key: key, lastCursor: initialItems.last?.id, elements: initialItems)
        let result = await sut.updateCache { _ in
            Difference(insertions: [newItem], deletions: ["1"], updates: [updatedItem])
        }

        #expect(result?.elements.count == 3)
        #expect(result?.elements.contains(where: { $0.id == "1" }) == false)
        #expect(result?.elements.contains(where: { $0.id == "2" && $0.name == "Updated Item 2" }) == true)
        #expect(result?.elements.contains(where: { $0.id == "3" }) == true)
        #expect(result?.elements.contains(where: { $0.id == "4" }) == true)
    }

    @Test(.teardownTracking())
    func cachedElement_returnsElementWithMatchingID() async throws {
        let sut = await makeSUT()
        let key = TestKey(value: "test-key")
        let items = [
            TestItem(id: "1", name: "Item 1"),
            TestItem(id: "2", name: "Item 2")
        ]

        _ = await sut.updateCache(key: key, lastCursor: items.last?.id, elements: items)
        let result = await sut.cachedElement(with: "2")

        #expect(result?.id == "2")
        #expect(result?.name == "Item 2")
    }

    @Test(.teardownTracking())
    func cachedElement_returnsNilForNonExistentID() async throws {
        let sut = await makeSUT()
        let key = TestKey(value: "test-key")
        let items = [TestItem(id: "1", name: "Item 1")]

        _ = await sut.updateCache(key: key, lastCursor: items.last?.id, elements: items)
        let result = await sut.cachedElement(with: "non-existent")

        #expect(result == nil)
    }
}

// MARK: - Test Helpers

private struct TestItem: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
}

private struct TestKey: Hashable, Sendable {
    let value: String
}
