// ListModelTests.swift
// Copyright (c) 2025 Moroverse
// Created by Daniel Moro on 2025-04-07 08:57 GMT.

import Clocks
import ConcurrencyExtras
import Foundation
import Testing
import TestKit
@testable import StateKit

@MainActor
@Suite
struct ListModelTests {
    // MARK: - SUT Creation

    private func makeSUTPaginated() async -> (
        sut: ListModel<Paginated<TestListItem>, TestQuery>,
        loader: AsyncSpy<Paginated<TestListItem>>,
        queryBuilder: QueryBuilderStub
    ) {
        let loader = AsyncSpy<Paginated<TestListItem>>()
        let queryBuilder = QueryBuilderStub()
        let clock = ImmediateClock()

        let sut = ListModel(
            clock: clock,
            loader: loader.load,
            queryBuilder: queryBuilder.build
        )

        await Test.trackForMemoryLeaks(sut)
        await Test.trackForMemoryLeaks(loader)
        await Test.trackForMemoryLeaks(queryBuilder)

        return (sut, loader, queryBuilder)
    }

    // swiftlint:disable:next large_tuple
    private func makeSUTSearch() async -> (
        sut: ListModel<[TestListItem], TestQuery>,
        loader: AsyncSpy<[TestListItem]>,
        queryBuilder: QueryBuilderStub,
        clock: TestClock<Duration>
    ) {
        let loader = AsyncSpy<[TestListItem]>()
        let queryBuilder = QueryBuilderStub()
        let clock = TestClock()

        let sut = ListModel(
            clock: clock,
            loader: loader.load,
            queryBuilder: queryBuilder.build
        )

        await Test.trackForMemoryLeaks(sut)
        await Test.trackForMemoryLeaks(loader)
        await Test.trackForMemoryLeaks(queryBuilder)

        return (sut, loader, queryBuilder, clock)
    }

    // Helper method for tests with selection callback
    private func makeSUT(
        onSelectionChange: ((TestListItem?) -> Void)? = nil
    ) async -> (
        sut: ListModel<[TestListItem], TestQuery>,
        loader: AsyncSpy<[TestListItem]>,
        queryBuilder: QueryBuilderStub
    ) {
        let loader = AsyncSpy<[TestListItem]>()
        let queryBuilder = QueryBuilderStub()
        let clock = ImmediateClock()

        let sut = ListModel(
            clock: clock,
            loader: loader.load,
            queryBuilder: queryBuilder.build,
            onSelectionChange: onSelectionChange
        )

        await Test.trackForMemoryLeaks(sut)
        await Test.trackForMemoryLeaks(loader)
        await Test.trackForMemoryLeaks(queryBuilder)

        return (sut, loader, queryBuilder)
    }

    // MARK: - Test Cases

    @Test(.teardownTracking())
    func init_setsEmptyStateAndNilErrorMessage() async throws {
        let (sut, _, _) = await makeSUT()

        #expect(sut.state == .empty(label: "No results", image: "magnifyingglass"))
        #expect(sut.errorMessage == nil)
    }

    @Test(.teardownTracking())
    func load_setsReadyStateOnSuccessfulResponse() async throws {
        let expectedItems = [TestListItem(id: "1", name: "Item 1")]
        let (sut, loader, queryBuilder) = await makeSUT()
        queryBuilder.queries = [TestQuery(term: "test")]

        try await loader
            .async(yieldCount: 2) {
                await sut.load()
            } completeWith: {
                .success(expectedItems)
            } expectationAfterCompletion: { _ in
                #expect(sut.state == .ready(expectedItems))
                #expect(sut.errorMessage == nil)
            }
    }

    @Test(.teardownTracking())
    func load_setsEmptyStateForEmptyResponse() async throws {
        let (sut, loader, queryBuilder) = await makeSUT()
        queryBuilder.queries = [TestQuery(term: "test")]

        try await loader
            .async(yieldCount: 2) {
                await sut.load()
            } completeWith: {
                .success([])
            } expectationAfterCompletion: { _ in
                #expect(sut.state == .empty(label: "No results", image: "magnifyingglass"))
                #expect(sut.errorMessage == nil)
            }
    }

    @Test(.teardownTracking())
    func load_setsErrorMessageOnErrorResponse() async throws {
        let expectedError = NSError(domain: "TestError", code: 0, userInfo: nil)
        let (sut, loader, queryBuilder) = await makeSUT()
        queryBuilder.queries = [TestQuery(term: "test")]

        try await loader
            .async(yieldCount: 2) {
                await sut.load()
            } completeWith: {
                .failure(expectedError)
            } expectationAfterCompletion: { _ in
                #expect(sut.errorMessage != nil)
            }
    }

    @Test(.teardownTracking())
    func load_usesCacheOnRepeatedCallWithSameQuery() async throws {
        let items1 = [TestListItem(id: "1", name: "Item 1")]
        let items2 = [TestListItem(id: "2", name: "Item 2")]
        let (sut, loader, queryBuilder) = await makeSUT()
        let query1 = TestQuery(term: "query1")
        let query2 = TestQuery(term: "query2")
        queryBuilder.queries = [query1, query1, query2]

        // First load
        try await loader.async(yieldCount: 2) {
            await sut.load()
        } completeWith: {
            .success(items1)
        } expectationAfterCompletion: { _ in
            #expect(sut.state == .ready(items1))
        }

        // Second load with same query (should use cache)
        try await loader.async(yieldCount: 2) {
            await sut.load()
        } expectationAfterCompletion: { _ in
            #expect(sut.state == .ready(items1))
            #expect(loader.performCallCount == 1)
        }

        // Third load with different query (should call loader again)
        try await loader.async(yieldCount: 2, at: 1) {
            await sut.load()
        } completeWith: {
            .success(items2)
        } expectationAfterCompletion: { _ in
            #expect(sut.state == .ready(items2))
            #expect(loader.performCallCount == 2)
        }
    }

