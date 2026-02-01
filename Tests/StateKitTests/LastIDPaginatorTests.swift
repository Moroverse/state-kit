// LastIDPaginatorTests.swift
// Copyright (c) 2026 Moroverse
// Created by Daniel Moro on 2025-04-08 12:52 GMT.

import Foundation
import Testing
import TestKit
@testable import StateKit

@MainActor
@Suite
struct LastIDPaginatorTests {
    // MARK: - SUT Creation

    private func makeSUT() async -> (
        sut: LastIDPaginator<TestItem, TestQuery>,
        loader: AsyncSpy<(elements: [TestItem], lastCursor: String?)>
    ) {
        let loader = AsyncSpy<(elements: [TestItem], lastCursor: String?)>()
        let sut = LastIDPaginator<TestItem, TestQuery>(remoteLoader: loader.load)

        await Test.trackForMemoryLeaks(sut)
        await Test.trackForMemoryLeaks(loader)

        return (sut, loader)
    }

    // MARK: - Test Cases

    @Test("Load - Requests items from remote loader", .teardownTracking())
    func load_requestsItemsFromRemoteLoaderWithoutCursor() async throws {
        let query = TestQuery(value: "test-query")
        let (sut, loader) = await makeSUT()
        let response = (elements: [TestItem(id: "1", name: "Item 1")], lastCursor: nil as String?)

        try await loader
            .async {
                _ = try await sut.load(query: query)
            } completeWith: {
                .success(response)
            } expectationAfterCompletion: { _ in
                #expect(loader.performCallCount == 1)
                let params = loader.params(at: 0)
                #expect(params.count == 2)
                #expect(params[0] as? TestQuery == query)
                #expect(params[1] as? String? == nil)
            }
    }

    @Test("Load - Deliver items", .teardownTracking())
    func load_deliversItemsFromRemoteLoader() async throws {
        let items = [TestItem(id: "1", name: "Item 1")]
        let (sut, loader) = await makeSUT()
        let response = (elements: items, lastCursor: nil as String?)

        try await loader
            .async {
                try await sut.load(query: TestQuery(value: "test"))
            } completeWith: {
                .success(response)
            } expectationAfterCompletion: { result in
                #expect(result.items == items)
                #expect(result.hasMore == false)
                #expect(result.loadMore == nil)
            }
    }

    @Test("Load - Deliver paginated result", .teardownTracking())
    func load_deliversPaginatedResultWithLoadMoreWhenLastCursorExists() async throws {
        let items = [TestItem(id: "1", name: "Item 1")]
        let lastCursor = "1"
        let (sut, loader) = await makeSUT()
        let response = (elements: items, lastCursor: lastCursor)

        try await loader
            .async {
                try await sut.load(query: TestQuery(value: "test"))
            } completeWith: {
                .success(response)
            } expectationAfterCompletion: { result in
                #expect(result.items == items)
                #expect(result.hasMore == true)
                #expect(result.loadMore != nil)
            }
    }

    @Test("Load More - Requests items from remote loader", .teardownTracking())
    func loadMore_requestsItemsFromRemoteLoaderWithLastCursor() async throws {
        let query = TestQuery(value: "test-query")
        let firstItems = [TestItem(id: "1", name: "Item 1")]
        let nextItems = [TestItem(id: "2", name: "Item 2")]
        let (sut, loader) = await makeSUT()

        // First page response with a lastCursor to enable pagination
        let firstResponse = (elements: firstItems, lastCursor: "1" as String?)

        // Second page response with no lastCursor (end of pagination)
        let nextResponse = (elements: nextItems, lastCursor: nil as String?)

        var paginatedFirstPage: Paginated<TestItem>?
        // Load first page
        try await loader
            .async {
                try await sut.load(query: query)
            } completeWith: {
                .success(firstResponse)
            } expectationAfterCompletion: { firstPage in
                #expect(firstPage.items == firstItems)
                #expect(firstPage.hasMore == true)
                paginatedFirstPage = firstPage
            }

        let loadMore = try #require(paginatedFirstPage?.loadMore)
        // Load next page
        try await loader
            .async(at: 1) {
                try await loadMore()
            } completeWith: {
                .success(nextResponse)
            } expectationAfterCompletion: { nextPage in
                // Verify the loader was called with the correct cursor
                #expect(loader.performCallCount == 2)
                let params = loader.params(at: 1)
                #expect(params.count == 2)
                #expect(params[0] as? TestQuery == query)
                #expect(params[1] as? String == "1")

                // Verify the combined items are returned
                #expect(nextPage.items.count == 2)
                #expect(nextPage.items[0].id == "1")
                #expect(nextPage.items[1].id == "2")
                #expect(nextPage.hasMore == false)
            }
    }

