//
//  SearchableModelPicker.swift
//  DrawThingsKit
//
//  Created by euphoriacyberware-ai.
//  Copyright © 2025 euphoriacyberware-ai
//
//  Licensed under the MIT License.
//  See LICENSE file in the project root for license information.
//

import SwiftUI
import DrawThingsClient

/// A searchable model picker that displays models in a popover with filtering.
///
/// Much faster than SwiftUI's Picker/Menu for large model lists.
/// Groups models by source (Local, Official, Community) and supports search.
///
/// Example usage:
/// ```swift
/// SearchableModelPicker(
///     selection: $selectedModel,
///     models: modelsManager.baseModels,
///     label: "Model"
/// )
/// ```
public struct SearchableModelPicker: View {
    @Binding var selection: CheckpointModel?
    let models: [CheckpointModel]
    var label: String
    var placeholder: String
    var allowNone: Bool

    @State private var isPresented = false
    @State private var searchText = ""

    public init(
        selection: Binding<CheckpointModel?>,
        models: [CheckpointModel],
        label: String = "Model",
        placeholder: String = "Select a model...",
        allowNone: Bool = false
    ) {
        self._selection = selection
        self.models = models
        self.label = label
        self.placeholder = placeholder
        self.allowNone = allowNone
    }

    public var body: some View {
        HStack {
            Text(label)
            Spacer()
            Button {
                isPresented = true
            } label: {
                HStack(spacing: 4) {
                    if let selected = selection {
                        sourceIcon(for: selected.source)
                        Text(selected.name)
                            .lineLimit(1)
                    } else {
                        Text(placeholder)
                            .foregroundColor(.secondary)
                    }
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            ModelPickerPopover(
                selection: $selection,
                models: models,
                searchText: $searchText,
                allowNone: allowNone,
                isPresented: $isPresented
            )
        }
    }

    @ViewBuilder
    private func sourceIcon(for source: ModelSource) -> some View {
        switch source {
        case .official:
            Image(systemName: "checkmark.seal.fill")
                .foregroundColor(.blue)
                .font(.caption)
        case .community:
            Image(systemName: "person.2.fill")
                .foregroundColor(.purple)
                .font(.caption)
        case .local:
            EmptyView()
        }
    }
}

/// The popover content with search and grouped model list.
private struct ModelPickerPopover: View {
    @Binding var selection: CheckpointModel?
    let models: [CheckpointModel]
    @Binding var searchText: String
    let allowNone: Bool
    @Binding var isPresented: Bool

    private var filteredModels: [CheckpointModel] {
        if searchText.isEmpty {
            return models
        }
        let query = searchText.lowercased()
        return models.filter { model in
            model.name.lowercased().contains(query) ||
            model.file.lowercased().contains(query) ||
            (model.version?.lowercased().contains(query) ?? false)
        }
    }

    private var localModels: [CheckpointModel] {
        filteredModels.filter { $0.source == .local }
    }

    private var officialModels: [CheckpointModel] {
        filteredModels.filter { $0.source == .official }
    }

    private var communityModels: [CheckpointModel] {
        filteredModels.filter { $0.source == .community }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search models...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color.secondary.opacity(0.1))

            Divider()

            // Model list
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    // None option
                    if allowNone {
                        ModelRow(model: nil, isSelected: selection == nil) {
                            selection = nil
                            isPresented = false
                        }
                        Divider()
                    }

                    // Local models section
                    if !localModels.isEmpty {
                        sectionHeader("Local Models", icon: "internaldrive", count: localModels.count)
                        ForEach(localModels) { model in
                            ModelRow(model: model, isSelected: selection?.id == model.id) {
                                selection = model
                                isPresented = false
                            }
                        }
                    }

                    // Official models section
                    if !officialModels.isEmpty {
                        if !localModels.isEmpty {
                            Divider()
                                .padding(.vertical, 4)
                        }
                        sectionHeader("Official Models", icon: "checkmark.seal.fill", count: officialModels.count)
                        ForEach(officialModels) { model in
                            ModelRow(model: model, isSelected: selection?.id == model.id) {
                                selection = model
                                isPresented = false
                            }
                        }
                    }

                    // Community models section
                    if !communityModels.isEmpty {
                        if !localModels.isEmpty || !officialModels.isEmpty {
                            Divider()
                                .padding(.vertical, 4)
                        }
                        sectionHeader("Community Models", icon: "person.2.fill", count: communityModels.count)
                        ForEach(communityModels) { model in
                            ModelRow(model: model, isSelected: selection?.id == model.id) {
                                selection = model
                                isPresented = false
                            }
                        }
                    }

                    // Empty state
                    if filteredModels.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.title)
                                .foregroundColor(.secondary)
                            Text("No models found")
                                .foregroundColor(.secondary)
                            if !searchText.isEmpty {
                                Text("Try a different search term")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .frame(width: 320, height: 400)
    }

    @ViewBuilder
    private func sectionHeader(_ title: String, icon: String, count: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
            Text("(\(count))")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .foregroundColor(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.secondary.opacity(0.05))
    }
}

/// A single model row in the picker.
private struct ModelRow: View {
    let model: CheckpointModel?
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary.opacity(0.3))
                    .font(.body)

