// ListStoreTests.swift
// Copyright (c) 2026 Moroverse
// Created by Daniel Moro on 2025-04-07 08:57 GMT.

import Clocks
import ConcurrencyExtras
import Foundation
import Testing
import TestKit
@testable import StateKit

@MainActor
@Suite
struct ListStoreTests {
    // MARK: - SUT Creation

    private func makeSUTPaginated() async -> (
        sut: PaginatedListStore<SearchableListStore<Paginated<TestListItem>, TestQuery, any Error>, TestListItem>,
        loader: AsyncSpy<Paginated<TestListItem>>,
        queryBuilder: QueryBuilderStub
    ) {
        let loader = AsyncSpy<Paginated<TestListItem>>()
        let queryBuilder = QueryBuilderStub()
        let clock = ImmediateClock()

        let listStore: ListStore<Paginated<TestListItem>, TestQuery, any Error> = ListStore(
            emptyStateConfiguration: EmptyStateConfiguration(
                label: "No results",
                image: .system("magnifyingglass")
            ),
            loader: loader.load,
            queryProvider: { queryBuilder.build("") }
        )

        let sut = listStore
            .searchable(
                queryBuilder: queryBuilder.build,
                loadingConfiguration: LoadingConfiguration(
                    debounceDelay: .seconds(0.5),
                    clock: clock
                )
            )
            .paginated()

        await Test.trackForMemoryLeaks(sut)
        await Test.trackForMemoryLeaks(loader)
        await Test.trackForMemoryLeaks(queryBuilder)

        return (sut, loader, queryBuilder)
    }

    // swiftlint:disable:next large_tuple
    private func makeSUTSearch() async -> (
        sut: SearchableListStore<[TestListItem], TestQuery, any Error>,
        loader: AsyncSpy<[TestListItem]>,
        queryBuilder: QueryBuilderStub,
        clock: TestClock<Duration>
    ) {
        let loader = AsyncSpy<[TestListItem]>()
        let queryBuilder = QueryBuilderStub()
        let clock = TestClock()

        let listStore: ListStore<[TestListItem], TestQuery, any Error> = ListStore(
            emptyStateConfiguration: EmptyStateConfiguration(
                label: "No results",
                image: .system("magnifyingglass")
            ),
            loader: loader.load,
            queryProvider: { queryBuilder.build("") }
        )

        let sut = listStore.searchable(
            queryBuilder: queryBuilder.build,
            loadingConfiguration: LoadingConfiguration(
                debounceDelay: .seconds(0.5),
                clock: clock
            )
        )

        await Test.trackForMemoryLeaks(sut)
        await Test.trackForMemoryLeaks(loader)
        await Test.trackForMemoryLeaks(queryBuilder)

        return (sut, loader, queryBuilder, clock)
    }

    // swiftlint:disable:next large_tuple
    private func makeSUT() async -> (
        sut: SelectableListStore<SearchableListStore<[TestListItem], TestQuery, any Error>>,
        loader: AsyncSpy<[TestListItem]>,
        queryBuilder: QueryBuilderStub
    ) {
        let loader = AsyncSpy<[TestListItem]>()
        let queryBuilder = QueryBuilderStub()
        let clock = ImmediateClock()

        let listStore: ListStore<[TestListItem], TestQuery, any Error> = ListStore(
            emptyStateConfiguration: EmptyStateConfiguration(
                label: "No results",
                image: .system("magnifyingglass")
            ),
            loader: loader.load,
            queryProvider: { queryBuilder.build("") }
        )

        let sut = listStore
            .searchable(
                queryBuilder: queryBuilder.build,
                loadingConfiguration: LoadingConfiguration(
                    debounceDelay: .seconds(0.5),
                    clock: clock
                )
            )
            .selectable()

        await Test.trackForMemoryLeaks(sut)
        await Test.trackForMemoryLeaks(loader)
        await Test.trackForMemoryLeaks(queryBuilder)

        return (sut, loader, queryBuilder)
    }

