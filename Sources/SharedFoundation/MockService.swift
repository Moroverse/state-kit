// MockService.swift
// Copyright (c) 2025 Moroverse
// Created by Daniel Moro on 2025-03-26 19:18 GMT.

public actor MockService<T> where T: Sendable {
    let result: Result<T, Error>
    let delay: Duration?

    public init(result: Result<T, Error>, delay: Duration? = nil) {
        self.result = result
        self.delay = delay
    }

    @Sendable
    public func perform() async throws -> T {
        if let delay {
            try await Task.sleep(for: delay)
        }

        switch result {
        case let .success(success):
            return success
        case let .failure(failure):
            throw failure
        }
    }
}
