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
}