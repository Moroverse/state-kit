// EventHandling.swift
// Copyright (c) 2025 Moroverse
// Created by Daniel Moro on 2024-07-20 03:24 GMT.

import Foundation

/// A protocol representing an event that can occur within the system.
public protocol Event {
    var eventId: UUID { get }
    var timestamp: Date { get }
    var version: String { get }
}

/// A protocol representing a subscription to an event.
public protocol EventSubscription {
    /// Unsubscribes from the event, stopping further notifications.
    func unsubscribe()
}

public protocol EventSubscriber {
    /// Subscribes to events of a specific type `T`.
    ///
    /// - Parameters:
    ///   - eventType: The type of event to subscribe to.
    ///   - handler: A closure that will be called when an event of type `T` is published.
    /// - Returns: An `EventSubscription` that allows unsubscribing from the event.
    func subscribe<T: Event>(_ eventType: T.Type, handler: @escaping @Sendable (T) -> Void) -> EventSubscription
}

/// A protocol for objects that can publish events.
public protocol EventPublisher {
    /// Publishes an event of type `T`.
    ///
    /// - Parameter event: The event to be published.
    func publish(_ event: some Event)
}

/// A protocol representing an event broker that handles event publication and subscription.
public typealias EventBroker = EventPublisher & EventSubscriber