                if let model = model {
                    // Source icon
                    sourceIcon(for: model.source)

                    // Model info
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.name)
                            .font(.body)
                            .lineLimit(1)

                        if let version = model.version, !version.isEmpty {
                            Text(version)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    Text("None")
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
    }

    @ViewBuilder
    private func sourceIcon(for source: ModelSource) -> some View {
        switch source {
        case .official:
            Image(systemName: "checkmark.seal.fill")
                .foregroundColor(.blue)
                .font(.caption)
        case .community:
            Image(systemName: "person.2.fill")
                .foregroundColor(.purple)
                .font(.caption)
        case .local:
            Image(systemName: "internaldrive")
                .foregroundColor(.secondary)
                .font(.caption)
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("With Models") {
    let models: [CheckpointModel] = [
        .mock(name: "SDXL Base 1.0", file: "sdxl_base.safetensors", version: "sdxl", source: .local),
        .mock(name: "Juggernaut XL", file: "juggernaut.safetensors", version: "sdxl", source: .local),
        .mock(name: "DreamShaper XL", file: "dreamshaper.safetensors", version: "sdxl", source: .official),
        .mock(name: "Realistic Vision", file: "realistic.safetensors", version: "sd15", source: .official),
        .mock(name: "Anime Style", file: "anime.safetensors", version: "sdxl", source: .community),
        .mock(name: "Photorealistic", file: "photo.safetensors", version: "sdxl", source: .community),
    ]

    struct PreviewWrapper: View {
        @State var selection: CheckpointModel?

        let models: [CheckpointModel]

        var body: some View {
            Form {
                SearchableModelPicker(
                    selection: $selection,
                    models: models,
                    label: "Model"
                )
            }
            .formStyle(.grouped)
            .frame(width: 400, height: 150)
        }
    }

    return PreviewWrapper(selection: nil, models: models)
}

#Preview("With Selection") {
    let models: [CheckpointModel] = [
        .mock(name: "SDXL Base 1.0", file: "sdxl_base.safetensors", version: "sdxl", source: .local),
        .mock(name: "Juggernaut XL", file: "juggernaut.safetensors", version: "sdxl", source: .local),
    ]

    struct PreviewWrapper: View {
        @State var selection: CheckpointModel?

        let models: [CheckpointModel]

        var body: some View {
            Form {
                SearchableModelPicker(
                    selection: $selection,
                    models: models,
                    label: "Model"
                )
            }
            .formStyle(.grouped)
            .frame(width: 400, height: 150)
        }
    }

    return PreviewWrapper(selection: models.first, models: models)
}

#Preview("Allow None") {
    let models: [CheckpointModel] = [
        .mock(name: "SDXL Refiner", file: "refiner.safetensors", version: "sdxl-refiner", source: .local),
    ]

    struct PreviewWrapper: View {
        @State var selection: CheckpointModel?

        let models: [CheckpointModel]

        var body: some View {
            Form {
                SearchableModelPicker(
                    selection: $selection,
                    models: models,
                    label: "Refiner",
                    placeholder: "None",
                    allowNone: true
                )
            }
            .formStyle(.grouped)
            .frame(width: 400, height: 150)
        }
    }

    return PreviewWrapper(selection: nil, models: models)
}
#endif
