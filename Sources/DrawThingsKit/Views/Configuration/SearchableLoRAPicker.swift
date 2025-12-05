//
//  SearchableLoRAPicker.swift
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

/// A searchable LoRA picker that displays models in a popover with filtering.
///
/// Much faster than SwiftUI's Menu for large LoRA lists.
/// Groups LoRAs by source (Local, Official, Community) and supports search.
///
/// Example usage:
/// ```swift
/// SearchableLoRAPicker(
///     loras: modelsManager.compatibleLoRAs,
///     selectedLoRAIds: selectedLoRAs.map { $0.lora.id },
///     onSelect: { lora in addLoRA(lora) }
/// )
/// ```
public struct SearchableLoRAPicker: View {
    let loras: [LoRAModel]
    let selectedLoRAIds: Set<String>
    let onSelect: (LoRAModel) -> Void
    var disabled: Bool
    var disabledReason: String?

    @State private var isPresented = false
    @State private var searchText = ""

    public init(
        loras: [LoRAModel],
        selectedLoRAIds: Set<String>,
        onSelect: @escaping (LoRAModel) -> Void,
        disabled: Bool = false,
        disabledReason: String? = nil
    ) {
        self.loras = loras
        self.selectedLoRAIds = selectedLoRAIds
        self.onSelect = onSelect
        self.disabled = disabled
        self.disabledReason = disabledReason
    }

    public var body: some View {
        Button {
            isPresented = true
        } label: {
            Label("Add LoRA", systemImage: "plus.circle")
                .frame(maxWidth: .infinity)
        }
        .disabled(disabled)
        .help(disabledReason ?? "Add a LoRA model")
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            LoRAPickerPopover(
                loras: loras,
                selectedLoRAIds: selectedLoRAIds,
                searchText: $searchText,
                isPresented: $isPresented,
                onSelect: onSelect
            )
        }
    }
}

/// The popover content with search and grouped LoRA list.
private struct LoRAPickerPopover: View {
    let loras: [LoRAModel]
    let selectedLoRAIds: Set<String>
    @Binding var searchText: String
    @Binding var isPresented: Bool
    let onSelect: (LoRAModel) -> Void

    private var filteredLoRAs: [LoRAModel] {
        if searchText.isEmpty {
            return loras
        }
        let query = searchText.lowercased()
        return loras.filter { lora in
            lora.name.lowercased().contains(query) ||
            lora.file.lowercased().contains(query) ||
            (lora.version?.lowercased().contains(query) ?? false) ||
            (lora.prefix?.lowercased().contains(query) ?? false)
        }
    }

    private var localLoRAs: [LoRAModel] {
        filteredLoRAs.filter { $0.source == .local }
    }

    private var officialLoRAs: [LoRAModel] {
        filteredLoRAs.filter { $0.source == .official }
    }

    private var communityLoRAs: [LoRAModel] {
        filteredLoRAs.filter { $0.source == .community }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search LoRAs...", text: $searchText)
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

            // LoRA list
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    // Local LoRAs section
                    if !localLoRAs.isEmpty {
                        sectionHeader("Local LoRAs", icon: "internaldrive", count: localLoRAs.count)
                        ForEach(localLoRAs) { lora in
                            LoRAPickerRow(
                                lora: lora,
                                isSelected: selectedLoRAIds.contains(lora.id)
                            ) {
                                onSelect(lora)
                                isPresented = false
                            }
                        }
                    }

                    // Official LoRAs section
                    if !officialLoRAs.isEmpty {
                        if !localLoRAs.isEmpty {
                            Divider()
                                .padding(.vertical, 4)
                        }
                        sectionHeader("Official LoRAs", icon: "checkmark.seal.fill", count: officialLoRAs.count)
                        ForEach(officialLoRAs) { lora in
                            LoRAPickerRow(
                                lora: lora,
                                isSelected: selectedLoRAIds.contains(lora.id)
                            ) {
                                onSelect(lora)
                                isPresented = false
                            }
                        }
                    }

                    // Community LoRAs section
                    if !communityLoRAs.isEmpty {
                        if !localLoRAs.isEmpty || !officialLoRAs.isEmpty {
                            Divider()
                                .padding(.vertical, 4)
                        }
                        sectionHeader("Community LoRAs", icon: "person.2.fill", count: communityLoRAs.count)
                        ForEach(communityLoRAs) { lora in
                            LoRAPickerRow(
                                lora: lora,
                                isSelected: selectedLoRAIds.contains(lora.id)
                            ) {
                                onSelect(lora)
                                isPresented = false
                            }
                        }
                    }

                    // Empty state
                    if filteredLoRAs.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.title)
                                .foregroundColor(.secondary)
                            Text("No LoRAs found")
                                .foregroundColor(.secondary)
                            if !searchText.isEmpty {
                                Text("Try a different search term")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("No compatible LoRAs available")
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

/// A single LoRA row in the picker.
private struct LoRAPickerRow: View {
    let lora: LoRAModel
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                // Already added indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.body)
                } else {
                    Image(systemName: "plus.circle")
                        .foregroundColor(.accentColor)
                        .font(.body)
                }

                // Source icon
                sourceIcon(for: lora.source)

                // LoRA info
                VStack(alignment: .leading, spacing: 2) {
                    Text(lora.name)
                        .font(.body)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        if let version = lora.version, !version.isEmpty {
                            Text(version)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        if let prefix = lora.prefix, !prefix.isEmpty {
                            Text("trigger: \(prefix)")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isSelected ? Color.green.opacity(0.1) : Color.clear)
        .disabled(isSelected)
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
#Preview("With LoRAs") {
    let loras: [LoRAModel] = [
        .mock(name: "Detail Tweaker XL", file: "detail_tweaker_xl.safetensors", version: "sdxl", source: .local),
        .mock(name: "Film Grain", file: "film_grain.safetensors", version: "sdxl", source: .local),
        .mock(name: "SDXL Offset", file: "sdxl_offset.safetensors", version: "sdxl", source: .official),
        .mock(name: "LCM LoRA", file: "lcm_lora.safetensors", version: "sdxl", source: .official),
        .mock(name: "Anime Style", file: "anime_style.safetensors", version: "sdxl", source: .community),
        .mock(name: "Realistic Skin", file: "realistic_skin.safetensors", version: "sdxl", source: .community),
    ]

    return Form {
        SearchableLoRAPicker(
            loras: loras,
            selectedLoRAIds: ["detail_tweaker_xl.safetensors"],
            onSelect: { lora in print("Selected: \(lora.name)") }
        )
    }
    .formStyle(.grouped)
    .frame(width: 400, height: 150)
}

#Preview("Empty State") {
    Form {
        SearchableLoRAPicker(
            loras: [],
            selectedLoRAIds: [],
            onSelect: { _ in }
        )
    }
    .formStyle(.grouped)
    .frame(width: 400, height: 150)
}

#Preview("Disabled") {
    let loras: [LoRAModel] = [
        .mock(name: "Detail Tweaker XL", file: "detail_tweaker_xl.safetensors", version: "sdxl", source: .local),
    ]

    return Form {
        SearchableLoRAPicker(
            loras: loras,
            selectedLoRAIds: [],
            onSelect: { _ in },
            disabled: true,
            disabledReason: "Select a checkpoint first"
        )
    }
    .formStyle(.grouped)
    .frame(width: 400, height: 150)
}
#endif
