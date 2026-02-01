// Article.swift
// Copyright (c) 2026 Moroverse
// Created by Daniel Moro on 2026-02-01 12:28 GMT.

import Foundation

nonisolated struct Article: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let author: String
    let summary: String
    let publishedAt: Date
}

nonisolated struct ArticleQuery: Equatable, Sendable, Hashable {
    var term: String
    var page: Int

    static let `default` = ArticleQuery(term: "", page: 0)
}
