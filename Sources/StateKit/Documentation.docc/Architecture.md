# Architecture

Understanding StateKit's composable decorator pattern, state machines, and internal structure.

## Overview

StateKit is built on three pillars: a **composable decorator pattern** for flexible store composition, **state machine enums** for UI-driven state, and **internal engines** that extract reusable logic.

### Composable Decorator Pattern

The core design separates concerns into layered decorators. Each decorator adds a single capability (search, pagination, or selection) while delegating everything else to the wrapped store.

```
┌─────────────────────────────────────────┐
│         SelectableListStore             │ ← selection tracking
│  ┌───────────────────────────────────┐  │
│  │      PaginatedListStore           │  │ ← load-more lifecycle
│  │  ┌─────────────────────────────┐  │  │
│  │  │   SearchableListStore       │  │  │ ← debounced search
│  │  │  ┌───────────────────────┐  │  │  │
│  │  │  │      ListStore        │  │  │  │ ← core loading + caching
│  │  │  │   (LoadingEngine)     │  │  │  │
│  │  │  └───────────────────────┘  │  │  │
│  │  │      (SearchEngine)         │  │  │
│  │  └─────────────────────────────┘  │  │
│  │        (PaginationEngine)         │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

The fluent API makes composition readable:

```swift
ListStore(loader: fetch, queryProvider: { .default })
    .searchable(queryBuilder: { term in Query(term: term) })
    .paginated()
    .selectable()
```

Decorators are **order-sensitive**: `.searchable()` is only available on ``ListStore`` directly, while `.paginated()` and `.selectable()` are available on any ``ListStoreComposable`` conformant. The typical order is:

1. ``ListStore`` (base)
2. `.searchable()` → ``SearchableListStore``
3. `.paginated()` → ``PaginatedListStore``
4. `.selectable()` → ``SelectableListStore``

### Protocol Hierarchy

Protocols are orthogonal traits designed for free composition via conditional conformances:

```
                ListStateProviding
               /        |         \
  PaginatedList   SearchableList   SelectableList
    Providing       Providing        Providing
```

- ``ListStateProviding`` — Base protocol. Provides `state` and `load(forceReload:)`.
- ``PaginatedListProviding`` — Adds `loadMore()`.
- ``SearchableListProviding`` — Adds `search(_:)` and `cancelSearch()`.
- ``SelectableListProviding`` — Adds `selection` and `select(_:)`.

All decorator stores gain conditional conformance to protocols their base supports. For example, if you wrap a `SearchableListStore` with `.paginated()`, the resulting `PaginatedListStore` automatically conforms to `SearchableListProviding` too.

``ListStoreComposable`` is the internal protocol that enables the fluent builder API. It exposes the root ``ListStore`` via `coreStore`, letting decorators wire up engines and state closures.

### State Machine: ListLoadingState

``ListLoadingState`` is an indirect enum that drives the UI for list views:

```
         ┌─────────────────────────────────────┐
         │                idle                  │
         └──────────────────┬──────────────────┘
                            │ load()
                            ▼
         ┌─────────────────────────────────────┐
         │       inProgress(previousState)      │◄────┐
         └──────┬───────────┬──────────┬───────┘     │
                │           │          │              │
          empty │    loaded │   error  │       reload │
                ▼           ▼          ▼              │
         ┌──────────┐ ┌──────────┐ ┌────────────┐    │
         │  empty   │ │  loaded  │ │   error    │────┘
         │(label,   │ │(model,   │ │(failure,   │
         │ image)   │ │ loadMore)│ │ previous)  │
         └──────────┘ └────┬─────┘ └────────────┘
                           │
                    ┌──────┴──────┐
                    │ LoadMoreState│
                    ├─────────────┤
                    │ unavailable │
                    │ ready       │
                    │ inProgress  │
                    └─────────────┘
```

Key characteristics:

- **`inProgress` carries `previousState`**: This allows the UI to show existing content while loading, rather than flashing a loading spinner.
- **`error` carries `previousState`**: Lets the UI show an error overlay on existing content.
- **`loaded` carries `loadMoreState`**: The ``LoadMoreState`` nested within `loaded` tracks pagination state independently.
- **Indirect enum**: Required because `inProgress` and `error` reference `Self`.

### State Machine: LoadingState

``LoadingState`` is the single-item counterpart used by ``DetailStore``:

```
    idle → inProgress(previousState) → loaded(model)
                                     → empty(label, image)
                                     → error(failure, previousState)
