// Paginated.swift
// Copyright (c) 2025 Moroverse
// Created by Daniel Moro on 2025-04-06 16:31 GMT.

import Foundation

/// A `Paginated` structure that manages a collection of items and provides functionality to load more
/// items asynchronously.
///
/// `Paginated` conforms to the `Collection` protocol, allowing it to be used like any
/// other collection in Swift.
/// It provides asynchronous loading of more items through the `loadMore` closure.
///
/// - Note: The `loadMore` closure is optional and can be `nil` if no further items are available to load.
///
/// - Parameters:
///   - Item: The type of elements contained in the `Paginated` structure.
public struct Paginated<Item> {
    /// A closure that asynchronously loads more items and returns a new instance of `Paginated`
    /// with the additional items.
    ///
    /// The `LoadMoreCompletion` typealias defines a closure that asynchronously returns
    /// a new instance of `Paginated`
    /// with additional items.
    public typealias LoadMoreCompletion = @Sendable () async throws -> Self

    /// The items currently contained in the `Paginated` structure.
    ///
    /// An array of items of the specified type `Item`.
    public let items: [Item]

    /// A closure that, when called, asynchronously loads more items and returns
    /// a new instance of `Paginated`.
    ///
    /// This property is optional and can be `nil` if there are no more items to load.
    public let loadMore: LoadMoreCompletion?

    /// Initializes a new instance of `Paginated` with the given items and an optional
    /// `loadMore` closure.
    ///
    /// - Parameters:
    ///   - items: The items to be contained in the new instance of `Paginated`.
    ///   - loadMore: An optional closure to load more items asynchronously. Defaults to `nil`.
    public init(items: [Item], loadMore: LoadMoreCompletion? = nil) {
        self.items = items
        self.loadMore = loadMore
    }
}

public extension Paginated {
    var hasMore: Bool {
        loadMore != nil
    }
}

extension Paginated: Sendable where Item: Sendable {}

// MARK: - Collection Conformance

extension Paginated: Collection {
    public var startIndex: Int { items.startIndex }
    public var endIndex: Int { items.endIndex }
    public subscript(index: Int) -> Item {
        items[index]
    }

    public func index(after i: Int) -> Int {
        items.index(after: i)
    }
}

extension Paginated: RandomAccessCollection {}

public extension Paginated {
    func map<T>(_ transform: @escaping @Sendable (Item) throws -> T) rethrows -> Paginated<T> {
        if let loadMore {
            try Paginated<T>(items: items.map(transform)) {
                let result = try await loadMore()
                return try result.map(transform)
            }

        } else {
            try Paginated<T>(items: items.map(transform))
        }
    }
}
