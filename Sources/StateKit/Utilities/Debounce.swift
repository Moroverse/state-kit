// Debounce.swift
// Copyright (c) 2026 Moroverse
// Created by Daniel Moro on 2025-04-06 16:31 GMT.

import Foundation

/// An actor that debounces an async operation using variadic generics.
///
/// When called multiple times in rapid succession, `Debounce` cancels the previous pending
/// operation and restarts the delay. Only the final call within the delay window executes.
///
/// `Debounce` uses `callAsFunction` so it can be invoked like a function:
///
/// ```swift
/// let debounce = Debounce<String, [Item]>(
///     call: { query in try await api.search(query) },
///     after: .seconds(0.5)
/// )
///
/// let results = try await debounce("search term")
/// ```
///
/// - Note: The clock parameter enables deterministic testing with `TestClock`.
public actor Debounce<each Parameter: Sendable, Result: Sendable> {
    private let delay: Duration
    private let operation: @Sendable (repeat each Parameter) async throws -> Result
    private var currentTask: Task<Result, Error>?
    private let waiter: Waiter

    /// Creates a new debounce actor.
    ///
    /// - Parameters:
    ///   - operation: The async operation to debounce.
    ///   - delay: The duration to wait before executing the operation.
    ///   - clock: The clock to use for timing. Defaults to `ContinuousClock()`.
    public init(
        call operation: @Sendable @escaping (repeat each Parameter) async throws -> Result,
        after delay: Duration,
        clock: any Clock<Duration> = ContinuousClock()
    ) {
        self.delay = delay
        self.operation = operation
        waiter = Waiter(duration: delay, clock: clock)
    }

    /// Debounces and executes the operation with the given parameters.
    ///
    /// Cancels any pending execution and waits for the configured delay before running.
    /// If called again during the delay, the previous call is cancelled via `CancellationError`.
    ///
    /// - Parameter parameter: The parameters to pass to the debounced operation.
    /// - Returns: The result of the operation.
    /// - Throws: `CancellationError` if superseded by a newer call, or the operation's error.
    public func callAsFunction(
        _ parameter: repeat each Parameter,
        isolation: isolated (any Actor)? = #isolation
    ) async throws -> Result {
        await currentTask?.cancel()

        let task = Task {
            try await waiter.wait()
            try Task.checkCancellation()
            return try await operation(repeat each parameter)
        }

        await assign(task: task)
        return try await task.value
    }

    /// Cancels any pending debounced operation.
    public func cancel() {
        currentTask?.cancel()
        currentTask = nil
    }

    private func assign(task: Task<Result, Error>) {
        currentTask = task
    }
}

private actor Waiter {
    private let elapsedTime: (any InstantProtocol<Duration>) -> (
        elapsed: Duration,
        lastCallTime: (any InstantProtocol<Duration>)?
    )
    private let clock: any Clock<Duration>
    private let duration: Duration
    private var lastCallTime: (any InstantProtocol<Duration>)?

    init<C: Clock<Duration>>(duration: Duration, clock: C) {
        self.clock = clock
        self.duration = duration
        elapsedTime = { lastCallTime in
            let now = clock.now
            let timeToWait: Duration
            if let lastCall = lastCallTime as? C.Instant, now > lastCall {
                let elapsedTime = lastCall.duration(to: now)
                timeToWait = elapsedTime >= duration ? .zero : duration - elapsedTime
            } else {
                timeToWait = .zero
            }

            return (timeToWait, now)
        }
    }

    func wait() async throws {
        let timeToWait: Duration
        if let lastCallTime {
            let result = elapsedTime(lastCallTime)
            timeToWait = result.elapsed
            self.lastCallTime = result.lastCallTime
        } else {
            timeToWait = duration
            lastCallTime = clock.now
        }

        if timeToWait > .zero {
            try await clock.sleep(for: timeToWait)
        }
    }
}
