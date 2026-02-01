// LoadingConfiguration.swift
// Copyright (c) 2025 Moroverse
// Created by Daniel Moro on 2025-07-06 GMT.

import Foundation
import Clocks

/// Behavioral configuration for list loading (debounce delay and clock).
public struct LoadingConfiguration: Sendable {
    public let debounceDelay: Duration
    public let clock: any Clock<Duration>

    public static let `default` = LoadingConfiguration(
        debounceDelay: .seconds(0.5),
        clock: ContinuousClock()
    )

    public init(debounceDelay: Duration, clock: any Clock<Duration>) {
        self.debounceDelay = debounceDelay
        self.clock = clock
    }
}

/// Presentational configuration for empty states.
public struct EmptyStateConfiguration: Sendable {
    public let label: LocalizedStringResource
    public let image: ImageSource

    public static let `default` = EmptyStateConfiguration(
        label: "No results",
        image: .system("magnifyingglass")
    )

    public init(label: LocalizedStringResource, image: ImageSource) {
        self.label = label
        self.image = image
    }
}
