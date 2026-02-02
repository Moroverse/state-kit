# StateKit

Core utilities and abstractions for managing application state and data flow in Swift, built on `@Observable` and Swift concurrency.

## Key Components

### State Management

- **`ListStore`** — Core `@Observable` store for async collection loading. Manages state machine, caching, and cancellation. Wrappable with decorator stores for search, pagination, and selection.
- **`DetailStore`** — Store for managing the loading state of a single item.
- **`ListLoadingState`** — State enum for list loading: `idle`, `inProgress`, `loaded`, `empty`, `error`. Includes `LoadMoreState` for pagination.
- **`LoadingState`** — State enum for single-item loading: `idle`, `inProgress`, `loaded`, `empty`, `error`.

### Pagination

- **`CursorPaginator`** / **`MainActorCursorPaginator`** — Cursor-based pagination with automatic caching, difference-based updates, and `AsyncStream` subscriptions.
- **`LastIDPaginator`** / **`MainActorLastIDPaginator`** — Convenience typealiases for cursor paginators using the element's ID as the cursor.
- **`OffsetPaginator`** — Offset-based pagination with caching.
- **`Paginated`** — A collection wrapper carrying items and an optional `loadMore` closure.
- **`Difference`** — Describes insertions, deletions, and updates for local cache modifications.

### Protocols

- **`ListStateProviding`** — Observable protocol for list state (used by views).
- **`PaginatedListProviding`** — Extends `ListStateProviding` with `loadMore()`.
- **`SearchableListProviding`** — Extends `ListStateProviding` with `search(_:)` and `cancelSearch()`.
- **`SelectableListProviding`** — Extends `ListStateProviding` with `select(_:)` and `selection`.

### Utilities

- **`Debounce`** — Actor-based debounce using variadic generics.
- **`AsyncSubject`** / **`MainActorSubject`** — Broadcast values to multiple `AsyncStream` subscribers.

### Decorator Stores

- **`SearchableListStore`** — Adds debounced text search via `SearchEngine`.
- **`PaginatedListStore`** — Adds load-more pagination via `PaginationEngine`.
- **`SelectableListStore`** — Adds item selection tracking.

## Usage

### Basic List

```swift
let store = ListStore<[MyItem], MyQuery, MyError>(
    loader: { query in try await api.fetchItems(query) },
    queryFactory: { MyQuery() }
)

await store.load()
```

### Composable Decorator Chain

```swift
let store = ListStore<Paginated<MyItem>, MyQuery, MyError>(
    loader: { query in try await api.fetchPaginatedItems(query) },
    queryFactory: { MyQuery() }
)
.searchable(queryBuilder: { term in MyQuery(term: term) })
.paginated()
.selectable()

await store.load()
await store.search("keyword")
try await store.loadMore()
store.select(someItemID)
```

### Single Item

```swift
let detailStore = DetailStore<MyItem, UUID, MyError>(
    loader: { id in try await api.fetchItem(id) },
    queryProvider: { itemID }
)

await detailStore.load()
```

## Documentation

The [online documentation][Documentation] has more information, code examples, etc.

## License

MIT License - See [LICENSE.txt](LICENSE.txt) for details.

[Documentation]: https://moroverse.github.io/state-kit
