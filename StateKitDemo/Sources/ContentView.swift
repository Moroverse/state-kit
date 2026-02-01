// ContentView.swift
// Copyright (c) 2026 Moroverse
// Created by Daniel Moro on 2026-02-01 11:35 GMT.

import SwiftUI

struct ContentView: View {
    var body: some View {
        List {
            Section("List Stores") {
                NavigationLink("Basic List", destination: BasicListScreen())
                NavigationLink("Paginated List", destination: PaginatedListScreen())
                NavigationLink("Full-Featured List", destination: FullFeaturedListScreen())
            }

            Section("Detail Store") {
                NavigationLink("Detail Loading", destination: DetailScreen())
            }
        }
        .navigationTitle("StateKit Demo")
    }
}
