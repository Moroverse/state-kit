// ListModelConfiguration.swift
// Copyright (c) 2025 Moroverse
// Created by Daniel Moro on 2025-07-06 GMT.

import Foundation
import Clocks

public struct ListModelConfiguration: Sendable {
    public let emptyContentLabel: LocalizedStringResource
    public let emptyContentImageResource: ImageSource
    public let debounceDelay: Duration
    public let clock: any Clock<Duration>
    
    public static let `default` = ListModelConfiguration(
        emptyContentLabel: "No results",
        emptyContentImageResource: .system("magnifyingglass"),
        debounceDelay: .seconds(0.5),
        clock: ContinuousClock()
    )
    
    public init(emptyContentLabel: LocalizedStringResource, emptyContentImageResource: ImageSource, debounceDelay: Duration, clock: any Clock<Duration>) {
        self.emptyContentLabel = emptyContentLabel
        self.emptyContentImageResource = emptyContentImageResource
        self.debounceDelay = debounceDelay
        self.clock = clock
    }
}
