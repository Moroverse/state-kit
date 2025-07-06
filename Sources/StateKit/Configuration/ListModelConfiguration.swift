// ListModelConfiguration.swift
// Copyright (c) 2025 Moroverse
// Created by Daniel Moro on 2025-07-06 GMT.

import Foundation

public struct ListModelConfiguration: Sendable {
    public let emptyContentLabel: LocalizedStringResource
    public let emptyContentImageResource: String
    
    public static let `default` = ListModelConfiguration(
        emptyContentLabel: "No results",
        emptyContentImageResource: "magnifyingglass"
    )
    
    public init(emptyContentLabel: LocalizedStringResource, emptyContentImageResource: String) {
        self.emptyContentLabel = emptyContentLabel
        self.emptyContentImageResource = emptyContentImageResource
    }
}