// Article.swift
// Copyright (c) 2026 Moroverse
// Created by Daniel Moro on 2026-02-01 11:34 GMT.

import Foundation

struct Article: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let author: String
    let summary: String
    let publishedAt: Date
}

struct ArticleQuery: Equatable, Sendable, Hashable {
    var term: String
    var page: Int

    static let `default` = ArticleQuery(term: "", page: 0)
}
