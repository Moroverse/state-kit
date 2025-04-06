// QueryProviderStub.swift
// Copyright (c) 2025 Moroverse
// Created by Daniel Moro on 2024-08-04 05:06 GMT.

import Testing

@MainActor
final class QueryProviderStub {
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
