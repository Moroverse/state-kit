// Difference.swift
// Copyright (c) 2025 Moroverse
// Created by Daniel Moro on 2025-04-06 16:31 GMT.

/// Represents changes to be applied to the cached collection.
public struct Difference<Element: Identifiable> {
    /// New elements to be added to the collection.
    public let insertions: [Element]
    /// IDs of elements to be removed from the collection.
    public let deletions: [Element.ID]
    /// Elements to be updated in the collection.
    public let updates: [Element]

    /// Initializes a new difference with insertions, deletions, and updates.
    ///
    /// - Parameters:
    ///   - insertions: New elements to be added
    ///   - deletions: IDs of elements to be removed
    ///   - updates: Elements to be updated
    public init(insertions: [Element], deletions: [Element.ID], updates: [Element]) {
        self.insertions = insertions
        self.deletions = deletions
        self.updates = updates
    }
}

extension Difference: Sendable where Element: Sendable, Element.ID: Sendable {}
