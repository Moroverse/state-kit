// CursorPaginator.swift
// Copyright (c) 2026 Moroverse
// Created by Daniel Moro on 2025-04-06 16:31 GMT.

/**
 A generic actor that handles pagination using a cursor-based strategy for any collection of identifiable elements.

 `CursorPaginator` manages the complete lifecycle of paginated data with support for flexible cursor types:
 1. Initial loading: Fetches the first page of data for a given query
 2. Pagination: Provides mechanism to load subsequent pages using cursor-based pagination
 3. Caching: Maintains loaded elements in memory to avoid redundant network requests
 4. Updates: Supports local modifications to the cache (insertions, updates, deletions)

 The cursor type is generic, allowing for both simple cursors (like `String` or `UUID`) and composite cursors
 (like tuples `(id: String, createdAt: Date)` or custom structs).

 ### Usage Example with Simple Cursor:
 ```swift
 class RemotePatientRepository {
     // Simple UUID cursor (equivalent to LastIDPaginator)
     private lazy var paginator = CursorPaginator<Patient, Query, UUID>(remoteLoader: myRemoteLoadFunction)

     private func myRemoteLoadFunction(query: Query, cursor: UUID?) async throws
         -> (elements: [Patient], lastCursor: UUID?) {
         // Call API, map results, extract cursor...
         return (mappedPatients, nextCursor)
     }

     func load(query: Query) async throws -> Paginated<Patient> {
         return try await paginator.load(query: query)
     }
 }
 ```

 ### Usage Example with Composite Cursor:
 ```swift
 class RemotePostRepository {
     // Composite cursor for pagination by timestamp + ID
     typealias PostCursor = (id: String, createdAt: Date)
     private lazy var paginator = CursorPaginator<Post, Query, PostCursor>(remoteLoader: myRemoteLoadFunction)

     private func myRemoteLoadFunction(query: Query, cursor: PostCursor?) async throws
         -> (elements: [Post], lastCursor: PostCursor?) {
         // If cursor exists, query posts created before cursor.createdAt with id < cursor.id
         // Otherwise, get the first page
         let posts = try await api.getPosts(before: cursor?.createdAt, afterId: cursor?.id)
         let nextCursor = posts.last.map { (id: $0.id, createdAt: $0.createdAt) }
         return (posts, nextCursor)
     }
 }
 ```

 - Note: The `Cursor` type must conform to `Hashable & Sendable`. Swift tuples automatically conform when their elements do.
 */
public actor CursorPaginator<Element: Identifiable & Sendable, Query: Hashable & Sendable, Cursor: Hashable & Sendable> where Element.ID: Sendable {
    /// A function type that loads elements from a remote source.
    ///
    /// - Parameters:
    ///   - query: The query parameters used to fetch data
    ///   - cursor: Optional cursor indicating the position of the last item from previous page (nil for first page)
    ///
    /// - Returns: A tuple containing:
    ///   - elements: Array of loaded elements
    ///   - lastCursor: Optional cursor for the last element, used for pagination (nil if no more pages)
    ///
    /// - Throws: Any error that might occur during the remote loading process
    public typealias RemoteLoader = @Sendable (Query, Cursor?) async throws -> (elements: [Element], lastCursor: Cursor?)

    private let cache: CursorPaginationCache<Element, Query, Cursor>
    private let remoteLoader: RemoteLoader
    private let asyncSubject: AsyncSubject<Paginated<Element>>

    /// Initializes a new paginator with a remote loader function.
    ///
    /// - Parameter remoteLoader: A function that loads elements from a remote source.
    public init(remoteLoader: @escaping RemoteLoader) {
        cache = CursorPaginationCache()
        self.remoteLoader = remoteLoader
        asyncSubject = AsyncSubject()
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
        await cache.updateCache(key: query, lastCursor: lastCursor, elements: elements)
        return makePage(query: query, lastCursor: lastCursor, items: elements)
    }

    /// Updates the cached elements based on local changes.
    ///
    /// This method allows modifying the cached collection without performing a remote request.
    /// It's useful for reflecting local changes like adding, updating, or removing elements.
    ///
    /// This method also notifies subscribers via `subscribe()` with the updated result.
    ///
    /// - Parameter differenceBuilder: A closure that computes the changes to apply based on current cache
    ///
    /// - Returns: A `Paginated` object containing the updated elements
    ///
    /// - Throws: Any error that might occur during the update process
    @discardableResult
    public func update(
        differenceBuilder: @Sendable (_ cache: [Element]) -> Difference<Element>
    ) async throws -> Paginated<Element> {
        let params = await cache.updateCache(differenceBuilder: differenceBuilder)
        guard let params else { return Paginated(items: []) }
        let result = makePage(
            query: params.key,
            lastCursor: params.lastCursor,
            items: params.elements
        )
        await asyncSubject.send(result)
        return result
    }

    /// Returns a cached element with the specified ID, if it exists.
    ///
    /// - Parameter id: The identifier of the element to retrieve
    ///
    /// - Returns: The element if found in cache, otherwise nil
    public func cachedElement(for id: Element.ID) async -> Element? {
        await cache.cachedElement(for: id)
    }

    /// Subscribe to pagination updates.
    ///
    /// Returns an `AsyncStream` that emits `Paginated<Element>` whenever the cache is updated
    /// via the `update()` method. This allows reactive updates when local changes occur.
    ///
    /// - Returns: An async stream of paginated results
    ///
    /// ### Usage Example:
    /// ```swift
    /// Task {
    ///     for await page in await paginator.subscribe() {
    ///         self.items = page.items
    ///     }
    /// }
    /// ```
    public func subscribe() async -> AsyncStream<Paginated<Element>> {
        await asyncSubject.stream()
    }

    private func loadMorePage(
        query: Query,
        lastCursor: Cursor
    ) async throws -> Paginated<Element> {
        let (elements, newCursor) = try await remoteLoader(query, lastCursor)
        let latestCache = await cache.updateCache(key: query, lastCursor: newCursor, elements: elements)
        return makePage(query: query, lastCursor: newCursor, items: latestCache)
    }

    private func makePage(
        query: Query,
        lastCursor: Cursor?,
        items: [Element]
    ) -> Paginated<Element> {
        CursorPaginatorPage.makePage(
            query: query,
            lastCursor: lastCursor,
            items: items
        ) { [weak self] query, cursor in
            guard let self else { throw CursorPaginatorPage.Error.paginatorDeallocated }
            return try await loadMorePage(query: query, lastCursor: cursor)
        }
    }
}
