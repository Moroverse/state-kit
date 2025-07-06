// StateKit.swift
// Copyright (c) 2025 Moroverse
// Created by Daniel Moro on 2025-04-06 16:31 GMT.


/// A closure type for loading a model based on a query.
public typealias ModelLoader<Query, Model> = @Sendable (Query) async throws -> Model

/// A closure type for building a query from a string.
public typealias QueryBuilder<Query> = (String) -> Query

/// A closure type for providing a query.
public typealias QueryProvider<Query> = () -> Query
