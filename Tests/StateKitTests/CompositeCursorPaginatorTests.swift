// CompositeCursorPaginatorTests.swift
// Copyright (c) 2025 Moroverse
// Created by Daniel Moro on 2025-04-08 12:52 GMT.

import Foundation
import Testing
import TestKit
@testable import StateKit

@MainActor
@Suite
struct CompositeCursorPaginatorTests {
    // MARK: - SUT Creation

    private func makeSUT() async -> (
        sut: CursorPaginator<TestPost, TestQuery, CompositeCursor>,
        loader: AsyncSpy<(elements: [TestPost], lastCursor: CompositeCursor?)>
    ) {
        let loader = AsyncSpy<(elements: [TestPost], lastCursor: CompositeCursor?)>()
        let sut = CursorPaginator<TestPost, TestQuery, CompositeCursor>(remoteLoader: loader.load)

        await Test.trackForMemoryLeaks(sut)
        await Test.trackForMemoryLeaks(loader)

        return (sut, loader)
    }

    // MARK: - Test Cases

    @Test("Load - Requests items from remote loader with composite cursor", .teardownTracking())
    func load_requestsItemsWithCompositeCursor() async throws {
        let query = TestQuery(value: "test-query")
        let (sut, loader) = await makeSUT()
        let post = TestPost(id: "1", title: "Post 1", createdAt: Date(timeIntervalSince1970: 1000))
        let response = (elements: [post], lastCursor: nil as CompositeCursor?)

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
                #expect(params[1] as? CompositeCursor? == nil)
            }
    }

    @Test("Load - Deliver items with composite cursor", .teardownTracking())
    func load_deliversItemsWithCompositeCursor() async throws {
        let date = Date(timeIntervalSince1970: 1000)
        let posts = [TestPost(id: "1", title: "Post 1", createdAt: date)]
        let (sut, loader) = await makeSUT()
        let response = (elements: posts, lastCursor: nil as CompositeCursor?)

        try await loader
            .async {
                try await sut.load(query: TestQuery(value: "test"))
            } completeWith: {
                .success(response)
            } expectationAfterCompletion: { result in
                #expect(result.items == posts)
                #expect(result.hasMore == false)
                #expect(result.loadMore == nil)
            }
    }

    @Test("Load - Deliver paginated result with composite cursor", .teardownTracking())
    func load_deliversPaginatedResultWithCompositeCursor() async throws {
        let date = Date(timeIntervalSince1970: 1000)
        let posts = [TestPost(id: "1", title: "Post 1", createdAt: date)]
        let lastCursor = CompositeCursor(id: "1", createdAt: date)
        let (sut, loader) = await makeSUT()
        let response = (elements: posts, lastCursor: lastCursor)

        try await loader
            .async {
                try await sut.load(query: TestQuery(value: "test"))
            } completeWith: {
                .success(response)
            } expectationAfterCompletion: { result in
                #expect(result.items == posts)
                #expect(result.hasMore == true)
                #expect(result.loadMore != nil)
            }
    }

    @Test("Load More - Requests items with composite cursor", .teardownTracking())
    func loadMore_requestsItemsWithCompositeCursor() async throws {
        let query = TestQuery(value: "test-query")
        let date1 = Date(timeIntervalSince1970: 1000)
        let date2 = Date(timeIntervalSince1970: 2000)

        let firstPosts = [TestPost(id: "1", title: "Post 1", createdAt: date1)]
        let nextPosts = [TestPost(id: "2", title: "Post 2", createdAt: date2)]
        let (sut, loader) = await makeSUT()

        // First page response with composite cursor
        let firstCursor = CompositeCursor(id: "1", createdAt: date1)
        let firstResponse = (elements: firstPosts, lastCursor: firstCursor as CompositeCursor?)

        // Second page response with no cursor (end of pagination)
        let nextResponse = (elements: nextPosts, lastCursor: nil as CompositeCursor?)

        var paginatedFirstPage: Paginated<TestPost>?
        // Load first page
        try await loader
            .async {
                try await sut.load(query: query)
            } completeWith: {
                .success(firstResponse)
            } expectationAfterCompletion: { firstPage in
                #expect(firstPage.items == firstPosts)
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
                // Verify the loader was called with the correct composite cursor
                #expect(loader.performCallCount == 2)
                let params = loader.params(at: 1)
                #expect(params.count == 2)
                #expect(params[0] as? TestQuery == query)

                let receivedCursor = params[1] as? CompositeCursor
                #expect(receivedCursor?.id == "1")
                #expect(receivedCursor?.createdAt == date1)

                // Verify the combined items are returned
                #expect(nextPage.items.count == 2)
                #expect(nextPage.items[0].id == "1")
                #expect(nextPage.items[1].id == "2")
                #expect(nextPage.hasMore == false)
            }
    }

    @Test("Update - Modifies cached elements with composite cursor", .teardownTracking())
    func update_modifiesCachedElementsWithCompositeCursor() async throws {
        let query = TestQuery(value: "test-query")
        let date1 = Date(timeIntervalSince1970: 1000)
        let date2 = Date(timeIntervalSince1970: 2000)

        let initialPosts = [
            TestPost(id: "1", title: "Post 1", createdAt: date1),
            TestPost(id: "2", title: "Post 2", createdAt: date2)
        ]
        let (sut, loader) = await makeSUT()
        let response = (elements: initialPosts, lastCursor: nil as CompositeCursor?)

        // First load to populate cache
        try await loader
            .async {
                try await sut.load(query: query)
            } completeWith: {
                .success(response)
            }

        // Update the cache
        let updatedTitle = "Updated Post 1"
        let updatedPost = TestPost(id: "1", title: updatedTitle, createdAt: date1)
        let date3 = Date(timeIntervalSince1970: 3000)
        let newPost = TestPost(id: "3", title: "Post 3", createdAt: date3)

        let updatedResult = try await sut.update { _ in
            Difference(
                insertions: [newPost],
                deletions: ["2"],
                updates: [updatedPost]
            )
        }

        // Verify the cache was updated correctly
        #expect(updatedResult.items.count == 2)
        #expect(updatedResult.items.contains(where: { $0.id == "1" && $0.title == updatedTitle }))
        #expect(updatedResult.items.contains(where: { $0.id == "3" && $0.title == "Post 3" }))
        #expect(!updatedResult.items.contains(where: { $0.id == "2" }))

        // Verify no additional remote calls were made
        #expect(loader.performCallCount == 1)
    }

    @Test("Get cached element - Returns element with composite cursor", .teardownTracking())
    func getCachedElement_returnsElementWithCompositeCursor() async throws {
        let query = TestQuery(value: "test-query")
        let date1 = Date(timeIntervalSince1970: 1000)
        let date2 = Date(timeIntervalSince1970: 2000)

        let posts = [
            TestPost(id: "1", title: "Post 1", createdAt: date1),
            TestPost(id: "2", title: "Post 2", createdAt: date2)
        ]
        let (sut, loader) = await makeSUT()
        let response = (elements: posts, lastCursor: nil as CompositeCursor?)

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
        #expect(cachedElement?.title == "Post 2")
        #expect(cachedElement?.createdAt == date2)
    }

    @Test("Subscribe - Emits updates when cache is modified", .teardownTracking())
    func subscribe_emitsUpdatesWhenCacheModified() async throws {
        let query = TestQuery(value: "test-query")
        let date1 = Date(timeIntervalSince1970: 1000)

        let initialPosts = [TestPost(id: "1", title: "Post 1", createdAt: date1)]
        let (sut, loader) = await makeSUT()
        let response = (elements: initialPosts, lastCursor: nil as CompositeCursor?)

        // First load to populate cache
        try await loader
            .async {
                try await sut.load(query: query)
            } completeWith: {
                .success(response)
            }

        // Subscribe to updates
        var receivedUpdates: [Paginated<TestPost>] = []
        let subscriptionTask = Task {
            var iterator = await sut.subscribe().makeAsyncIterator()
            if let update = await iterator.next() {
                receivedUpdates.append(update)
            }
        }

        // Give subscription time to start
        try await Task.sleep(for: .milliseconds(10))

        // Update the cache
        let updatedPost = TestPost(id: "1", title: "Updated Post 1", createdAt: date1)
        _ = try await sut.update { _ in
            Difference(insertions: [], deletions: [], updates: [updatedPost])
        }

        // Give time for the subscription to receive the update
        try await Task.sleep(for: .milliseconds(50))

        subscriptionTask.cancel()

        // Verify we received the update
        #expect(receivedUpdates.count == 1)
        #expect(receivedUpdates[0].items.first?.title == "Updated Post 1")
    }

    @Test("Subscribe - Supports multiple subscribers", .teardownTracking())
    func subscribe_supportsMultipleSubscribers() async throws {
        let query = TestQuery(value: "test-query")
        let date1 = Date(timeIntervalSince1970: 1000)

        let initialPosts = [TestPost(id: "1", title: "Post 1", createdAt: date1)]
        let (sut, loader) = await makeSUT()
        let response = (elements: initialPosts, lastCursor: nil as CompositeCursor?)

        // First load to populate cache
        try await loader
            .async {
                try await sut.load(query: query)
            } completeWith: {
                .success(response)
            }

        // Create two subscribers
        var subscriber1Updates: [Paginated<TestPost>] = []
        var subscriber2Updates: [Paginated<TestPost>] = []

        let task1 = Task {
            var iterator = await sut.subscribe().makeAsyncIterator()
            if let update = await iterator.next() {
                subscriber1Updates.append(update)
            }
        }

        let task2 = Task {
            var iterator = await sut.subscribe().makeAsyncIterator()
            if let update = await iterator.next() {
                subscriber2Updates.append(update)
            }
        }

        // Give subscriptions time to start
        try await Task.sleep(for: .milliseconds(10))

        // Update the cache
        let updatedPost = TestPost(id: "1", title: "Updated Post 1", createdAt: date1)
        _ = try await sut.update { _ in
            Difference(insertions: [], deletions: [], updates: [updatedPost])
        }

        // Give time for subscriptions to receive the update
        try await Task.sleep(for: .milliseconds(50))

        task1.cancel()
        task2.cancel()

        // Verify both subscribers received the update
        #expect(subscriber1Updates.count == 1)
        #expect(subscriber2Updates.count == 1)
        #expect(subscriber1Updates[0].items.first?.title == "Updated Post 1")
        #expect(subscriber2Updates[0].items.first?.title == "Updated Post 1")
    }
}

// MARK: - Test Helpers

/// Composite cursor using both ID and creation timestamp for pagination
private struct CompositeCursor: Hashable, Sendable {
    let id: String
    let createdAt: Date
}

private struct TestPost: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let createdAt: Date
}

private struct TestQuery: Hashable, Sendable {
    let value: String
}

private extension AsyncSpy {
    @Sendable
    func load(_ query: any Sendable, _ cursor: CompositeCursor?) async throws -> Result {
        try await perform(query, cursor)
    }
}
