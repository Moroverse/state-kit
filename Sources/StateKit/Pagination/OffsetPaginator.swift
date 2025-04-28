// OffsetPaginator.swift
// Copyright (c) 2025 Moroverse
// Created by Daniel Moro on 2025-04-06 16:31 GMT.

public actor OffsetPaginator<Element, Query: Hashable & Sendable> where Element: Identifiable & Sendable, Element.ID: Sendable {
    /// A function type that loads elements from a remote source using offset-based pagination.
    ///
    /// - Parameters:
    ///   - query: The query parameters used to fetch data
    ///   - offset: The pagination offset (starting from 0 for first page)
    ///
    /// - Returns: A tuple containing:
    ///   - elements: Array of loaded elements
    ///   - hasNextPage: Boolean indicating if more pages are available
    ///
    /// - Throws: Any error that might occur during the remote loading process
    public typealias RemoteLoader = @Sendable (Query, Int) async throws -> (elements: [Element], hasNextPage: Bool)

    enum Error: Swift.Error {
        case invalidInstance
    }

    private let remoteLoader: RemoteLoader
    private let cache: OffsetPaginationCache<Element, Query>

    /// Initializes a new paginator with a remote loader function and page size.
    ///
    /// - Parameters:
    ///   - remoteLoader: A function that loads elements from a remote source.
    public init(remoteLoader: @escaping RemoteLoader) {
        self.remoteLoader = remoteLoader
        cache = .init()
    }

    /// Loads the initial page of elements for the given query.
    ///
    /// - Parameter query: The query parameters used for loading data
    ///
    /// - Returns: A `Paginated` object containing the loaded elements and a function to load more if available
    ///
    /// - Throws: Any error that might occur during the loading process
    public func load(query: Query) async throws -> Paginated<Element> {
        let (elements, hasNextPage) = try await remoteLoader(query, 0)
        let offset = elements.count
        await cache.updateCache(key: query, offset: offset, hasMore: hasNextPage, elements: elements)
        return makePage(query: query, elements: elements, offset: offset, hasNextPage: hasNextPage)
    }

    /// Updates the cached elements based on local changes.
    ///
    /// This method allows modifying the cached collection without performing a remote request.
    /// It's useful for reflecting local changes like adding, updating, or removing elements.
    ///
    /// - Parameter differenceBuilder: A closure that computes the changes to apply based on current cache
    ///
    /// - Returns: A `Paginated` object containing the updated elements
    ///
    /// - Throws: Any error that might occur during the update process
    public func update(
        differenceBuilder: @Sendable (_ cache: [Element]) -> Difference<Element>
    ) async throws -> Paginated<Element> {
        let params = await cache.updateCache(differenceBuilder: differenceBuilder)
        guard let params else { return Paginated(items: []) }
        return makePage(
            query: params.key,
            elements: params.elements,
            offset: params.offset,
            hasNextPage: params.hasMore
        )
    }

    public func cachedElement(with id: Element.ID) async -> Element? {
        await cache.cachedElement(with: id)
    }

    private func loadMore(query: Query, offset: Int) async throws -> Paginated<Element> {
        let (newElements, hasNextPage) = try await remoteLoader(query, offset)
        let newOffset = offset + newElements.count

        let latestCache = await cache.updateCache(key: query, offset: newOffset, hasMore: hasNextPage, elements: newElements)
        return makePage(query: query, elements: latestCache, offset: newOffset, hasNextPage: hasNextPage)
    }

    private func makePage(
        query: Query,
        elements: [Element],
        offset: Int,
        hasNextPage: Bool
    ) -> Paginated<Element> {
        if hasNextPage {
            Paginated(
                items: elements,
                loadMore: { [weak self] in
                    guard let self else {
                        throw Error.invalidInstance
                    }
                    return try await loadMore(query: query, offset: offset)
                }
            )
        } else {
            Paginated(items: elements)
        }
    }
}
