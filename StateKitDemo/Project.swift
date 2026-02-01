// Project.swift
// Copyright (c) 2026 Moroverse
// Created by Daniel Moro on 2026-02-01 12:28 GMT.

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
            infoPlist: .extendingDefault(
                with: [
                    "UILaunchScreen": [
                        "UIColorName": "",
                        "UIImageName": ""
                    ]
                ]
            ),
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
            ],
            settings: .settings(
                base: [
                    "SWIFT_DEFAULT_ACTOR_ISOLATION": "MainActor",
                    "SWIFT_APPROACHABLE_CONCURRENCY": true,
                    "SWIFT_VERSION": "6.0"
                ],
                defaultSettings: .recommended
            )
        )
    ]
)