```

Same recursive pattern as ``ListLoadingState`` but without pagination.

### Internal Engines

Logic is extracted into reusable engine types to avoid duplication:

#### LoadingEngine

Manages the load/cache/cancel lifecycle for ``ListStore``:

- **Query caching**: Skips the network call when the same query is already loaded or in progress.
- **Task management**: Creates and cancels `Task` instances, preventing concurrent loads for the same query.
- **State transitions**: Computes the new state (loaded, empty, error) and calls back into the store via a `setState` closure.
- **Cache invalidation**: Resets the cached query when errors occur or when explicitly requested.

#### SearchEngine

Coordinates search queries with debouncing for ``SearchableListStore``:

- **Query string tracking**: Maintains the latest query string for building queries.
- **Debounce integration**: Uses the ``Debounce`` actor to coalesce rapid search inputs.
- **Lazy initialization**: The debounce actor is created on first use with the configured ``LoadingConfiguration``.

#### PaginationEngine

Manages the load-more lifecycle for ``PaginatedListStore``:

- **LoadMoreState resolution**: Determines whether a model supports pagination by checking if it's a ``Paginated`` type with a `loadMore` closure.
- **State transitions**: Moves between `.ready`, `.inProgress`, and `.unavailable` within the ``LoadMoreState``.
- **Deduplication**: Awaits an in-progress load-more task rather than starting a duplicate.

### Pagination Layer

The pagination layer operates independently from the store layer. Paginators are actors that manage the full lifecycle of paginated data:

- ``CursorPaginator`` — Actor-isolated, cursor-based pagination with generic cursor types (simple IDs, composite tuples, custom structs).
- ``MainActorCursorPaginator`` — MainActor-isolated variant for direct UI integration.
- ``OffsetPaginator`` — Actor-isolated, offset-based pagination.
- ``LastIDPaginator`` / ``MainActorLastIDPaginator`` — Type aliases for cursor paginators using `Element.ID` as the cursor.

All paginators provide:

- **Loading**: Initial load and load-more operations.
- **Caching**: In-memory cache of loaded elements.
- **Local updates**: Apply ``Difference`` (insertions, deletions, updates) without network requests.
- **Cache lookup**: Retrieve individual cached elements by ID.

Cursor paginators additionally support **`AsyncStream` subscriptions** via `subscribe()`, emitting updated pages when the cache changes.

### Concurrency Model

StateKit embraces Swift 6 strict concurrency:

- All stores and engines are `@MainActor`, ensuring UI state mutations happen on the main thread.
- Paginators use actor isolation (`actor` for background, `@MainActor` for UI-bound variants).
- The ``Debounce`` utility is an actor with type parameter packs for flexible function signatures.
- ``Cancellable`` wraps task cancellation in a `Sendable`, `Hashable` value type that can be stored in enum cases.

### Data Flow

A typical load cycle:

1. View calls `store.load()`.
2. `ListStore` asks the `queryProvider` for a query.
3. `LoadingEngine` checks the cache — if the query matches and data is loaded, it returns immediately.
4. Otherwise, `LoadingEngine` creates a `Task`, sets state to `.inProgress(cancellable, previousState:)`.
5. The loader closure fetches data asynchronously.
6. On success: state becomes `.loaded(model, loadMoreState:)` or `.empty`.
7. On failure: state becomes `.error(failure, previousState:)`.
8. On cancellation: state reverts to the previous state.

A search cycle adds debouncing:

1. View calls `searchableStore.search("term")`.
2. `SearchEngine` updates the query string and builds a query via the `queryBuilder`.
3. `Debounce` actor waits for the configured delay, cancelling any pending debounce.
4. After the delay, `SearchEngine` delegates to `LoadingEngine` for the actual load.

## Topics

### Stores

- ``ListStore``
- ``DetailStore``

### Decorators

- ``SearchableListStore``
- ``PaginatedListStore``
- ``SelectableListStore``

### Protocols

- ``ListStateProviding``
- ``PaginatedListProviding``
- ``SearchableListProviding``
- ``SelectableListProviding``
- ``ListStoreComposable``

### State

- ``ListLoadingState``
- ``LoadingState``
- ``LoadMoreState``
