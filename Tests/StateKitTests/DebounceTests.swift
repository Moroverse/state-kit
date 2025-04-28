// DebounceTests.swift
// Copyright (c) 2025 Moroverse
// Created by Daniel Moro on 2025-04-06 16:31 GMT.

import Clocks
import Testing
@testable import StateKit

struct DebounceTests {
    @Test func testDebounce() async throws {
        let clock = TestClock()
        let spy = DebouncerSpy(clock: clock)

        Task { await spy.insert(item: 1) }

        await clock.advance(by: .seconds(0.1)) // 0.1

        #expect(await spy.results == [])

        Task { await spy.insert(item: 2) }

        await clock.advance(by: .seconds(0.3)) // 0.4

        #expect(await spy.results == [])

        await clock.advance(by: .seconds(0.1)) // 0.5

        #expect(await spy.results == [2])

        Task { await spy.insert(item: 3) }

        await clock.advance(by: .seconds(0.5)) // 1.0
        #expect(await spy.results == [2, 3])
    }
}

actor DebouncerSpy {
    var results: [Int] = []
    private let clock: any Clock<Duration>
    private lazy var debounce: Debounce<Int, Void> = .init(call: append, after: .seconds(0.5), clock: clock)

    init(clock: any Clock<Duration>) {
        self.clock = clock
    }

    private func append(item: Int) {
        results.append(item)
    }

    func insert(item: Int) async {
        try? await debounce(item)
    }
}
