// String+Scripts.swift
// Copyright (c) 2026 Moroverse
// Created by Daniel Moro on 2026-02-01 12:28 GMT.

import ProjectDescription

public extension String {
    static let lintScript: Self = """
    #!/bin/bash
    export PATH="$PATH:$HOME/.local/share/mise/shims"

    if command -v swiftformat >/dev/null 2>&1; then
        swiftformat . 2>/dev/null
    else
        echo "warning: swiftformat not installed"
    fi

    if command -v swiftlint >/dev/null 2>&1; then
        swiftlint lint --quiet 2>/dev/null
    else
        echo "warning: swiftlint not installed"
    fi
    """
}
