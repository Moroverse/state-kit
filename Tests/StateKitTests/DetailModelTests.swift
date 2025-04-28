// DetailModelTests.swift
// Copyright (c) 2025 Moroverse
// Created by Daniel Moro on 2025-04-06 16:31 GMT.

import Foundation
import SharedTesting
import Testing
@testable import StateKit

@MainActor
@Suite
struct DetailModelTests {
    // MARK: - SUT Creation

    private func makeSUT() async -> (
        sut: DetailModel<TestModel, TestQuery>,
        loader: AsyncSpy<TestModel>,
        queryProvider: QueryProviderStub
    ) {
        let loader = AsyncSpy<TestModel>()

        let queryProvider = QueryProviderStub()

        let sut = DetailModel(loader: loader.load, queryProvider: queryProvider.provide)
        await Test.trackForMemoryLeaks(sut)
        await Test.trackForMemoryLeaks(loader)
        await Test.trackForMemoryLeaks(queryProvider)

        return (sut, loader, queryProvider)
    }

    // MARK: - Test Cases

    @Test(.teardownTracking())
    func init_setsEmptyStateAndNilError() async throws {
        let (sut, _, _) = await makeSUT()
        #expect(sut.state == .empty)
        #expect(sut.error == nil)
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
                #expect(sut.state == .ready(expectedModel))
                #expect(sut.error == nil)
            }
    }

    @Test(.teardownTracking())
    func load_setsEmptyStateAndErrorOnErrorResponse() async throws {
        let expectedError = NSError(domain: "TestError", code: 0, userInfo: nil)
        let (sut, loader, queryProvider) = await makeSUT()
        queryProvider.queries = [TestQuery(id: "1")]

        try await loader.async {
            await sut.load()
        } completeWith: {
            .failure(expectedError)
        } expectationAfterCompletion: { _ in
            #expect(sut.state == .empty)
            #expect(sut.error as NSError? == expectedError)
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
            #expect(sut.state == .ready(model1))
        }

        // Second load with same query (should use cache)
        try await loader.async {
            await sut.load()
        } expectationAfterCompletion: { _ in
            #expect(sut.state == .ready(model1))
            #expect(loader.performCallCount == 1)
        }

        try await loader.async(at: 1) {
            await sut.load()
        }
        completeWith: {
            .success(model2)
        }
        expectationAfterCompletion: {
            #expect(sut.state == .ready(model2))
            #expect(loader.performCallCount == 2)
        }
    }

    @Test(.teardownTracking())
    func cancel_maintainsEmptyStateOnCancelledLoad() async throws {
        let anyModel = TestModel(id: "1", name: "Test")
        let (sut, loader, queryProvider) = await makeSUT()
        queryProvider.queries = [TestQuery(id: "1")]

        try await loader.async(yieldCount: 2) {
            await sut.load()
        } completeWith: {
            sut.cancel()
            return .success(anyModel)
        } expectationAfterCompletion: { _ in
            #expect(sut.state == .empty)
        }
    }
}

// MARK: - Test Helpers

private extension AsyncSpy {
    @Sendable
    func load(_ query: some Sendable) async throws -> Result {
        try await perform(query)
    }
}

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
