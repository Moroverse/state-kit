// CreationModel.swift
// Copyright (c) 2025 Moroverse
// Created by Daniel Moro on 2024-08-07 18:45 GMT.

import Foundation
import Observation

@MainActor
@Observable
public class CreationModel<CreationInfo> where CreationInfo: Sendable {
    public var serviceError: ServiceError?
    public var currentOperation: Task<Void, Error>?
    public var creationInfo: CreationInfo

    private let service: ((CreationInfo) async throws -> Void)?

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

        currentOperation = task

        do {
            try await task.value
        } catch is CancellationError {
        } catch {
            serviceError = ServiceError(error: error)
        }
    }

    public func cancel() {
        if let task = currentOperation {
            task.cancel()
            currentOperation = nil
        }
    }
}
