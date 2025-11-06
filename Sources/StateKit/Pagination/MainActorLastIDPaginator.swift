// MainActorLastIDPaginator.swift
// Copyright (c) 2025 Moroverse
// Created by Daniel Moro on 2025-04-06 16:31 GMT.


@MainActor
public final class MainActorLastIDPaginator<Element, Query: Hashable> where Element: Identifiable {
    /// A function type that loads elements from a remote source.
    ///
    /// - Parameters:
    ///   - query: The query parameters used to fetch data
    ///   - lastID: Optional cursor ID indicating the last item from previous page (nil for first page)
    ///
    /// - Returns: A tuple containing:
    ///   - elements: Array of loaded elements
    ///   - lastCursor: Optional ID of the last element, used for pagination (nil if no more pages)
    ///
    /// - Throws: Any error that might occur during the remote loading process
    public typealias RemoteLoader = @MainActor (Query, Element.ID?) async throws -> (elements: [Element], lastCursor: Element.ID?)

    enum Error: Swift.Error {
        case invalidInstance
    }

    private let cache: MainActorLastIDPaginationCache<Element, Query>
    private let remoteLoader: RemoteLoader
    private let asyncSubject: MainActorSubject<Paginated<Element>>

    /// Initializes a new paginator with a remote loader function.
    ///
    /// - Parameter remoteLoader: A function that loads elements from a remote source.
    public init(remoteLoader: @escaping RemoteLoader) {
        cache = MainActorLastIDPaginationCache()
        self.remoteLoader = remoteLoader
        self.asyncSubject = MainActorSubject()
    }

    /// Loads the initial page of elements for the given query.
    ///
    /// - Parameter query: The query parameters used for loading data
    ///
    /// - Returns: A `Paginated` object containing the loaded elements and a function to load more if available
    ///
    /// - Throws: Any error that might occur during the loading process
    public func load(query: Query) async throws -> Paginated<Element> {
        let (elements, lastCursor) = try await remoteLoader(query, nil)
        cache.updateCache(key: query, lastCursor: lastCursor, elements: elements)
        return makePage(query: query, lastCursor: lastCursor, items: elements)
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
    
    @discardableResult
    public func update(
        differenceBuilder: @MainActor (_ cache: [Element]) -> Difference<Element>
    ) async throws -> Paginated<Element> {
        let params = cache.updateCache(differenceBuilder: differenceBuilder)
        guard let params else { return Paginated(items: []) }
        let result = makePage(
            query: params.key,
            lastCursor: params.lastCursor,
            items: params.elements
        )
        asyncSubject.send(result)
        return result
    }

    public func cachedElement(with id: Element.ID) -> Element? {
        cache.cachedElement(with: id)
    }
    
    public func subscribe() -> AsyncStream<Paginated<Element>> {
        return asyncSubject.stream()
    }

    private func makeRemoteLoadMoreLoader(
        query: Query,
        lastCursor: Element.ID
    ) async throws -> Paginated<Element> {
        let (elements, lastID) = try await remoteLoader(query, lastCursor)
        let latestCache = cache.updateCache(key: query, lastCursor: lastID, elements: elements)
        return makePage(query: query, lastCursor: lastID, items: latestCache)
    }

    private func makePage(
        query: Query,
        lastCursor: Element.ID?,
        items: [Element]
    ) -> Paginated<Element> {
        if let lastCursor {
            Paginated(
                items: items,
                loadMore: { @MainActor [weak self] in
                    guard let self else {
                        throw Error.invalidInstance
                    }
                    return try await makeRemoteLoadMoreLoader(
                        query: query,
                        lastCursor: lastCursor
                    )
                }
            )
        } else {
            Paginated(items: items)
        }
    }
}
