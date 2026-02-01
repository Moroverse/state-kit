// ConfigurationTests.swift
// Copyright (c) 2026 Moroverse
// Created by Daniel Moro on 2025-07-06 17:34 GMT.

import Foundation
import Testing
@testable import StateKit

@Suite
struct LoadingConfigurationTests {
    @Test
    func defaultConfiguration_hasDebounceDelay() {
        let config = LoadingConfiguration.default

        #expect(config.debounceDelay == .seconds(0.5))
    }

    @Test
    func defaultConfiguration_hasClock() {
        let config = LoadingConfiguration.default

        // Can't easily test clock equality, just verify it exists and is ContinuousClock
        #expect(config.clock is ContinuousClock)
    }
}

@Suite
struct EmptyStateConfigurationTests {
    @Test
    func defaultConfiguration_hasEmptyContentLabel() {
        let config = EmptyStateConfiguration.default

        #expect(config.label.key == "No results")
    }

    @Test
    func defaultConfiguration_hasEmptyContentImage() {
        let config = EmptyStateConfiguration.default

        #expect(config.image == .system("magnifyingglass"))
    }
}
