// CreationStore.swift
// Copyright (c) 2025 Moroverse
// Created by Daniel Moro on 2024-08-07 18:45 GMT.

import Foundation
import Observation

@MainActor
@Observable
public class CreationStore<CreationInfo> where CreationInfo: Sendable {
    public var serviceError: ServiceError?
    public var currentOperation: Cancellable?
    public var creationInfo: CreationInfo

    private let service: ((CreationInfo) async throws -> Void)?
    @ObservationIgnored
    private var currentTask: Task<Void, Error>?

    public init(
        creationInfo: CreationInfo,
        service: ((CreationInfo) async throws -> Void)? = nil
    ) {
        self.creationInfo = creationInfo
        self.service = service
    }

    public func create() async {
        guard let creator = service else { return }
        serviceError = nil

        let task = Task {
            try Task.checkCancellation()
            try await creator(creationInfo)
            try Task.checkCancellation()
        }

        currentTask = task
        currentOperation = Cancellable { task.cancel() }

        do {
            try await task.value
            currentTask = nil
        } catch is CancellationError {
            currentTask = nil
        } catch {
            currentTask = nil
            serviceError = ServiceError(error: error)
        }
    }

    public func cancel() {
        currentOperation?.cancel()
        currentOperation = nil
        currentTask = nil
    }
}
