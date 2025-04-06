# Event Handling

These protocols define abstractions for handling events within a system.

## Overview

- ``Event``: Represents an event with an associated payload.
- ``EventSubscription``: Represents a subscription to an event.
- ``EventBroker``: Manages event publication and subscription.

## Details

- ``Event``
    - Represents an event that can occur within the system.
    - Provides an associated type `Payload` for event-specific data.
    - Conform to this protocol to define custom event types.

- ``EventSubscription``:
    - Represents a subscription to an event.
    - Provides a method `unsubscribe()` to stop receiving event notifications.

- ``EventBroker``:
    - Manages the publication and subscription of events.
    - Provides methods `publish(_:)` to publish events and `subscribe(_:handler:)`
to subscribe to events with a handler closure.
    - Returns an `EventSubscription` object for managing event subscriptions.

## Usage

Use these protocols to implement a flexible event handling system where components can
communicate via events without direct dependencies.

- Example:
1. Define a custom event
```swift

public struct CustomEvent: Event {
    public struct Payload {
        let id: String
    }

    public let payload: Payload
}

public extension Event where Self == CustomEvent {
    static func customEvent(_ id: String) ->  CustomEvent {
        CustomEvent(payload: .init(id: id))
    }
}
```

2. Implement event handling using EventBroker
    1. Implement publishing logic

```swift
func perform(_ model: SomeModel) {
    try await someService.serve(model)
    eventBroker.publish(.customEvent(model.id))
}
```
    2. Implement subscription logic

```swift
func onLoad() {
    subscription = eventBroker.subscribe(CustomEvent.self) { _ in
        Task { @MainActor [weak viewModel] in
            await viewModel?.load()
        }
    }
}

func onDismiss() {
    subscription.unsubscribe()
}
```
