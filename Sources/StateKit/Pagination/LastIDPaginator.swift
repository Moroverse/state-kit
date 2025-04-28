// LastIDPaginator.swift
// Copyright (c) 2025 Moroverse
// Created by Daniel Moro on 2025-04-06 16:31 GMT.

/**
 A generic actor that handles pagination using a 'last ID' (cursor-based) strategy for any collection of identifiable elements.

 `LastIDPaginator` manages the complete lifecycle of paginated data:
 1. Initial loading: Fetches the first page of data for a given query
 2. Pagination: Provides mechanism to load subsequent pages using cursor-based pagination
 3. Caching: Maintains loaded elements in memory to avoid redundant network requests
 4. Updates: Supports local modifications to the cache (insertions, updates, deletions)

 ### Usage Example:
 When used within a repository pattern:
 - The repository initializes the paginator with a remote loading function
 - Repository methods delegate pagination operations to the paginator
 - The paginator maintains the state and cache between repository method calls
 - Update operations can be performed through the repository to modify cache state

 ```swift
 class RemotePatientRepository {
 // 1. Initialize paginator in repository
     private lazy var paginator = LastIDPaginator<Patient, Query>(remoteLoader: myRemoteLoadFunction)

     // Define remote loader function that:
     // - Calls API with query parameters and cursor
     // - Maps response to domain objects
     // - Extracts next pagination cursor
     private func myRemoteLoadFunction(query: Query, cursor: Patient.ID?) async throws
         -> (elements: [Patient], lastCursor: Patient.ID?) {
         // Call API, map results, extract cursor...
         return (mappedPatients, nextCursor)
     }

     // 2. Repository load method delegates to paginator for initial page
     func load(query: Query) async throws -> Paginated<Patient> {
         return try await paginator.load(query: query)
     }

     // 3. Pagination happens automatically through the Paginated's loadMore callback
     // when consumer calls: let nextPage = try await initialPage.loadMore?()

     // 4. Repository update method uses paginator to modify cache
     func updatePatient(_ patient: Patient) async throws -> Paginated<Patient> {
         // After successful remote update
         return try await paginator.update { existingCache in
             // Calculate and return difference
             .init(insertions: [], deletions: [], updates: [patient])
         }
     }
 }
 ```
 */
public actor LastIDPaginator<Element, Query: Hashable & Sendable> where Element: Identifiable & Sendable, Element.ID: Sendable {
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
    public typealias RemoteLoader = @Sendable (Query, Element.ID?) async throws -> (elements: [Element], lastCursor: Element.ID?)

    enum Error: Swift.Error {
        case invalidInstance
    }

    private let cache: LastIDPaginationCache<Element, Query>
    private let remoteLoader: RemoteLoader

    /// Initializes a new paginator with a remote loader function.
    ///
    /// - Parameter remoteLoader: A function that loads elements from a remote source.
    public init(remoteLoader: @escaping RemoteLoader) {
        cache = LastIDPaginationCache()
        self.remoteLoader = remoteLoader
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
            lastCursor: params.lastCursor,
            items: params.elements
        )
    }

    public func cachedElement(with id: Element.ID) async -> Element? {
        await cache.cachedElement(with: id)
    }

    private func makeRemoteLoadMoreLoader(
        query: Query,
        lastCursor: Element.ID
    ) async throws -> Paginated<Element> {
        let (elements, lastID) = try await remoteLoader(query, lastCursor)
        let latestCache = await cache.updateCache(key: query, lastCursor: lastID, elements: elements)
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
                loadMore: { [weak self] in
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