    @Test("Load - Propagates error from remote loader", .teardownTracking())
    func load_propagatesErrorFromRemoteLoader() async {
        let query = TestQuery(value: "test-query")
        let (sut, loader) = await makeSUT()
        let expectedError = NSError(domain: "test-error", code: 1)

        await #expect(throws: expectedError, performing: {
            try await loader
                .async {
                    try await sut.load(query: query)
                } completeWith: {
                    .failure(expectedError)
                }
        })
    }

    @Test("Load - Uses cache for repeated queries", .teardownTracking(), .disabled("Not yet functional"))
    func load_usesCacheForRepeatedQueries() async throws {
        let query = TestQuery(value: "test-query")
        let items = [TestItem(id: "1", name: "Item 1")]
        let (sut, loader) = await makeSUT()
        let response = (elements: items, lastCursor: nil as String?)

        var result: Paginated<TestItem>?
        // First load
        try await loader
            .async {
                try await sut.load(query: query)
            } completeWith: {
                .success(response)
            } expectationAfterCompletion: {
                result = $0
            }

        // Second load with same query
        try await loader
            .async(at: 1) {
                try await sut.load(query: query)
            } completeWith: {
                .success(response)
            } expectationAfterCompletion: {
                #expect(result?.items == $0.items)
            }

        // Loader should only be called once
        #expect(loader.performCallCount == 1)
    }

    @Test("Update - Modifies cached elements", .teardownTracking())
    func update_modifiesCachedElements() async throws {
        let query = TestQuery(value: "test-query")
        let initialItems = [
            TestItem(id: "1", name: "Item 1"),
            TestItem(id: "2", name: "Item 2")
        ]
        let (sut, loader) = await makeSUT()
        let response = (elements: initialItems, lastCursor: nil as String?)

        // First load to populate cache
        try await loader
            .async {
                try await sut.load(query: query)
            } completeWith: {
                .success(response)
            }

        // Update the cache
        let updatedName = "Updated Item 1"
        let updatedItem = TestItem(id: "1", name: updatedName)
        let newItem = TestItem(id: "3", name: "Item 3")

        let updatedResult = try await sut.update { _ in
            Difference(
                insertions: [newItem],
                deletions: ["2"],
                updates: [updatedItem]
            )
        }

        // Verify the cache was updated correctly
        #expect(updatedResult.items.count == 2)
        #expect(updatedResult.items.contains(where: { $0.id == "1" && $0.name == updatedName }))
        #expect(updatedResult.items.contains(where: { $0.id == "3" && $0.name == "Item 3" }))
        #expect(!updatedResult.items.contains(where: { $0.id == "2" }))

        // Verify no additional remote calls were made
        #expect(loader.performCallCount == 1)
    }

    @Test("Update - Returns empty paginated result when cache is empty", .teardownTracking())
    func update_returnsEmptyPaginatedResultWhenCacheIsEmpty() async throws {
        let (sut, _) = await makeSUT()

        // Attempt update without loading first
        let result = try await sut.update { _ in
            Difference(insertions: [], deletions: [], updates: [])
        }

        #expect(result.items.isEmpty)
        #expect(result.hasMore == false)
    }

    @Test("Get cached element - Returns element when exists in cache", .teardownTracking())
    func getCachedElement_returnsElementWhenExistsInCache() async throws {
        let query = TestQuery(value: "test-query")
        let items = [
            TestItem(id: "1", name: "Item 1"),
            TestItem(id: "2", name: "Item 2")
        ]
        let (sut, loader) = await makeSUT()
        let response = (elements: items, lastCursor: nil as String?)

        // Load to populate cache
        try await loader
            .async {
                try await sut.load(query: query)
            } completeWith: {
                .success(response)
            }

        // Get cached element
        let cachedElement = await sut.cachedElement(with: "2")

        #expect(cachedElement?.id == "2")
        #expect(cachedElement?.name == "Item 2")
    }

    @Test("Get cached element - Returns nil when element doesn't exist", .teardownTracking())
    func getCachedElement_returnsNilWhenElementDoesNotExist() async throws {
        let query = TestQuery(value: "test-query")
        let items = [TestItem(id: "1", name: "Item 1")]
        let (sut, loader) = await makeSUT()
        let response = (elements: items, lastCursor: nil as String?)

        // Load to populate cache
        try await loader
            .async {
                try await sut.load(query: query)
            } completeWith: {
                .success(response)
            }

        // Get non-existent cached element
        let cachedElement = await sut.cachedElement(with: "999")

        #expect(cachedElement == nil)
    }
}

// MARK: - Test Helpers

private struct TestItem: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
}

private struct TestQuery: Hashable, Sendable {
    let value: String
}

private extension AsyncSpy {
    @Sendable
    func load(_ query: any Sendable, _ cursor: String?) async throws -> Result {
        try await perform(query, cursor)
    }
}
