// ImageSource+SystemName.swift
// Copyright (c) 2026 Moroverse
// Created by Daniel Moro on 2026-02-02 06:09 GMT.

import StateKit

extension ImageSource {
    var systemName: String {
        switch self {
        case let .system(name): name
        case .asset: "questionmark"
        }
    }
}