    // MARK: - Test Cases

    @Test(.teardownTracking())
    func init_setsIdleState() async {
        let (sut, _, _) = await makeSUT()

        guard case .idle = sut.state else {
            Issue.record("Expected .idle state, got \(sut.state)")
            return
        }
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
                guard case let .loaded(items, loadMoreState) = sut.state else {
                    Issue.record("Expected .loaded state")
                    return
                }
                #expect(items == expectedItems)
                #expect(loadMoreState == .unavailable)
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
                guard case .empty = sut.state else {
                    Issue.record("Expected .empty state, got \(sut.state)")
                    return
                }
            }
    }

    @Test(.teardownTracking())
    func load_setsErrorStateOnErrorResponse() async throws {
        let expectedError = NSError(domain: "TestError", code: 0, userInfo: nil)
        let (sut, loader, queryBuilder) = await makeSUT()
        queryBuilder.queries = [TestQuery(term: "test")]

        try await loader
            .async(yieldCount: 2) {
                await sut.load()
            } completeWith: {
                .failure(expectedError)
            } expectationAfterCompletion: { _ in
                guard case .error = sut.state else {
                    Issue.record("Expected .error state")
                    return
                }
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
            guard case let .loaded(items, _) = sut.state else {
                Issue.record("Expected .loaded state")
                return
            }
            #expect(items == items1)
        }

        // Second load with same query (should use cache)
        try await loader.async(yieldCount: 2) {
            await sut.load()
        } expectationAfterCompletion: { _ in
            guard case let .loaded(items, _) = sut.state else {
                Issue.record("Expected .loaded state")
                return
            }
            #expect(items == items1)
            #expect(loader.performCallCount == 1)
        }

        // Third load with different query (should call loader again)
        try await loader.async(yieldCount: 2, at: 1) {
            await sut.load()
        } completeWith: {
            .success(items2)
        } expectationAfterCompletion: { _ in
            guard case let .loaded(items, _) = sut.state else {
                Issue.record("Expected .loaded state")
                return
            }
            #expect(items == items2)
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
                sut.cancelSearch()
            } completeWith: {
                .success(expectedItems)
            } expectationAfterCompletion: { _ in
                guard case .idle = sut.state else {
                    Issue.record("Expected .idle state after cancel, got \(sut.state)")
                    return
                }
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
                    await sut.search("te")
                }, processAdvance: {
                    await clock.advance(by: .seconds(0.2))
                }),
                .init(process: {
                    await sut.search("tes")
                }, processAdvance: {
                    await clock.advance(by: .seconds(0.2))
                }),
                .init(process: {
                    await sut.search("test")
                }, processAdvance: {
                    await clock.advance(by: .seconds(0.6))
                })
            ],
            completeWith: {
                .success(expectedItems)
            },
            expectationAfterCompletion: { _ in
                guard case let .loaded(items, _) = sut.state else {
                    Issue.record("Expected .loaded state")
                    return
                }
                #expect(items == expectedItems)
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
            guard case let .loaded(model, loadMoreState) = sut.state else {
                Issue.record("Expected .loaded state")
                return
            }
            #expect(model == Paginated(items: initialItems) { Paginated(items: nextPageItems) })
            #expect(loadMoreState == .ready)
        }

        // Test loading more
        try await sut.loadMore()
        guard case let .loaded(model, loadMoreState) = sut.state else {
            Issue.record("Expected .loaded state after loadMore")
            return
        }
        #expect(model == Paginated(items: nextPageItems))
        #expect(loadMoreState == .unavailable)
    }

    @Test(.teardownTracking())
    func selection_setsSelectionProperty() async {
        let (sut, _, _) = await makeSUT()

        #expect(sut.selection == nil)

        sut.select("test-id")
        #expect(sut.selection == "test-id")

        sut.select("different-id")
        #expect(sut.selection == "different-id")
    }

    @Test(.teardownTracking())
    func selection_handlesEmptyCollection() async throws {
        let (sut, loader, queryBuilder) = await makeSUT()

        queryBuilder.queries = [TestQuery(term: "test")]

        // Load empty collection
        try await loader.async(yieldCount: 2) {
            await sut.load()
        } completeWith: {
            .success([]) // Empty array
        }

        // Select from empty collection — selection property should still be set
        sut.select("1")
        #expect(sut.selection == "1")
    }

    @Test(.teardownTracking())
    func selection_handlesMultipleSelectionChanges() async throws {
        let items = [
            TestListItem(id: "1", name: "Item 1"),
            TestListItem(id: "2", name: "Item 2"),
            TestListItem(id: "3", name: "Item 3")
        ]

        let (sut, loader, queryBuilder) = await makeSUT()

        queryBuilder.queries = [TestQuery(term: "test")]

        try await loader.async(yieldCount: 2) {
            await sut.load()
        } completeWith: {
            .success(items)
        }

        // Multiple rapid selection changes
        sut.select("1")
        #expect(sut.selection == "1")

        sut.select("2")
        #expect(sut.selection == "2")

        sut.select("3")
        #expect(sut.selection == "3")

        sut.select("1")
        #expect(sut.selection == "1")
    }

    @Test(.teardownTracking())
    func selection_maintainsSelectionAcrossStateChanges() async throws {
        let initialItems = [
            TestListItem(id: "1", name: "Item 1"),
            TestListItem(id: "2", name: "Item 2")
        ]

        let updatedItems = [
            TestListItem(id: "1", name: "Updated Item 1"),
            TestListItem(id: "3", name: "Item 3")
        ]

        let (sut, loader, queryBuilder) = await makeSUT()

        queryBuilder.queries = [TestQuery(term: "test"), TestQuery(term: "updated")]

        // Load initial data and select item
        try await loader.async(yieldCount: 2) {
            await sut.load()
        } completeWith: {
            .success(initialItems)
        }

        sut.select("1")
        #expect(sut.selection == "1")

        // Load new data — selection should be maintained
        try await loader.async(yieldCount: 2, at: 1) {
            await sut.load()
        } completeWith: {
            .success(updatedItems)
        }

        #expect(sut.selection == "1")
    }

    @Test(.teardownTracking())
    func selection_worksWithPaginatedResults() async throws {
        let initialItems = [TestListItem(id: "1", name: "Item 1")]
        let paginatedItems = [
            TestListItem(id: "1", name: "Item 1"),
            TestListItem(id: "2", name: "Item 2")
        ]

        let loader = AsyncSpy<Paginated<TestListItem>>()
        let queryBuilder = QueryBuilderStub()
        let clock = ImmediateClock()

        let listStore: ListStore<Paginated<TestListItem>, TestQuery, any Error> = ListStore(
            emptyStateConfiguration: EmptyStateConfiguration(
                label: "No results",
                image: .system("magnifyingglass")
            ),
            loader: loader.load,
            queryProvider: { queryBuilder.build("") }
        )

        let sut = listStore
            .searchable(
                queryBuilder: queryBuilder.build,
                loadingConfiguration: LoadingConfiguration(
                    debounceDelay: .seconds(0.5),
                    clock: clock
                )
            )
            .paginated()
            .selectable()

        queryBuilder.queries = [TestQuery(term: "test")]

        // Load initial paginated data
        try await loader.async(yieldCount: 2) {
            await sut.load()
        } completeWith: {
            .success(Paginated(items: initialItems) {
                Paginated(items: paginatedItems)
            })
        }

        // Select item from initial paginated results
        sut.select("1")
        #expect(sut.selection == "1")

        // Load more data
        try await sut.loadMore()

        // Select item that exists in paginated results
        sut.select("2")
        #expect(sut.selection == "2")
    }
}

// MARK: - Test Helpers

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
