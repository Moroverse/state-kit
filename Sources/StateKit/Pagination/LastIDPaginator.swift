// LastIDPaginator.swift
// Copyright (c) 2025 Moroverse
// Created by Daniel Moro on 2025-04-06 16:31 GMT.

/**
 A specialized cursor-based paginator that uses an element's ID as the pagination cursor.

 `LastIDPaginator` is a type alias for `CursorPaginator` where the cursor type is `Element.ID`.
 This provides a convenient interface for the common case of paginating by the last element's identifier.

 For more complex pagination scenarios requiring composite cursors (e.g., timestamp + ID),
 use `CursorPaginator` directly with a tuple or custom cursor type:
 ```swift
 // Composite cursor example
 typealias PostCursor = (id: String, createdAt: Date)
 let paginator = CursorPaginator<Post, Query, PostCursor>(remoteLoader: ...)
 ```

 ### Usage Example:
 ```swift
 class RemotePatientRepository {
     // LastIDPaginator uses Element.ID (Patient.ID) as the cursor
     private lazy var paginator = LastIDPaginator<Patient, Query>(remoteLoader: myRemoteLoadFunction)

     private func myRemoteLoadFunction(query: Query, cursor: Patient.ID?) async throws
         -> (elements: [Patient], lastCursor: Patient.ID?) {
         // Call API with cursor, map results
         return (mappedPatients, nextCursor)
     }

     func load(query: Query) async throws -> Paginated<Patient> {
         return try await paginator.load(query: query)
     }

     func updatePatient(_ patient: Patient) async throws -> Paginated<Patient> {
         return try await paginator.update { existingCache in
             .init(insertions: [], deletions: [], updates: [patient])
         }
     }
 }
 ```

 - Note: For full API documentation, see `CursorPaginator`.
 */
public typealias LastIDPaginator<Element, Query> = CursorPaginator<Element, Query, Element.ID> where Element: Identifiable, Query: Hashable & Sendable
