// MockService.swift
// Copyright (c) 2026 Moroverse
// Created by Daniel Moro on 2025-04-06 16:31 GMT.

actor MockService<T: Sendable> {
    let result: Result<T, Error>
    let delay: Duration?

    init(result: Result<T, Error>, delay: Duration? = nil) {
        self.result = result
        self.delay = delay
    }

    @Sendable
    func perform() async throws -> T {
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
