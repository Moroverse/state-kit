// AsyncSubject.swift
// Copyright (c) 2026 Moroverse
// Created by Daniel Moro on 2025-11-06 06:35 GMT.

import Foundation

public actor AsyncSubject<Value: Sendable> {
    private var continuations: [UUID: AsyncStream<Value>.Continuation] = [:]

    public init() {}

    public func stream() -> AsyncStream<Value> {
        let id = UUID()
        return AsyncStream { continuation in
            continuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeContinuation(id) }
            }
        }
    }

    public func send(_ value: Value) {
        for continuation in continuations.values {
            continuation.yield(value)
        }
    }

    private func removeContinuation(_ id: UUID) {
        continuations[id] = nil
    }
}

@MainActor
public final class MainActorSubject<Value: Sendable> {
    private var continuations: [UUID: AsyncStream<Value>.Continuation] = [:]

    public init() {}

    public func stream() -> AsyncStream<Value> {
        let id = UUID()
        return AsyncStream { @MainActor continuation in
            continuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in self?.removeContinuation(id) }
            }
        }
    }

    public func send(_ value: Value) {
        for continuation in continuations.values {
            continuation.yield(value)
        }
    }

    private func removeContinuation(_ id: UUID) {
        continuations[id] = nil
    }
}
