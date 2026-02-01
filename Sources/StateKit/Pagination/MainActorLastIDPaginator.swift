// MainActorLastIDPaginator.swift
// Copyright (c) 2026 Moroverse
// Created by Daniel Moro on 2025-04-06 16:31 GMT.

/**
 A MainActor-isolated cursor-based paginator that uses an element's ID as the pagination cursor.

 `MainActorLastIDPaginator` is a type alias for `MainActorCursorPaginator` where the cursor type is `Element.ID`.
 This provides a convenient interface for the common case of paginating by the last element's identifier,
 with MainActor isolation for direct UI integration.

 For more complex pagination scenarios requiring composite cursors (e.g., timestamp + ID),
 use `MainActorCursorPaginator` directly with a tuple or custom cursor type:
 ```swift
 // Composite cursor example
 @MainActor
 class PostViewModel {
     typealias PostCursor = (id: String, createdAt: Date)
     let paginator = MainActorCursorPaginator<Post, Query, PostCursor>(remoteLoader: ...)
 }
 ```

 ### Usage Example:
 ```swift
 @MainActor
 class PatientListViewModel: ObservableObject {
     @Published var patients: [Patient] = []

     // MainActorLastIDPaginator uses Element.ID (Patient.ID) as the cursor
     private lazy var paginator = MainActorLastIDPaginator<Patient, Query>(
         remoteLoader: loadPatients
     )

     func loadPatients(query: Query, cursor: Patient.ID?) async throws
         -> (elements: [Patient], lastCursor: Patient.ID?) {
         // Call API with cursor, map results
         return (mappedPatients, nextCursor)
     }

     func load(query: Query) async throws {
         let result = try await paginator.load(query: query)
         patients = result.items
     }

     func observeUpdates() {
         Task {
             for await page in paginator.subscribe() {
                 patients = page.items
             }
         }
     }
 }
 ```

 - Note: For full API documentation, see `MainActorCursorPaginator`.
 */
public typealias MainActorLastIDPaginator<Element, Query> = MainActorCursorPaginator<Element, Query, Element.ID> where Element: Identifiable & Sendable, Query: Hashable & Sendable
