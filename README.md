# StateKit
Core utilities and abstractions for managing application state and data flow.

Key components:
- `State`: An enumeration for representing the state of data-loading processes.
- `ListModel`: A generic model for managing lists of data with support for pagination and asynchronous loading.
- `DetailModel`: A model for managing the state of a single item's details.
- `RepositoryModel`: A model for managing CRUD operations on a repository.
- `Debouncer`: A utility for managing rate-limited operations.
- `Paginated`: A structure for handling paginated collections.
- Event handling protocols: `Event`, `EventSubscription`, `EventBroker`, etc.

## Documentation

The [online documentation][Documentation] has more information, code examples, etc.

## License

MIT License - See [LICENSE.txt](LICENSE.txt) for details.

[Documentation]: https://moroverse.github.io/state-kit