    @Test(.teardownTracking())
    func cancelSearch_cancelsInProgressLoadOperation() async throws {
        let (sut, loader, queryBuilder) = await makeSUT()
        let expectedItems = [TestListItem(id: "1", name: "Search Result")]
        queryBuilder.queries = [TestQuery(term: "test")]

        try await loader
            .async(yieldCount: 2) {
                await sut.load()
            } processAdvance: {
                await sut.cancelSearch()
            } completeWith: {
                .success(expectedItems)
            } expectationAfterCompletion: { _ in
                #expect(sut.state == .empty(label: "No results", image: "magnifyingglass"))
                #expect(sut.errorMessage == nil)
            }
    }

    @Test(.teardownTracking())
    func onSearch_performsLoadWithDebounce() async throws {
        let (sut, loader, queryBuilder, clock) = await makeSUTSearch()
        let expectedItems = [TestListItem(id: "1", name: "Search Result")]
        queryBuilder.queries = [TestQuery(term: "te"), TestQuery(term: "tes"), TestQuery(term: "test")]

        // Query is sent 3 times but load is performed only once
        try await loader.async(
            yieldCount: 2,
            processes: [
                .init(process: {
                    await sut.onSearch("te")
                }, processAdvance: {
                    await clock.advance(by: .seconds(0.2))
                }),
                .init(process: {
                    await sut.onSearch("tes")
                }, processAdvance: {
                    await clock.advance(by: .seconds(0.2))
                }),
                .init(process: {
                    await sut.onSearch("test")
                }, processAdvance: {
                    await clock.advance(by: .seconds(0.6))
                })
            ],
            completeWith: {
                .success(expectedItems)
            },
            expectationAfterCompletion: { _ in
                #expect(sut.state == .ready(expectedItems))
                #expect(queryBuilder.buildCallCount == 3)
                #expect(loader.performCallCount == 1)
            }
        )
    }

    @Test(.teardownTracking())
    func element_returnsItemAtSpecifiedIndex() async throws {
        let items = [
            TestListItem(id: "1", name: "Item 1"),
            TestListItem(id: "2", name: "Item 2")
        ]
        let (sut, loader, queryBuilder) = await makeSUT()
        queryBuilder.queries = [TestQuery(term: "test")]

        try await loader.async(yieldCount: 2) {
            await sut.load()
        } completeWith: {
            .success(items)
        } expectationAfterCompletion: { _ in
            let element = sut.element(at: 1)
            #expect(element?.id == "2")
            #expect(element?.name == "Item 2")
        }
    }

    @Test(.teardownTracking())
    func loadMore_callsLoadMoreOnPaginatedModel() async throws {
        let initialItems = [TestListItem(id: "1", name: "Item 1")]
        let nextPageItems = [
            TestListItem(id: "1", name: "Item 1"),
            TestListItem(id: "2", name: "Item 2")
        ]

        let (sut, loader, queryBuilder) = await makeSUTPaginated()
        queryBuilder.queries = [TestQuery(term: "test")]

        // Use a paginated result
        try await loader.async(yieldCount: 2) {
            await sut.load()
        } completeWith: {
            .success(Paginated(items: initialItems) {
                Paginated(items: nextPageItems)
            })
        } expectationAfterCompletion: { _ in
            #expect(sut.loadMoreState == .ready)
        }

        // Test loading more
        try await sut.loadMore()
        #expect(sut.state == .ready(Paginated(items: nextPageItems)))
    }

    @Test(.teardownTracking())
    func selection_triggersSelectionCallback() async throws {
        let items = [
            TestListItem(id: "1", name: "Item 1"),
            TestListItem(id: "2", name: "Item 2")
        ]

        var selectedItem: TestListItem?
        let (sut, loader, queryBuilder) = await makeSUT(
            onSelectionChange: { selected in
                selectedItem = selected
            }
        )

        queryBuilder.queries = [TestQuery(term: "test")]

        try await loader.async(yieldCount: 2) {
            await sut.load()
        } completeWith: {
            .success(items)
        }

        sut.selection = "2"
        #expect(selectedItem == items[1])
    }
}

// MARK: - Test Helpers

private extension AsyncSpy {
    @Sendable
    func load(_ query: some Sendable) async throws -> Result {
        try await perform(query)
    }
}

private struct TestListItem: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
}

private struct TestQuery: Equatable, Sendable {
    let term: String
}

@MainActor
private class QueryBuilderStub {
    var queries: [TestQuery] = []
    var buildCallCount = 0

    func build(_ searchTerm: String) -> TestQuery {
        buildCallCount += 1
        guard !queries.isEmpty else {
            Issue.record("Query builder not properly stubbed")
            return TestQuery(term: "")
        }

        return queries.removeFirst()
    }
}

extension Paginated: Equatable where Item: Equatable {
    public static func == (lhs: Paginated<Item>, rhs: Paginated<Item>) -> Bool {
        lhs.items == rhs.items &&
            lhs.hasMore == rhs.hasMore
    }
}
