// FullFeaturedListScreen.swift
// Copyright (c) 2026 Moroverse
// Created by Daniel Moro on 2026-02-01 12:21 GMT.

import StateKit
import SwiftUI

struct FullFeaturedListScreen: View {
    typealias FullStore = SelectableListStore<
        PaginatedListStore<
            SearchableListStore<Paginated<Article>, ArticleQuery, any Error>
        >
    >

    @State private var service = MockArticleService()
    @State private var store: FullStore?
    @State private var searchText = ""
    @State private var selectedArticle: Article?

    var body: some View {
        Group {
            if let store {
                stateView(for: store)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Full-Featured")
        .searchable(text: $searchText)
        .onChange(of: searchText) { _, newValue in
            guard let store else { return }
            Task { await store.search(newValue) }
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
                    .toggleStyle(.switch)
            }
        }
        .task {
            let newStore = ListStore<Paginated<Article>, ArticleQuery, any Error>(
                loader: { query in
                    try await service.loadPaginatedArticles(query: query)
                },
                queryFactory: { ArticleQuery(term: "", page: 0) }
            )
            .searchable(queryBuilder: { term in ArticleQuery(term: term, page: 0) })
            .paginated()
            .selectable(onSelectionChange: { [weak service] article in
                guard service != nil else { return }
                selectedArticle = article
            })
            store = newStore
            await newStore.load()
        }
    }

    @ViewBuilder
    private func stateView(for store: FullStore) -> some View {
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

        case let .loaded(articles, loadMoreState):
            articleList(articles, store: store)
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

    private func articleList(
        _ articles: Paginated<Article>,
        store: FullStore
    ) -> some View {
        List(articles) { article in
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
        store: FullStore
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

private extension ImageSource {
    var systemName: String {
        switch self {
        case let .system(name): name
        case .asset: "questionmark"
        }
    }
}
