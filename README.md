# StateKit

Core utilities and abstractions for managing application state and data flow in Swift, built on `@Observable` and Swift concurrency.

## Key Components

### State Management

- **`ListStore`** — Full-featured store for managing asynchronous loading, debounced search, pagination, and selection for a collection of items. Conforms to `ListStateProviding`, `PaginatedListProviding`, `SearchableListProviding`, and `SelectableListProviding`.
- **`BasicListStore`** — Simpler list store without search, pagination, or selection. Conforms to `ListStateProviding`.
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

## Usage

```swift
let store = ListStore<[MyItem], MyQuery, MyError>(
    loader: { query in try await api.fetchItems(query) },
    queryBuilder: { searchTerm in MyQuery(term: searchTerm) }
)

await store.load()
await store.search("keyword")
store.select(someItemID)
```

## Documentation

The [online documentation][Documentation] has more information, code examples, etc.

## License

MIT License - See [LICENSE.txt](LICENSE.txt) for details.

[Documentation]: https://moroverse.github.io/state-kit
