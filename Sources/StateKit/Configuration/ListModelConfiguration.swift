// ListModelConfiguration.swift
// Copyright (c) 2025 Moroverse
// Created by Daniel Moro on 2025-07-06 GMT.

import Foundation

public struct ListModelConfiguration: Sendable {
    public let emptyContentLabel: LocalizedStringResource
    
    public static let `default` = ListModelConfiguration(
        emptyContentLabel: "No results"
    )
    
    public init(emptyContentLabel: LocalizedStringResource) {
        self.emptyContentLabel = emptyContentLabel
    }
}