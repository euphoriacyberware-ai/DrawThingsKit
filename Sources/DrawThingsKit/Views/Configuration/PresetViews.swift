//
//  PresetViews.swift
//  DrawThingsKit
//
//  Created by euphoriacyberware-ai.
//  Copyright © 2025 euphoriacyberware-ai
//
//  Licensed under the MIT License.
//  See LICENSE file in the project root for license information.
//

import SwiftUI
import SwiftData

/// A dropdown menu for quickly loading saved configuration presets.
///
/// Example usage:
/// ```swift
/// PresetMenuView(modelsManager: connectionManager.modelsManager)
///     .environmentObject(configurationManager)
/// ```
public struct PresetMenuView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedConfiguration.updatedAt, order: .reverse) private var presets: [SavedConfiguration]

    @EnvironmentObject private var configurationManager: ConfigurationManager

    /// Optional ModelsManager for resolving models after loading a preset.
    /// When provided, LoRAs, ControlNets, and model selections will be properly resolved.
    private var modelsManager: ModelsManager?

    public init(modelsManager: ModelsManager? = nil) {
        self.modelsManager = modelsManager
    }

    public var body: some View {
        Menu {
            if presets.isEmpty {
                Text("No saved presets")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(presets) { preset in
                    Button {
                        loadPreset(preset)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(preset.name)
                            if !preset.tags.isEmpty {
                                Text(preset.tags.joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Divider()

                Menu("Delete") {
                    ForEach(presets) { preset in
                        Button(role: .destructive) {
                            deletePreset(preset)
                        } label: {
                            Text(preset.name)
                        }
                    }
                }
            }
        } label: {
            Label("Presets", systemImage: "list.bullet")
                .frame(maxWidth: .infinity)
        }
        .menuStyle(.borderlessButton)
    }

    private func loadPreset(_ preset: SavedConfiguration) {
        if configurationManager.loadFromJSON(preset.configurationJSON) {
            // Resolve models to populate selectedLoRAs, selectedControls, etc.
            if let manager = modelsManager {
                configurationManager.resolveModels(from: manager)
            }
        }
    }

    private func deletePreset(_ preset: SavedConfiguration) {
        modelContext.delete(preset)
    }
}

/// A full-screen browser view for searching and managing configuration presets.
///
/// Example usage:
/// ```swift
/// .sheet(isPresented: $showingPresetBrowser) {
///     PresetBrowserView(modelsManager: connectionManager.modelsManager)
/// }
/// ```
public struct PresetBrowserView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedConfiguration.updatedAt, order: .reverse) private var presets: [SavedConfiguration]

    @EnvironmentObject private var configurationManager: ConfigurationManager

    @State private var searchText = ""
    @State private var selectedPreset: SavedConfiguration?

    /// Optional ModelsManager for resolving models after loading a preset.
    /// When provided, LoRAs, ControlNets, and model selections will be properly resolved.
    private var modelsManager: ModelsManager?

    public init(modelsManager: ModelsManager? = nil) {
        self.modelsManager = modelsManager
    }

    private var filteredPresets: [SavedConfiguration] {
        if searchText.isEmpty {
            return presets
        }
        return presets.filter { $0.matches(query: searchText) }
    }

    public var body: some View {
        NavigationStack {
            List(selection: $selectedPreset) {
                ForEach(filteredPresets) { preset in
                    PresetRow(preset: preset)
                        .tag(preset)
                        .contextMenu {
                            Button(role: .destructive) {
                                deletePreset(preset)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
                .onDelete(perform: deletePresets)
            }
            .searchable(text: $searchText, prompt: "Search by name or tag")
            .navigationTitle("Presets")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Load") {
                        if let preset = selectedPreset {
                            if configurationManager.loadFromJSON(preset.configurationJSON) {
                                // Resolve models to populate selectedLoRAs, selectedControls, etc.
                                if let manager = modelsManager {
                                    configurationManager.resolveModels(from: manager)
                                }
                            }
                            dismiss()
                        }
                    }
                    .disabled(selectedPreset == nil)
                }
            }
        }
        #if os(macOS)
        .frame(width: 400, height: 500)
        #endif
    }

    private func deletePreset(_ preset: SavedConfiguration) {
        if selectedPreset?.id == preset.id {
            selectedPreset = nil
        }
        modelContext.delete(preset)
    }

    private func deletePresets(at offsets: IndexSet) {
        for index in offsets {
            let preset = filteredPresets[index]
            deletePreset(preset)
        }
    }
}

/// A row view displaying preset information.
public struct PresetRow: View {
    public let preset: SavedConfiguration

    public init(preset: SavedConfiguration) {
        self.preset = preset
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(preset.name)
                .font(.headline)

            if !preset.tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(preset.tags.prefix(5), id: \.self) { tag in
                        Text(tag)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.secondary.opacity(0.2))
                            .clipShape(Capsule())
                    }
                    if preset.tags.count > 5 {
                        Text("+\(preset.tags.count - 5)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Text(preset.updatedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

#Preview("Menu") {
    PresetMenuView()
        .environmentObject(ConfigurationManager())
        .modelContainer(for: SavedConfiguration.self, inMemory: true)
        .frame(width: 200)
}

#Preview("Browser") {
    PresetBrowserView()
        .environmentObject(ConfigurationManager())
        .modelContainer(for: SavedConfiguration.self, inMemory: true)
}
