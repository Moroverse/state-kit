// ListModelConfigurationTests.swift
// Copyright (c) 2025 Moroverse
// Created by Daniel Moro on 2025-07-06 GMT.

import Foundation
import Testing
@testable import StateKit

@Suite
struct ListModelConfigurationTests {
    
    @Test
    func defaultConfiguration_hasEmptyContentLabel() async throws {
        let config = ListModelConfiguration.default
        
        #expect(config.emptyContentLabel.key == "No results")
    }
    
    @Test
    func defaultConfiguration_hasEmptyContentImageResource() async throws {
        let config = ListModelConfiguration.default
        
        #expect(config.emptyContentImageResource == "magnifyingglass")
    }
    
    @Test
    func defaultConfiguration_hasDebounceDelay() async throws {
        let config = ListModelConfiguration.default
        
        #expect(config.debounceDelay == .seconds(0.5))
    }
    
    @Test
    func defaultConfiguration_hasClock() async throws {
        let config = ListModelConfiguration.default
        
        // Can't easily test clock equality, just verify it exists and is ContinuousClock
        #expect(config.clock is ContinuousClock)
    }
}