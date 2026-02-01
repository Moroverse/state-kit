// ConfigurationTests.swift
// Copyright (c) 2025 Moroverse
// Created by Daniel Moro on 2025-07-06 GMT.

import Foundation
import Testing
@testable import StateKit

@Suite
struct LoadingConfigurationTests {

    @Test
    func defaultConfiguration_hasDebounceDelay() async throws {
        let config = LoadingConfiguration.default

        #expect(config.debounceDelay == .seconds(0.5))
    }

    @Test
    func defaultConfiguration_hasClock() async throws {
        let config = LoadingConfiguration.default

        // Can't easily test clock equality, just verify it exists and is ContinuousClock
        #expect(config.clock is ContinuousClock)
    }
}

@Suite
struct EmptyStateConfigurationTests {

    @Test
    func defaultConfiguration_hasEmptyContentLabel() async throws {
        let config = EmptyStateConfiguration.default

        #expect(config.label.key == "No results")
    }

    @Test
    func defaultConfiguration_hasEmptyContentImage() async throws {
        let config = EmptyStateConfiguration.default

        #expect(config.image == .system("magnifyingglass"))
    }
}
