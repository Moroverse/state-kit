// AsyncSubject.swift
// Copyright (c) 2026 Moroverse
// Created by Daniel Moro on 2025-11-06 06:35 GMT.

import Foundation

/// An actor that broadcasts values to multiple `AsyncStream` subscribers.
///
/// Each call to ``stream()`` creates a new subscriber. When ``send(_:)`` is called,
/// all active subscribers receive the value. Streams are automatically cleaned up on termination.
public actor AsyncSubject<Value: Sendable> {
    private var continuations: [UUID: AsyncStream<Value>.Continuation] = [:]

    public init() {}

    /// Creates a new `AsyncStream` that receives values sent via ``send(_:)``.
    ///
    /// - Returns: An async stream that yields values until termination.
    public func stream() -> AsyncStream<Value> {
        let id = UUID()
        return AsyncStream { continuation in
            continuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeContinuation(id) }
            }
        }
    }

    /// Sends a value to all active subscribers.
    ///
    /// - Parameter value: The value to broadcast to all streams.
    public func send(_ value: Value) {
        for continuation in continuations.values {
            continuation.yield(value)
        }
    }

    private func removeContinuation(_ id: UUID) {
        continuations[id] = nil
    }
}

/// A `@MainActor`-isolated subject that broadcasts values to multiple `AsyncStream` subscribers.
///
/// The MainActor variant of ``AsyncSubject`` for use in UI contexts where
/// synchronous access from the main thread is needed.
@MainActor
public final class MainActorSubject<Value: Sendable> {
    private var continuations: [UUID: AsyncStream<Value>.Continuation] = [:]

    public init() {}

    /// Creates a new `AsyncStream` that receives values sent via ``send(_:)``.
    ///
    /// - Returns: An async stream that yields values until termination.
    public func stream() -> AsyncStream<Value> {
        let id = UUID()
        return AsyncStream { @MainActor continuation in
            continuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in self?.removeContinuation(id) }
            }
        }
    }

    /// Sends a value to all active subscribers.
    ///
    /// - Parameter value: The value to broadcast to all streams.
    public func send(_ value: Value) {
        for continuation in continuations.values {
            continuation.yield(value)
        }
    }

    private func removeContinuation(_ id: UUID) {
        continuations[id] = nil
    }
}
