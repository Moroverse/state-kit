// SelectionManagerTests.swift
// Copyright (c) 2026 Moroverse
// Created by Daniel Moro on 2025-07-06 16:54 GMT.

import Foundation
import Testing
@testable import StateKit

@Suite
struct SelectionManagerTests {
    @Test
    func callbackSelectionManager_triggersCallbackWhenElementFound() {
        let items = [
            TestItem(id: "1", name: "Item 1"),
            TestItem(id: "2", name: "Item 2")
        ]

        var selectedItem: TestItem?
        let selectionManager = CallbackSelectionManager<TestItem> { selected in
            selectedItem = selected
        }

        selectionManager.selectedID = "2"
        selectionManager.handleSelection(from: items)

        #expect(selectedItem?.id == "2")
        #expect(selectedItem?.name == "Item 2")
    }

    @Test
    func callbackSelectionManager_doesNotTriggerCallbackWhenElementNotFound() {
        let items = [
            TestItem(id: "1", name: "Item 1"),
            TestItem(id: "2", name: "Item 2")
        ]

        var callbackTriggered = false
        let selectionManager = CallbackSelectionManager<TestItem> { _ in
            callbackTriggered = true
        }

        selectionManager.selectedID = "99" // Non-existent ID
        selectionManager.handleSelection(from: items)

        #expect(callbackTriggered == false)
    }

    @Test
    func callbackSelectionManager_doesNotTriggerCallbackWhenSelectedIDIsNil() {
        let items = [
            TestItem(id: "1", name: "Item 1"),
            TestItem(id: "2", name: "Item 2")
        ]

        var callbackTriggered = false
        let selectionManager = CallbackSelectionManager<TestItem> { _ in
            callbackTriggered = true
        }

        selectionManager.selectedID = nil
        selectionManager.handleSelection(from: items)

        #expect(callbackTriggered == false)
    }
}

// MARK: - Test Helpers

private struct TestItem: Identifiable, Equatable {
    let id: String
    let name: String
}
