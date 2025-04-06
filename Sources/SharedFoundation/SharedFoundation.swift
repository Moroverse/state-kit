// SharedFoundation.swift
// Copyright (c) 2025 Moroverse
// Created by Daniel Moro on 2024-07-20 03:24 GMT.

/// An enumeration representing the different states of a data-loading process.
///
/// The `ContentState` enum is a generic type that describes the state of a process that loads
/// a model of type `Model`.
/// It can be used to represent the various stages of loading data, such as when the data is
/// empty, loading, successfully loaded, or has encountered an error.
///
/// - Parameters:
///   - Model: The type of the model being loaded.
public indirect enum ContentState<Model> {
    /// Indicates that there is no data available.
    ///
    /// This case is used when the data is in an empty state.
    case empty

    /// Indicates that the data is currently being loaded.
    ///
    /// This case is used to represent the loading state.
    case inProgress(Task<Model, Error>, currentState: Self)

    /// Indicates that the data has been successfully loaded.
    ///
    /// This case holds the loaded data of type `Model`.
    ///
    /// - Parameter model: The model data that has been loaded.
    case ready(Model)
}

extension ContentState: Equatable where Model: Equatable {}

/// A closure type for loading a model based on a query.
public typealias ModelLoader<Query, Model> = @Sendable (Query) async throws -> Model

/// A closure type for building a query from a string.
public typealias QueryBuilder<Query> = (String) -> Query

/// A closure type for providing a query.
public typealias QueryProvider<Query> = () -> Query
