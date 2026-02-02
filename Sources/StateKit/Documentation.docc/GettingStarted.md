# Getting Started with StateKit

Load, search, paginate, and select items in your Swift app with minimal boilerplate.

## Overview

StateKit manages the lifecycle of async data loading through observable stores that integrate directly with SwiftUI. This guide walks through the core concepts and common patterns.

### Installation

Add StateKit to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Moroverse/state-kit.git", from: "1.0.0")
]
```

Then add it to your target:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "StateKit", package: "state-kit")
    ]
)
```

### Define Your Types

StateKit is generic over your model, query, and error types. Start by defining them:

```swift
struct Item: Identifiable, Sendable {
    let id: UUID
    let title: String
}

struct ItemQuery: Sendable, Equatable {
    var searchTerm: String = ""
}

enum ItemError: Error {
    case networkFailure
}
```

### Create a Basic List Store

``ListStore`` is the core type for loading collections. Provide a `loader` closure that fetches data and a `queryProvider` that constructs the default query:

```swift
let store = ListStore<[Item], ItemQuery, ItemError>(
    loader: { query in
        try await api.fetchItems(query: query)
    },
    queryProvider: { ItemQuery() }
)
```

### Load Data

Call ``ListStore/load(forceReload:)`` to trigger a load. The store manages cancellation, caching, and state transitions automatically:

```swift
await store.load()

// Force a fresh load, bypassing the cache
await store.load(forceReload: true)
```

### Observe State in SwiftUI

Use the ``ListLoadingState`` enum to drive your UI:

```swift
struct ItemListView: View {
    @State var store = ListStore<[Item], ItemQuery, ItemError>(
        loader: { query in try await api.fetchItems(query: query) },
        queryProvider: { ItemQuery() }
    )

    var body: some View {
        Group {
            switch store.state {
            case .idle:
                Text("Ready to load")

            case .inProgress(_, previousState: let previous):
                if case .loaded(let items, _) = previous {
                    // Show existing items with a loading indicator
                    List(items) { item in Text(item.title) }
                        .overlay { ProgressView() }
                } else {
                    ProgressView()
                }

            case .loaded(let items, _):
                List(items) { item in Text(item.title) }

            case .empty:
                ContentUnavailableView(
                    store.emptyStateConfiguration.label,
                    systemImage: "magnifyingglass"
                )

            case .error(let error, _):
                Text("Error: \(error.localizedDescription)")
            }
        }
        .task { await store.load() }
    }
}
```

### Add Search

Wrap the store with ``ListStore/searchable(queryBuilder:loadingConfiguration:)`` to add debounced search:

```swift
let searchableStore = ListStore<[Item], ItemQuery, ItemError>(
    loader: { query in try await api.fetchItems(query: query) },
    queryProvider: { ItemQuery() }
)
.searchable(queryBuilder: { term in
    ItemQuery(searchTerm: term)
})
```

The view layer uses the ``SearchableListProviding`` protocol:

```swift
struct SearchableItemListView<Store: SearchableListProviding & ListStateProviding>: View
    where Store.Model == [Item], Store.Failure == ItemError
{
    @Bindable var store: Store

    var body: some View {
        // ...list rendering
    }
    .searchable(text: searchBinding)
    .task { await store.load() }

    var searchBinding: Binding<String> {
        Binding(
            get: { "" },
            set: { newValue in
                Task { await store.search(newValue) }
            }
        )
    }
}
```

### Add Pagination

Chain `.paginated()` to add load-more support. Your `loader` should return a ``Paginated`` collection:

```swift
let paginatedStore = ListStore<Paginated<Item>, ItemQuery, ItemError>(
    loader: { query in
        try await api.fetchPaginatedItems(query: query)
    },
    queryProvider: { ItemQuery() }
)
.searchable(queryBuilder: { term in ItemQuery(searchTerm: term) })
.paginated()
```

Trigger pagination from the UI:

```swift
// In a list cell's onAppear
if item == items.last {
    Task { try await paginatedStore.loadMore() }
}
```

### Add Selection

Chain `.selectable()` to track which item is selected:

```swift
let fullStore = ListStore<Paginated<Item>, ItemQuery, ItemError>(
    loader: { query in try await api.fetchPaginatedItems(query: query) },
    queryProvider: { ItemQuery() }
)
.searchable(queryBuilder: { term in ItemQuery(searchTerm: term) })
.paginated()
.selectable()

// Select an item
fullStore.select(someItem.id)

// Read the selection
let selectedID = fullStore.selection
```

### Load a Single Item

Use ``DetailStore`` for loading individual items:

```swift
let detailStore = DetailStore<Item, UUID, ItemError>(
    loader: { id in
        try await api.fetchItem(id: id)
    },
    queryProvider: { itemID }
)

await detailStore.load()
```

### Program Against Protocols

Views should depend on protocols, not concrete types. This decouples the view from the specific store composition:

```swift
struct ItemList<Provider: ListStateProviding>: View
    where Provider.Model.Element == Item
{
    @Bindable var provider: Provider

    var body: some View {
        switch provider.state {
        case .loaded(let items, _):
            List(items) { item in Text(item.title) }
        // ... other states
        }
    }
}
```

Combine protocols for specific requirements:

```swift
// A view that needs search + pagination
struct FullItemList<Provider: SearchableListProviding & PaginatedListProviding>: View
    where Provider.Model.Element == Item
{
    // ...
}
```

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
- ``SearchableListProviding``
- ``PaginatedListProviding``
- ``SelectableListProviding``
