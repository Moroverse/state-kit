// SharedTestHelpers.swift
// Copyright (c) 2026 Moroverse
// Created by Daniel Moro on 2026-02-02 06:55 GMT.

import Foundation
import TestKit
@testable import StateKit

struct TestItem: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
}

extension AsyncSpy {
    @Sendable
    func load(_ query: some Sendable) async throws -> Result {
        try await perform(query)
    }
}
