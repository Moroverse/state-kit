// String+Scripts.swift
// Copyright (c) 2026 Moroverse
// Created by Daniel Moro on 2026-02-01 11:34 GMT.

import ProjectDescription

public extension String {
    static let lintScript: Self = """
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
