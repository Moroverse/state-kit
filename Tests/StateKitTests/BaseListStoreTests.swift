// BaseListStoreTests.swift
// Copyright (c) 2026 Moroverse
// Created by Daniel Moro on 2026-02-01 05:29 GMT.

import Foundation
import Testing
import TestKit
@testable import StateKit

@MainActor
@Suite
struct BaseListStoreTests {
    // MARK: - SUT Creation

    private func makeSUT() async -> (
        sut: ListStore<[TestItem], TestQuery, any Error>,
        loader: AsyncSpy<[TestItem]>,
        queryProvider: QueryProviderStub
    ) {
        let loader = AsyncSpy<[TestItem]>()
        let queryProvider = QueryProviderStub()

        let sut: ListStore<[TestItem], TestQuery, any Error> = ListStore(
            loader: loader.load,
            queryProvider: queryProvider.make
        )

        await Test.trackForMemoryLeaks(sut)
        await Test.trackForMemoryLeaks(loader)
        await Test.trackForMemoryLeaks(queryProvider)

        return (sut, loader, queryProvider)
    }

    // MARK: - Init

    @Test(.teardownTracking())
    func init_setsIdleState() async {
        let (sut, _, _) = await makeSUT()
        guard case .idle = sut.state else {
            Issue.record("Expected .idle state, got \(sut.state)")
            return
        }
    }

    // MARK: - Load

    @Test(.teardownTracking())
    func load_setsLoadedStateOnSuccessfulResponse() async throws {
        let expectedItems = [
            TestItem(id: "1", name: "Item 1"),
            TestItem(id: "2", name: "Item 2")
        ]
        let (sut, loader, queryProvider) = await makeSUT()
        queryProvider.queries = [TestQuery(term: "test")]

        try await loader.async(yieldCount: 2) {
            await sut.load()
        } completeWith: {
            .success(expectedItems)
        } expectationAfterCompletion: { _ in
            guard case let .loaded(items, loadMoreState) = sut.state else {
                Issue.record("Expected .loaded state, got \(sut.state)")
                return
            }
            #expect(items == expectedItems)
            #expect(loadMoreState == .unavailable)
        }
    }

    @Test(.teardownTracking())
    func load_setsEmptyStateForEmptyResponse() async throws {
        let (sut, loader, queryProvider) = await makeSUT()
        queryProvider.queries = [TestQuery(term: "test")]

        try await loader.async(yieldCount: 2) {
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
        let expectedError = NSError(domain: "TestError", code: 42, userInfo: nil)
        let (sut, loader, queryProvider) = await makeSUT()
        queryProvider.queries = [TestQuery(term: "test")]

        try await loader.async(yieldCount: 2) {
            await sut.load()
        } completeWith: {
            .failure(expectedError)
        } expectationAfterCompletion: { _ in
            guard case let .error(failure, previousState: previousState) = sut.state else {
                Issue.record("Expected .error state, got \(sut.state)")
                return
            }
            #expect((failure as NSError) == expectedError)
            guard case .idle = previousState else {
                Issue.record("Expected .idle previousState, got \(previousState)")
                return
            }
        }
    }

    // MARK: - Cache

    @Test(.teardownTracking())
    func load_usesCacheOnRepeatedCallWithSameQuery() async throws {
        let expectedItems = [TestItem(id: "1", name: "Item 1")]
        let (sut, loader, queryProvider) = await makeSUT()
        queryProvider.queries = [TestQuery(term: "test"), TestQuery(term: "test")]

        // First load
        try await loader.async(yieldCount: 2) {
            await sut.load()
        } completeWith: {
            .success(expectedItems)
        } expectationAfterCompletion: { _ in
            guard case let .loaded(items, _) = sut.state else {
                Issue.record("Expected .loaded state, got \(sut.state)")
                return
            }
            #expect(items == expectedItems)
        }

        // Second load with same query — should use cache
        try await loader.async {
            await sut.load()
        } expectationAfterCompletion: { _ in
            guard case let .loaded(items, _) = sut.state else {
                Issue.record("Expected .loaded state, got \(sut.state)")
                return
            }
            #expect(items == expectedItems)
            #expect(loader.performCallCount == 1)
        }
    }

    // MARK: - Cancel

    @Test(.teardownTracking())
    func cancel_maintainsIdleStateOnCancelledLoad() async throws {
        let anyItems = [TestItem(id: "1", name: "Item 1")]
        let (sut, loader, queryProvider) = await makeSUT()
        queryProvider.queries = [TestQuery(term: "test")]

        try await loader.async(yieldCount: 2) {
            await sut.load()
        } completeWith: {
            sut.cancel()
            return .success(anyItems)
        } expectationAfterCompletion: { _ in
            guard case .idle = sut.state else {
                Issue.record("Expected .idle state, got \(sut.state)")
                return
            }
        }
    }

    // MARK: - Element Access

    @Test(.teardownTracking())
    func element_returnsItemAtSpecifiedIndex() async throws {
        let expectedItems = [
            TestItem(id: "1", name: "Item 1"),
            TestItem(id: "2", name: "Item 2"),
            TestItem(id: "3", name: "Item 3")
        ]
        let (sut, loader, queryProvider) = await makeSUT()
        queryProvider.queries = [TestQuery(term: "test")]

        try await loader.async(yieldCount: 2) {
            await sut.load()
        } completeWith: {
            .success(expectedItems)
        } expectationAfterCompletion: { _ in
            #expect(sut.element(at: 0) == expectedItems[0])
            #expect(sut.element(at: 1) == expectedItems[1])
            #expect(sut.element(at: 2) == expectedItems[2])
            #expect(sut.element(at: 3) == nil)
        }
    }

    // MARK: - Protocol Conformance

    @Test(.teardownTracking())
    func listStore_conformsToListStateProviding() async {
        let (sut, _, _) = await makeSUT()
        let _: any ListStateProviding = sut
    }

    // MARK: - Load with loadMoreState always .unavailable

    @Test(.teardownTracking())
    func load_alwaysSetsLoadMoreStateToUnavailable() async throws {
        let items = [TestItem(id: "1", name: "Item 1")]
        let (sut, loader, queryProvider) = await makeSUT()
        queryProvider.queries = [TestQuery(term: "test")]

        try await loader.async(yieldCount: 2) {
            await sut.load()
        } completeWith: {
            .success(items)
        } expectationAfterCompletion: { _ in
            guard case let .loaded(_, loadMoreState) = sut.state else {
                Issue.record("Expected .loaded state, got \(sut.state)")
                return
            }
            #expect(loadMoreState == .unavailable)
        }
    }
}

// MARK: - Test Helpers

private struct TestQuery: Equatable, Sendable {
    let term: String
}

@MainActor
private final class QueryProviderStub {
    var queries: [TestQuery] = []
    var makeCallCount = 0

    func make() -> TestQuery {
        makeCallCount += 1
        guard !queries.isEmpty else {
            Issue.record("Query provider not properly stubbed")
            return TestQuery(term: "")
        }

        return queries.removeFirst()
    }
}
