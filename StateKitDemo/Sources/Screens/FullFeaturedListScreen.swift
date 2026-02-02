// FullFeaturedListScreen.swift
// Copyright (c) 2026 Moroverse
// Created by Daniel Moro on 2026-02-01 12:28 GMT.

import StateKit
import SwiftUI

struct FullFeaturedListScreen: View {
    typealias FullStore = SelectableListStore<PaginatedListStore<SearchableListStore<Paginated<Article>, ArticleQuery, any Error>, Article>>

    @State private var service: MockArticleService
    @State private var store: FullStore
    @State private var searchText = ""
    @State private var selectedArticle: Article?

    init(service: MockArticleService = MockArticleService()) {
        self.service = service
        let store = ListStore<Paginated<Article>, ArticleQuery, any Error>(
            loader: { query in
                try await service.loadPaginatedArticles(query: query)
            },
            queryProvider: { ArticleQuery(term: "", page: 0) }
        )
        .searchable(queryBuilder: { term in ArticleQuery(term: term, page: 0) })
        .paginated()
        .selectable()

        self.store = store
    }

    var body: some View {
        stateView(for: store)
            .navigationTitle("Full-Featured")
            .searchable(text: $searchText)
            .onChange(of: searchText) { _, newValue in
                Task { await store.search(newValue) }
            }
            .onChange(of: store.selection) { _, newSelection in
                if let newSelection, case let .loaded(articles, _) = store.state {
                    selectedArticle = articles.first { $0.id == newSelection }
                } else {
                    selectedArticle = nil
                }
            }
            .sheet(item: $selectedArticle) { article in
                NavigationStack {
                    ArticleDetailView(article: article)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") { selectedArticle = nil }
                            }
                        }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Toggle("Fail", isOn: $service.shouldFail)
                        .buttonStyle(.glass)
                        .toggleStyle(.button)
                }
            }
            .task {
                await store.load()
            }
    }

    @ViewBuilder
    private func stateView(for store: FullStore) -> some View {
        switch store.state {
        case .idle:
            ContentUnavailableView("Idle", systemImage: "tray")

        case let .inProgress(cancellable, previousState: previous):
            if case let .loaded(articles, loadMoreState) = previous {
                articleList(articles, loadMoreState)
                    .overlay(alignment: .bottom) {
                        loadingBanner(cancellable: cancellable)
                    }
            } else {
                VStack {
                    ProgressView("Loading articles...")
                    Button("Cancel") { cancellable.cancel() }
                }
            }

        case let .loaded(articles, loadMoreState):
            articleList(articles, loadMoreState)

        case .empty:
            ContentUnavailableView {
                Label(
                    String(localized: store.emptyStateConfiguration.label),
                    systemImage: store.emptyStateConfiguration.image.systemName
                )
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
        _ articles: Paginated<Article>,
        _ loadMoreState: LoadMoreState
    ) -> some View {
        List {
            ForEach(articles) { article in
                Button {
                    store.select(article.id)
                } label: {
                    HStack {
                        ArticleRow(article: article)
                        Spacer()
                        if store.selection == article.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.tint)
                        }
                    }
                }
                .tint(.primary)
                .accessibilityAddTraits(store.selection == article.id ? .isSelected : [])
                .accessibilityHint(store.selection == article.id ? "" : "Double tap to select")
            }
            loadMoreFooter(state: loadMoreState)
        }
        .refreshable {
            await store.load(forceReload: true)
        }
    }

    @ViewBuilder
    private func loadMoreFooter(
        state: LoadMoreState
    ) -> some View {
        switch state {
        case .unavailable:
            EmptyView()

        case let .inProgress(cancellable):
            HStack {
                ProgressView()
                Text("Loading more...")
                    .font(.footnote)
                Spacer()
                Button("Cancel") { cancellable.cancel() }
                    .font(.footnote)
            }

        case .ready:
            Button {
                Task { try? await store.loadMore() }
            } label: {
                Text("Load More")
                    .font(.footnote)
                    .frame(maxWidth: .infinity)
            }
            .accessibilityHint("Loads next page of articles")
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
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Article Detail

private struct ArticleDetailView: View {
    let article: Article

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(article.title)
                    .font(.title)
                Text("By \(article.author)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(article.publishedAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Divider()
                Text(article.summary)
                    .font(.body)
            }
            .padding()
        }
        .navigationTitle("Detail")
        .navigationBarTitleDisplayMode(.inline)
    }
}
