# ``StateKit``

A Swift library for managing async list and detail loading state, built on `@Observable` and Swift concurrency.

## Overview

StateKit provides a composable set of stores and protocols for loading, searching, paginating, and selecting items in Swift applications. All stores are `@MainActor`-isolated and use `@Observable` for SwiftUI integration.

The library follows a **composable decorator pattern**: start with a base ``ListStore`` and wrap it with decorators to add features incrementally.

```swift
let store = ListStore(loader: api.fetch, queryProvider: { .default })
    .searchable(queryBuilder: { term in Query(term: term) })
    .paginated()
    .selectable()
```

Each decorator conforms to ``ListStateProviding`` and delegates to its wrapped store. The fluent API is powered by ``ListStoreComposable``, an internal protocol giving decorators access to the root ``ListStore``.

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:Architecture>

### State Management

- ``ListStore``
- ``SearchableListStore``
- ``PaginatedListStore``
- ``SelectableListStore``
- ``DetailStore``

### Protocols

- ``ListStateProviding``
- ``PaginatedListProviding``
- ``SearchableListProviding``
- ``SelectableListProviding``
- ``ListStoreComposable``

### State Enums

- ``ListLoadingState``
- ``LoadingState``
- ``LoadMoreState``
- ``ImageSource``

### Pagination

- ``CursorPaginator``
- ``MainActorCursorPaginator``
- ``LastIDPaginator``
- ``MainActorLastIDPaginator``
- ``OffsetPaginator``
- ``Paginated``
- ``Difference``

### Configuration

- ``LoadingConfiguration``
- ``EmptyStateConfiguration``

### Utilities

- ``Debounce``
- ``Cancellable``

### Type Aliases

- ``DataLoader``
- ``QueryBuilder``
- ``QueryProvider``
