// PaginatedListScreen.swift
// Copyright (c) 2026 Moroverse
// Created by Daniel Moro on 2026-02-01 12:28 GMT.

import StateKit
import SwiftUI

struct PaginatedListScreen: View {
    @State private var service = MockArticleService()
    @State private var store: ComposedListStore<Article, ArticleQuery, any Error>.PaginatedSelectable

    init(service: MockArticleService = MockArticleService()) {
        self.service = service
        store = ListStore<Paginated<Article>, ArticleQuery, any Error>(
            loader: { query in
                try await service.loadPaginatedArticles(query: query)
            },
            queryProvider: { .default }
        )
        .paginated()
        .selectable()
    }

    private var selectionBinding: Binding<String?> {
        Binding {
            store.selection
        } set: { newSelection in
            store.select(newSelection)
        }
    }

    var body: some View {
        stateView()
            .navigationTitle("Paginated List")
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
    private func stateView() -> some View {
        switch store.state {
        case .idle:
            ContentUnavailableView("Idle", systemImage: "tray")

        case let .inProgress(cancellable, previousState: previous):
            if case let .loaded(articles, loadMoreState) = previous {
                paginatedList(articles, loadMoreState)
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
            paginatedList(articles, loadMoreState)

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

    private func paginatedList(
        _ articles: Paginated<Article>,
        _ loadMoreState: LoadMoreState
    ) -> some View {
        List(selection: selectionBinding) {
            ForEach(articles) { article in
                ArticleRow(article: article)
                    .tag(article.id)
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
