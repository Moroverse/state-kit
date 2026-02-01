// OffsetPaginatorTests.swift
// Copyright (c) 2026 Moroverse
// Created by Daniel Moro on 2025-04-08 12:52 GMT.

import Foundation
import Testing
import TestKit
@testable import StateKit

@MainActor
@Suite
struct OffsetPaginatorTests {
    // MARK: - SUT Creation

    private func makeSUT() async -> (
        sut: OffsetPaginator<TestItem, TestQuery>,
        loader: AsyncSpy<(elements: [TestItem], hasNextPage: Bool)>
    ) {
        let loader = AsyncSpy<(elements: [TestItem], hasNextPage: Bool)>()
        let sut = OffsetPaginator<TestItem, TestQuery>(remoteLoader: loader.load)

        await Test.trackForMemoryLeaks(sut)
        await Test.trackForMemoryLeaks(loader)

        return (sut, loader)
    }

    // MARK: - Load Tests

    @Test("Load - Requests items from remote loader with offset 0", .teardownTracking())
    func load_requestsItemsFromRemoteLoaderWithZeroOffset() async throws {
        let query = TestQuery(value: "test-query")
        let (sut, loader) = await makeSUT()
        let response = (elements: [TestItem(id: "1", name: "Item 1")], hasNextPage: false)

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
                #expect(params[1] as? Int == 0)
            }
    }

    @Test("Load - Delivers items from remote loader", .teardownTracking())
    func load_deliversItemsFromRemoteLoader() async throws {
        let items = [TestItem(id: "1", name: "Item 1")]
        let (sut, loader) = await makeSUT()
        let response = (elements: items, hasNextPage: false)

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

    @Test("Load - Delivers paginated result when hasNextPage is true", .teardownTracking())
    func load_deliversPaginatedResultWithLoadMoreWhenHasNextPage() async throws {
        let items = [TestItem(id: "1", name: "Item 1")]
        let (sut, loader) = await makeSUT()
        let response = (elements: items, hasNextPage: true)

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

    // MARK: - Load More Tests

    @Test("Load More - Requests items with correct offset", .teardownTracking())
    func loadMore_requestsItemsWithCorrectOffset() async throws {
        let query = TestQuery(value: "test-query")
        let firstItems = [TestItem(id: "1", name: "Item 1"), TestItem(id: "2", name: "Item 2")]
        let nextItems = [TestItem(id: "3", name: "Item 3")]
        let (sut, loader) = await makeSUT()

        let firstResponse = (elements: firstItems, hasNextPage: true)
        let nextResponse = (elements: nextItems, hasNextPage: false)

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
                // Verify the loader was called with offset = count of first page items
                #expect(loader.performCallCount == 2)
                let params = loader.params(at: 1)
                #expect(params.count == 2)
                #expect(params[0] as? TestQuery == query)
                #expect(params[1] as? Int == 2) // offset = firstItems.count

                // Verify the combined items are returned
                #expect(nextPage.items.count == 3)
                #expect(nextPage.items[0].id == "1")
                #expect(nextPage.items[1].id == "2")
                #expect(nextPage.items[2].id == "3")
                #expect(nextPage.hasMore == false)
            }
    }

    // MARK: - Update Tests

    @Test("Update - Modifies cached elements", .teardownTracking())
    func update_modifiesCachedElements() async throws {
        let query = TestQuery(value: "test-query")
        let initialItems = [
            TestItem(id: "1", name: "Item 1"),
            TestItem(id: "2", name: "Item 2")
        ]
        let (sut, loader) = await makeSUT()
        let response = (elements: initialItems, hasNextPage: false)

        // First load to populate cache
        try await loader
            .async {
                try await sut.load(query: query)
            } completeWith: {
                .success(response)
            }

        // Update the cache
        let updatedItem = TestItem(id: "1", name: "Updated Item 1")
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
        #expect(updatedResult.items.contains(where: { $0.id == "1" && $0.name == "Updated Item 1" }))
        #expect(updatedResult.items.contains(where: { $0.id == "3" && $0.name == "Item 3" }))
        #expect(!updatedResult.items.contains(where: { $0.id == "2" }))

        // Verify no additional remote calls were made
        #expect(loader.performCallCount == 1)
    }

    @Test("Update - Returns empty paginated result when cache is empty", .teardownTracking())
    func update_returnsEmptyPaginatedResultWhenCacheIsEmpty() async throws {
        let (sut, _) = await makeSUT()

        let result = try await sut.update { _ in
            Difference(insertions: [], deletions: [], updates: [])
        }

        #expect(result.items.isEmpty)
        #expect(result.hasMore == false)
    }

    // MARK: - Cached Element Tests

    @Test("Get cached element - Returns element when exists in cache", .teardownTracking())
    func getCachedElement_returnsElementWhenExistsInCache() async throws {
        let query = TestQuery(value: "test-query")
        let items = [
            TestItem(id: "1", name: "Item 1"),
            TestItem(id: "2", name: "Item 2")
        ]
        let (sut, loader) = await makeSUT()
        let response = (elements: items, hasNextPage: false)

        try await loader
            .async {
                try await sut.load(query: query)
            } completeWith: {
                .success(response)
            }

        let cachedElement = await sut.cachedElement(with: "2")

        #expect(cachedElement?.id == "2")
        #expect(cachedElement?.name == "Item 2")
    }

    @Test("Get cached element - Returns nil when element doesn't exist", .teardownTracking())
    func getCachedElement_returnsNilWhenElementDoesNotExist() async throws {
        let query = TestQuery(value: "test-query")
        let items = [TestItem(id: "1", name: "Item 1")]
        let (sut, loader) = await makeSUT()
        let response = (elements: items, hasNextPage: false)

        try await loader
            .async {
                try await sut.load(query: query)
            } completeWith: {
                .success(response)
            }

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
    func load(_ query: any Sendable, _ offset: Int) async throws -> Result {
        try await perform(query, offset)
    }
}
