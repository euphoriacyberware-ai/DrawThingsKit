//
//  LoRASection.swift
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

/// A composable section for managing LoRA models with a searchable picker.
///
/// Provides a simple list-based layout for adding and configuring LoRAs.
/// Each LoRA can be enabled/disabled and has an adjustable weight slider.
///
/// Example usage:
/// ```swift
/// LoRASection(
///     modelsManager: modelsManager,
///     selectedLoRAs: $selectedLoRAs
/// )
/// ```
public struct LoRASection: View {
    @ObservedObject var modelsManager: ModelsManager
    @Binding var selectedLoRAs: [LoRAConfiguration]

    public init(
        modelsManager: ModelsManager,
        selectedLoRAs: Binding<[LoRAConfiguration]>
    ) {
        self.modelsManager = modelsManager
        self._selectedLoRAs = selectedLoRAs
    }

    private var enabledCount: Int {
        selectedLoRAs.filter(\.enabled).count
    }

    public var body: some View {
        Section {
            VStack(spacing: 8) {
                // Add LoRA picker
                SearchableLoRAPicker(
                    loras: modelsManager.compatibleLoRAs,
                    selectedLoRAIds: Set(selectedLoRAs.map { $0.lora.id }),
                    onSelect: { lora in addLoRA(lora) },
                    disabled: modelsManager.selectedCheckpoint == nil,
                    disabledReason: modelsManager.selectedCheckpoint == nil ? "Select a checkpoint first" : nil
                )

                // LoRA list
                if selectedLoRAs.isEmpty {
                    Text("No LoRAs added")
                        .foregroundColor(.secondary)
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                } else {
                    ForEach($selectedLoRAs) { $loraConfig in
                        LoRARow(config: $loraConfig) {
                            removeLoRA(loraConfig)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    private func addLoRA(_ lora: LoRAModel) {
        guard !selectedLoRAs.contains(where: { $0.lora.id == lora.id }) else {
            return
        }
        selectedLoRAs.append(LoRAConfiguration(lora: lora))
    }

    private func removeLoRA(_ config: LoRAConfiguration) {
        selectedLoRAs.removeAll { $0.id == config.id }
    }
}

/// A row view for a single LoRA configuration.
public struct LoRARow: View {
    @Binding var config: LoRAConfiguration
    let onDelete: () -> Void

    public init(
        config: Binding<LoRAConfiguration>,
        onDelete: @escaping () -> Void
    ) {
        self._config = config
        self.onDelete = onDelete
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row with toggle and name
            HStack {
                Toggle("", isOn: $config.enabled)
                    .labelsHidden()

                VStack(alignment: .leading, spacing: 2) {
                    ModelLabelView(name: config.lora.name, source: config.lora.source)
                        .font(.body)

                    if let prefix = config.lora.prefix, !prefix.isEmpty {
                        Text(prefix)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .help("Remove LoRA")
            }

            // Weight slider (no step parameter to avoid tick marks, snaps on release)
            HStack {
                Text("Weight:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Slider(value: $config.weight, in: -1.5...2.5) { editing in
                    if !editing {
                        // Snap to 0.05 increments when released
                        config.weight = (config.weight / 0.05).rounded() * 0.05
                    }
                }

                Text(String(format: "%.2f", config.weight))
                    .font(.caption)
                    .monospacedDigit()
                    .frame(width: 50, alignment: .trailing)
            }
        }
        .padding(.vertical, 4)
        .opacity(config.enabled ? 1.0 : 0.5)
    }
}

// MARK: - Previews

#Preview("Empty State") {
    let manager = ModelsManager()
    return Form {
        LoRASection(
            modelsManager: manager,
            selectedLoRAs: .constant([])
        )
    }
    .formStyle(.grouped)
    .frame(width: 400, height: 300)
}

#if DEBUG
#Preview("With LoRAs") {
    let manager = ModelsManager.preview(withCheckpoints: [
        .mock(name: "SDXL Base", file: "sdxl_base.safetensors", version: "sdxl")
    ])

    let mockLoRAs: [LoRAConfiguration] = [
        LoRAConfiguration(
            lora: .mock(name: "Detail Tweaker XL", file: "detail_tweaker_xl.safetensors", version: "sdxl"),
            weight: 0.8,
            enabled: true
        ),
        LoRAConfiguration(
            lora: .mock(name: "Film Grain", file: "film_grain_lora.safetensors", version: "sdxl"),
            weight: 0.5,
            enabled: true
        ),
        LoRAConfiguration(
            lora: .mock(name: "Cinematic Look", file: "cinematic_lora.safetensors", version: "sdxl"),
            weight: 1.0,
            enabled: false
        )
    ]

    return Form {
        LoRASection(
            modelsManager: manager,
            selectedLoRAs: .constant(mockLoRAs)
        )
    }
    .formStyle(.grouped)
    .frame(width: 400, height: 400)
}

#Preview("Single LoRA") {
    let manager = ModelsManager.preview(withCheckpoints: [
        .mock(name: "SD 1.5", file: "sd15.safetensors", version: "sd15")
    ])

    let mockLoRAs: [LoRAConfiguration] = [
        LoRAConfiguration(
            lora: .mock(name: "Aesthetic Style", file: "aesthetic.safetensors", version: "sd15"),
            weight: 1.2,
            enabled: true
        )
    ]

    return Form {
        LoRASection(
            modelsManager: manager,
            selectedLoRAs: .constant(mockLoRAs)
        )
    }
    .formStyle(.grouped)
    .frame(width: 400, height: 250)
}
#endif
