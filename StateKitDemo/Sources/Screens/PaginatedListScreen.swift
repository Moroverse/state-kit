// PaginatedListScreen.swift
// Copyright (c) 2026 Moroverse
// Created by Daniel Moro on 2026-02-01 12:21 GMT.

import StateKit
import SwiftUI

struct PaginatedListScreen: View {
    @State private var service = MockArticleService()
    @State private var store: PaginatedListStore<ListStore<Paginated<Article>, ArticleQuery, any Error>>?

    var body: some View {
        Group {
            if let store {
                stateView(for: store)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Paginated List")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Toggle("Fail", isOn: $service.shouldFail)
                    .toggleStyle(.switch)
            }
        }
        .task {
            let newStore = ListStore<Paginated<Article>, ArticleQuery, any Error>(
                loader: { query in
                    try await service.loadPaginatedArticles(query: query)
                },
                queryFactory: { .default }
            ).paginated()
            store = newStore
            await newStore.load()
        }
    }

    @ViewBuilder
    private func stateView(
        for store: PaginatedListStore<ListStore<Paginated<Article>, ArticleQuery, any Error>>
    ) -> some View {
        switch store.state {
        case .idle:
            ContentUnavailableView("Idle", systemImage: "tray")

        case let .inProgress(cancellable, previousState: previous):
            if case let .loaded(articles, _) = previous {
                paginatedList(articles, store: store)
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

        case let .loaded(articles, loadMoreState):
            paginatedList(articles, store: store)
                .safeAreaInset(edge: .bottom) {
                    loadMoreFooter(state: loadMoreState, store: store)
                }

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

    private func paginatedList(
        _ articles: Paginated<Article>,
        store: PaginatedListStore<ListStore<Paginated<Article>, ArticleQuery, any Error>>
    ) -> some View {
        List(articles) { article in
            ArticleRow(article: article)
                .onAppear {
                    if article.id == articles.last?.id {
                        Task { try? await store.loadMore() }
                    }
                }
        }
        .refreshable {
            await store.load(forceReload: true)
        }
    }

    @ViewBuilder
    private func loadMoreFooter(
        state: LoadMoreState,
        store: PaginatedListStore<ListStore<Paginated<Article>, ArticleQuery, any Error>>
    ) -> some View {
        switch state {
        case .unavailable:
            Text("All articles loaded")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)

        case let .inProgress(cancellable):
            HStack {
                ProgressView()
                Text("Loading more...")
                    .font(.footnote)
                Spacer()
                Button("Cancel") { cancellable.cancel() }
                    .font(.footnote)
            }
            .padding()
            .background(.ultraThinMaterial)

        case .ready:
            Button {
                Task { try? await store.loadMore() }
            } label: {
                Text("Load More")
                    .font(.footnote)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding()
            .background(.ultraThinMaterial)
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

private extension ImageSource {
    var systemName: String {
        switch self {
        case let .system(name): name
        case .asset: "questionmark"
        }
    }
}
