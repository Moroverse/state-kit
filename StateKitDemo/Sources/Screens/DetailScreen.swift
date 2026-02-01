// DetailScreen.swift
// Copyright (c) 2026 Moroverse
// Created by Daniel Moro on 2026-02-01 12:18 GMT.

import StateKit
import SwiftUI

struct DetailScreen: View {
    @State private var service = MockArticleService()
    @State private var selectedID = "1"
    @State private var store: DetailStore<Article, String, any Error>?

    private let articleIDs = ["1", "2", "3", "4", "5"]

    var body: some View {
        Group {
            if let store {
                stateView(for: store)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Detail Store")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Toggle("Fail", isOn: $service.shouldFail)
                    .toggleStyle(.switch)
            }
        }
        .task {
            let newStore = DetailStore<Article, String, any Error>(
                loader: { query in
                    try await service.loadArticleDetail(query: query)
                },
                queryProvider: { selectedID }
            )
            store = newStore
            await newStore.load()
        }
        .onChange(of: selectedID) { _, _ in
            guard let store else { return }
            Task { await store.load() }
        }
    }

    private func stateView(for store: DetailStore<Article, String, any Error>) -> some View {
        VStack {
            Picker("Article", selection: $selectedID) {
                ForEach(articleIDs, id: \.self) { id in
                    Text("Article \(id)").tag(id)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            Spacer()

            switch store.state {
            case .idle:
                ContentUnavailableView("Idle", systemImage: "tray")

            case let .inProgress(cancellable, previousState: previous):
                if case let .loaded(article) = previous {
                    articleDetail(article)
                        .opacity(0.5)
                        .overlay {
                            ProgressView()
                        }
                        .overlay(alignment: .topTrailing) {
                            Button("Cancel") { cancellable.cancel() }
                                .padding()
                        }
                } else {
                    ProgressView("Loading article...")
                        .overlay(alignment: .topTrailing) {
                            Button("Cancel") { cancellable.cancel() }
                                .padding()
                        }
                }

            case let .loaded(article):
                articleDetail(article)

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
                        Task { await store.load() }
                    }
                    .buttonStyle(.bordered)
                }
            }

            Spacer()
        }
    }

    private func articleDetail(_ article: Article) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text(article.title)
                .font(.title2)
            Text("By \(article.author)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(article.publishedAt, style: .date)
                .font(.caption)
                .foregroundStyle(.tertiary)
            Text(article.summary)
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
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
