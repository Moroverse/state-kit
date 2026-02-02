// DetailStoreTests.swift
// Copyright (c) 2026 Moroverse
// Created by Daniel Moro on 2025-04-06 16:31 GMT.

import Foundation
import Testing
import TestKit
@testable import StateKit

@MainActor
@Suite
struct DetailStoreTests {
    // MARK: - SUT Creation

    private func makeSUT() async -> (
        sut: DetailStore<TestModel, TestQuery, any Error>,
        loader: AsyncSpy<TestModel>,
        queryProvider: QueryProviderStub
    ) {
        let loader = AsyncSpy<TestModel>()

        let queryProvider = QueryProviderStub()

        let sut: DetailStore<TestModel, TestQuery, any Error> = DetailStore(loader: loader.load, queryProvider: queryProvider.provide)
        await Test.trackForMemoryLeaks(sut)
        await Test.trackForMemoryLeaks(loader)
        await Test.trackForMemoryLeaks(queryProvider)

        return (sut, loader, queryProvider)
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
        let expectedModel = TestModel(id: "1", name: "Test")
        let (sut, loader, queryProvider) = await makeSUT()
        queryProvider.queries = [TestQuery(id: "1")]

        try await loader
            .async {
                await sut.load()
            } completeWith: {
                .success(expectedModel)
            } expectationAfterCompletion: { _ in
                guard case let .loaded(model) = sut.state else {
                    Issue.record("Expected .loaded state, got \(sut.state)")
                    return
                }
                #expect(model == expectedModel)
            }
    }

    @Test(.teardownTracking())
    func load_setsErrorStateOnErrorResponse() async throws {
        let expectedError = NSError(domain: "TestError", code: 0, userInfo: nil)
        let (sut, loader, queryProvider) = await makeSUT()
        queryProvider.queries = [TestQuery(id: "1")]

        try await loader.async {
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

    @Test(.teardownTracking())
    func load_usesCacheOnRepeatedCallWithSameQuery() async throws {
        let model1 = TestModel(id: "1", name: "Test 1")
        let model2 = TestModel(id: "2", name: "Test 2")
        let (sut, loader, queryProvider) = await makeSUT()
        queryProvider.queries = [TestQuery(id: "1"), TestQuery(id: "1"), TestQuery(id: "2")]

        // First load
        try await loader.async {
            await sut.load()
        } completeWith: {
            .success(model1)
        } expectationAfterCompletion: { _ in
            guard case let .loaded(model) = sut.state else {
                Issue.record("Expected .loaded state, got \(sut.state)")
                return
            }
            #expect(model == model1)
        }

        // Second load with same query (should use cache)
        try await loader.async {
            await sut.load()
        } expectationAfterCompletion: { _ in
            guard case let .loaded(model) = sut.state else {
                Issue.record("Expected .loaded state, got \(sut.state)")
                return
            }
            #expect(model == model1)
            #expect(loader.performCallCount == 1)
        }

        try await loader.async(at: 1) {
            await sut.load()
        }
        completeWith: {
            .success(model2)
        }
        expectationAfterCompletion: {
            guard case let .loaded(model) = sut.state else {
                Issue.record("Expected .loaded state, got \(sut.state)")
                return
            }
            #expect(model == model2)
            #expect(loader.performCallCount == 2)
        }
    }

    @Test(.teardownTracking())
    func cancel_maintainsIdleStateOnCancelledLoad() async throws {
        let anyModel = TestModel(id: "1", name: "Test")
        let (sut, loader, queryProvider) = await makeSUT()
        queryProvider.queries = [TestQuery(id: "1")]

        try await loader.async(yieldCount: 2) {
            await sut.load()
        } completeWith: {
            sut.cancel()
            return .success(anyModel)
        } expectationAfterCompletion: { _ in
            guard case .idle = sut.state else {
                Issue.record("Expected .idle state, got \(sut.state)")
                return
            }
        }
    }
}

// MARK: - Test Helpers

private struct TestModel: Equatable, Sendable {
    let id: String
    let name: String
}

private struct TestQuery: Equatable, Sendable {
    let id: String
}

@MainActor
private final class QueryProviderStub {
    var queries: [TestQuery] = []
    var provideCallCount = 0

    func provide() -> TestQuery {
        provideCallCount += 1
        guard !queries.isEmpty else {
            Issue.record("Query provider not properly stubbed")
            return TestQuery(id: "")
        }

        return queries.removeFirst()
    }
}
