// MockArticleService.swift
// Copyright (c) 2026 Moroverse
// Created by Daniel Moro on 2026-02-01 12:28 GMT.

import Foundation
import StateKit

@MainActor
@Observable
final class MockArticleService {
    var delay: Duration = .milliseconds(800)
    var shouldFail = false

    private let pageSize = 20
    private let totalArticles = 75

    // MARK: - Loaders

    func loadArticles(query: ArticleQuery) async throws -> [Article] {
        try await Task.sleep(for: delay)
        if shouldFail { throw MockError.networkFailure }
        return generateArticles(
            matching: query.term,
            count: pageSize
        )
    }

    func loadPaginatedArticles(query: ArticleQuery, base: [Article]? = nil) async throws -> Paginated<Article> {
        try await Task.sleep(for: delay)
        if shouldFail { throw MockError.networkFailure }

        let newArticles = generateArticles(
            matching: query.term,
            page: query.page,
            count: pageSize
        )

        let articles = if let base { base + newArticles } else { newArticles }

        let hasMore = (query.page + 1) * pageSize < totalArticles
        let nextPage = query.page + 1

        if hasMore {
            let loadMore: Paginated<Article>.LoadMoreAction = { [weak self] in
                guard let self else { throw MockError.networkFailure }
                return try await loadPaginatedArticles(
                    query: ArticleQuery(term: query.term, page: nextPage),
                    base: articles
                )
            }
            return Paginated(items: articles, loadMore: loadMore)
        } else {
            return Paginated(items: articles)
        }
    }

    func loadArticleDetail(query: String) async throws -> Article {
        try await Task.sleep(for: delay)
        if shouldFail { throw MockError.networkFailure }
        return Article(
            id: query,
            title: "Article \(query)",
            author: "Author \(query)",
            summary: "This is a detailed summary for article \(query). " +
                "It contains extended information about the topic.",
            publishedAt: Date().addingTimeInterval(-Double.random(in: 0 ... 86400 * 30))
        )
    }

    // MARK: - Generation

    private func generateArticles(
        matching term: String,
        page: Int = 0,
        count: Int
    ) -> [Article] {
        let offset = page * count
        return (0 ..< count).map { index in
            let id = offset + index
            let title = term.isEmpty
                ? "Article \(id + 1)"
                : "\(term.capitalized) — Article \(id + 1)"
            return Article(
                id: "\(id)",
                title: title,
                author: ["Alice", "Bob", "Charlie", "Diana"][id % 4],
                summary: "Summary for article \(id + 1). This article covers interesting topics.",
                publishedAt: Date().addingTimeInterval(-Double(id) * 3600)
            )
        }
    }
}

// MARK: - Errors

enum MockError: LocalizedError {
    case networkFailure

    var errorDescription: String? {
        switch self {
        case .networkFailure:
            "Network request failed. Please try again."
        }
    }
}
