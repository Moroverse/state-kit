// EditStore.swift
// Copyright (c) 2025 Moroverse
// Created by Daniel Moro on 2024-08-07 18:45 GMT.

import Foundation
import Observation

/// A generic service structure for repository operations.
///
/// This structure provides a flexible way to define create, update, and fetch operations
/// for a repository that deals with a specific model type and query type.
///
/// - Parameters:
///   - Query: The type used for querying the repository.
///   - Model: The type of model managed by the repository.
public struct RepositoryService<Query, Model> {
    /// A closure that updates an existing model in the repository.
    public var update: (@Sendable (Model) async throws -> Void)?

    /// A closure that fetches a model from the repository based on a query.
    public var fetch: (@Sendable (Query) async throws -> Model)?

    /// Initializes a new instance of `RepositoryService`.
    public init(
        update: (@Sendable (Model) async throws -> Void)? = nil,
        fetch: (@Sendable (Query) async throws -> Model)? = nil
    ) {
        self.update = update
        self.fetch = fetch
    }
}

/// Represents an error that occurred during a service operation.
public struct ServiceError: Identifiable {
    /// A unique identifier for the error.
    public let id = UUID()

    /// The underlying error that occurred.
    public let error: Error
}

/// A store that manages the state and operations of a repository model.
///
/// This class provides functionality for updating, fetching, and managing
/// the state of a model in a repository.
@MainActor
@Observable
public class EditStore<Model, Query> where Model: Sendable, Query: Sendable {
    /// Represents the current operation being performed on the repository.
    public enum Operation {
        case fetching(Cancellable)
        case updating(Cancellable)
    }

    /// Represents the current content state of the repository model.
    public enum Content {
        case empty
        case fetched(Model)
        case updated(Model)
        case edited(Model)

        /// Indicates whether the content is empty.
        public var isEmpty: Bool {
            if case .empty = self {
                return true
            }

            return false
        }
    }

    /// The current service error, if any.
    public var serviceError: ServiceError?
    /// The current operation being performed, if any.
    public var currentOperation: Operation?
    /// The current content state of the repository model.
    public var content: Content = .empty
    /// The current model, derived from the content state.

    public var model: Model? {
        get {
            switch content {
            case .empty:
                nil

            case let .fetched(model):
                model

            case let .updated(model):
                model

            case let .edited(model):
                model
            }
        }

        set {
            guard let newValue else {
                content = .empty
                return
            }

            content = .edited(newValue)
        }
    }

    private let service: RepositoryService<Query, Model>
    private let queryProvider: QueryProvider<Query>
    @ObservationIgnored
    private var fetchTask: Task<Model, Error>?
    @ObservationIgnored
    private var updateTask: Task<Void, Error>?

    /// Initializes a new instance of `EditStore`.
    ///
    /// - Parameters:
    ///   - service: The repository service to use for operations.
    ///   - queryProvider: A closure that provides the query for fetching.
    public init(
        service: RepositoryService<Query, Model>,
        queryProvider: @escaping QueryProvider<Query>
    ) {
        self.service = service
        self.queryProvider = queryProvider
    }

    /// Updates the existing model in the repository.
    ///
    /// - Parameter model: The updated model.
    public func changeModel(_ model: Model) {
        content = .edited(model)
    }

    /// Fetches the model from the repository.
    public func fetch() async {
        guard let fetcher = service.fetch else { return }
        let oldContent = content
        serviceError = nil

        let query = queryProvider()
        let task = Task {
            try Task.checkCancellation()
            let model = try await fetcher(query)
            try Task.checkCancellation()
            return model
        }

        fetchTask = task
        let cancellable = Cancellable { task.cancel() }
        currentOperation = .fetching(cancellable)

        do {
            let model = try await task.value
            fetchTask = nil
            if Task.isCancelled {
                content = oldContent
            } else {
                content = .fetched(model)
            }
        } catch is CancellationError {
            fetchTask = nil
            content = oldContent
        } catch {
            fetchTask = nil
            serviceError = ServiceError(error: error)
        }
    }

    /// Updates the current model in the repository.
    public func update() async {
        guard let updater = service.update else { return }
        guard case let .edited(model) = content else { return }

        let oldContent = content
        serviceError = nil

        let task = Task {
            try Task.checkCancellation()
            try await updater(model)
            try Task.checkCancellation()
        }

        updateTask = task
        let cancellable = Cancellable { task.cancel() }
        currentOperation = .updating(cancellable)

        do {
            try await task.value
            updateTask = nil
            if Task.isCancelled {
                content = oldContent
            } else {
                content = .updated(model)
            }
        } catch is CancellationError {
            updateTask = nil
            content = oldContent
        } catch {
            updateTask = nil
            serviceError = ServiceError(error: error)
        }
    }

    public func cancel() {
        switch currentOperation {
        case let .fetching(cancellable):
            cancellable.cancel()

        case let .updating(cancellable):
            cancellable.cancel()

        case .none:
            break
        }
    }
}
