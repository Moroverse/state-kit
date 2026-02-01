// BasicListScreen.swift
// Copyright (c) 2026 Moroverse
// Created by Daniel Moro on 2026-02-01 12:20 GMT.

import StateKit
import SwiftUI

struct BasicListScreen: View {
    @State private var service = MockArticleService()
    @State private var store: ListStore<[Article], ArticleQuery, any Error>?

    var body: some View {
        Group {
            if let store {
                stateView(for: store)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Basic List")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Toggle("Fail", isOn: $service.shouldFail)
                    .toggleStyle(.switch)
            }
        }
        .task {
            let newStore = ListStore<[Article], ArticleQuery, any Error>(
                loader: { query in
                    try await service.loadArticles(query: query)
                },
                queryFactory: { .default }
            )
            store = newStore
            await newStore.load()
        }
    }

    @ViewBuilder
    private func stateView(for store: ListStore<[Article], ArticleQuery, any Error>) -> some View {
        switch store.state {
        case .idle:
            ContentUnavailableView("Idle", systemImage: "tray")

        case let .inProgress(cancellable, previousState: previous):
            if case let .loaded(articles, _) = previous {
                articleList(articles, store: store)
                    .overlay(alignment: .bottom) {
                        loadingBanner(cancellable: cancellable)
                    }
            } else {
                ProgressView("Loading articles...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(alignment: .topTrailing) {
                        Button("Cancel") { cancellable.cancel() }
                            .padding()
                    }
            }

        case let .loaded(articles, _):
            articleList(articles, store: store)

        case let .empty(label, image):
            ContentUnavailableView {
                Label(String(localized: label), systemImage: image.systemName)
            }

        case let .error(error, previousState: _):
            ContentUnavailableView {
                Label("Error", systemImage: "exclamationmark.triangle")
            } description: {
                Text(error.localizedDescription)
            } actions: {
                Button("Retry") {
                    Task { await store.load(forceReload: true) }
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func articleList(
        _ articles: [Article],
        store: ListStore<[Article], ArticleQuery, any Error>
    ) -> some View {
        List(articles) { article in
            ArticleRow(article: article)
        }
        .refreshable {
            await store.load(forceReload: true)
        }
    }

    private func loadingBanner(cancellable: Cancellable) -> some View {
        HStack {
            ProgressView()
            Text("Refreshing...")
                .font(.footnote)
            Spacer()
            Button("Cancel") { cancellable.cancel() }
                .font(.footnote)
        }
        .padding()
        .background(.ultraThinMaterial)
    }
}

// MARK: - Helpers

private extension ImageSource {
    var systemName: String {
        switch self {
        case let .system(name): name
        case .asset: "questionmark"
        }
    }
}

struct ArticleRow: View {
    let article: Article

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(article.title)
                .font(.headline)
            Text(article.author)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(article.summary)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(2)
        }
        .padding(.vertical, 2)
    }
}
