// SelectionManager.swift
// Copyright (c) 2025 Moroverse
// Created by Daniel Moro on 2025-07-06 GMT.

import Foundation

/**
 A protocol that defines the interface for managing selection state and behavior.
 
 `SelectionManager` encapsulates the logic for handling element selection within collections,
 providing a clean separation of concerns from data loading and state management.
 
 ### Usage Example:
 
 ```swift
 let selectionManager = CallbackSelectionManager<MyItem> { selectedItem in
     print("Selected: \(selectedItem?.name ?? "None")")
 }
 
 selectionManager.selectedID = "item-1"
 selectionManager.handleSelection(from: items)
 ```
 
 - Note: The generic `Element` type must conform to `Identifiable` for ID-based selection.
 */
public protocol SelectionManager<Element> {
    /// The type of elements that can be selected
    associatedtype Element: Identifiable
    
    /// The currently selected element's ID, if any
    var selectedID: Element.ID? { get set }
    
    /// Whether this selection manager can handle selections (e.g., has a callback configured)
    var canHandleSelection: Bool { get }
    
    /**
     Handles selection logic for the given collection.
     
     This method finds the element matching `selectedID` in the provided collection
     and triggers appropriate selection behavior (e.g., calling a callback).
     
     - Parameter collection: The collection to search for the selected element
     */
    func handleSelection<C: Collection>(from collection: C) where C.Element == Element
}

// MARK: - CallbackSelectionManager

public final class CallbackSelectionManager<Element>: SelectionManager where Element: Identifiable {
    public var selectedID: Element.ID?
    
    public var canHandleSelection: Bool {
        onSelectionChange != nil
    }
    
    private let onSelectionChange: ((Element?) -> Void)?
    
    public init(onSelectionChange: ((Element?) -> Void)? = nil) {
        self.onSelectionChange = onSelectionChange
    }
    
    public func handleSelection<C: Collection>(from collection: C) where C.Element == Element {
        guard let selectedID = selectedID,
              let onSelectionChange = onSelectionChange else {
            return
        }
        
        if let element = collection.first(where: { $0.id == selectedID }) {
            onSelectionChange(element)
        }
    }
}