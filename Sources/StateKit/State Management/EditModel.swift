// EditModel.swift
// Copyright (c) 2025 Moroverse
// Created by Daniel Moro on 2025-04-06 16:31 GMT.

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
    ///
    /// - Parameter model: The model to be updated. This should be a complete model object,
    ///                    not just the fields that have changed.
    /// - Throws: An error if the update operation fails. This could include network errors,
    ///           validation errors, or database errors depending on the implementation.
    /// - Note: This operation may have side effects such as persisting data or making network requests.
    public var update: (@Sendable (Model) async throws -> Void)?

    /// A closure that fetches a model from the repository based on a query.
    ///
    /// - Parameter query: The query used to fetch the model. The exact structure of the query
    ///                    depends on the specific implementation.
    /// - Returns: The fetched model.
    /// - Throws: An error if the fetch operation fails. This could include network errors,
    ///           or cases where the requested model is not found.
    /// - Note: This operation should not have side effects other than potentially caching results.
    public var fetch: (@Sendable (Query) async throws -> Model)?

    /// Initializes a new instance of `RepositoryService`.
    ///
    /// - Parameters:
    ///   - update: An optional closure for updating an existing model.
    ///   - fetch: An optional closure for fetching a model based on a query.
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

/// A class that manages the state and operations of a repository model.
///
/// This class provides functionality for creating, updating, fetching, and managing
/// the state of a model in a repository.
///
/// - Parameters:
///   - Model: The type of model managed by this repository.
///   - Query: The type used for querying the repository.
@MainActor
@Observable
public class EditModel<Model, Query> where Model: Sendable, Query: Sendable {
    /// Represents the current operation being performed on the repository.
    public enum Operation {
        case fetching(Task<Model, Error>)
        case updating(Task<Void, Error>)
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

    /// Initializes a new instance of `EditModel`.
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
    /// Use this method when you have modifications to an existing model.
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

        currentOperation = .fetching(task)

        do {
            let model = try await task.value
            if Task.isCancelled {
                content = oldContent
            } else {
                content = .fetched(model)
            }
        } catch is CancellationError {
            content = oldContent
        } catch {
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

        currentOperation = .updating(task)

        do {
            try await task.value
            if Task.isCancelled {
                content = oldContent
            } else {
                content = .updated(model)
            }
        } catch is CancellationError {
            content = oldContent
        } catch {
            serviceError = ServiceError(error: error)
        }
    }

    public func cancel() {
        switch currentOperation {
        case let .fetching(task):
            task.cancel()

        case let .updating(task):
            task.cancel()

        case .none:
            break
        }
    }
}
