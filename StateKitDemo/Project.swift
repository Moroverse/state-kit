// Project.swift
// Copyright (c) 2026 Moroverse
// Created by Daniel Moro on 2026-02-01 11:34 GMT.

import ProjectDescription
import ProjectDescriptionHelpers

let project = Project(
    name: "StateKitDemo",
    targets: [
        .target(
            name: "StateKitDemo",
            destinations: .iOS,
            product: .app,
            bundleId: "com.moroverse.StateKitDemo",
            infoPlist: .extendingDefault(with: [:]),
            buildableFolders: [
                "Sources",
                "Resources"
            ],
            scripts: [
                .pre(
                    script: .lintScript,
                    name: "Lint",
                    basedOnDependencyAnalysis: false
                )
            ],
            dependencies: [
                .external(name: "StateKit")
            ]
        )
    ]
)
