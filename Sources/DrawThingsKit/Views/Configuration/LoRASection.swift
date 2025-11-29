//
//  LoRASection.swift
//  DrawThingsKit
//
//  Composable LoRA selection section for configuration UI.
//

import SwiftUI
import DrawThingsClient

/// A composable section for managing LoRA models.
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
            DisclosureGroup("LoRAs (\(enabledCount)/\(selectedLoRAs.count))") {
                VStack(spacing: 12) {
                    // Add LoRA menu
                    Menu {
                        if modelsManager.compatibleLoRAs.isEmpty {
                            Text("No compatible LoRAs")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(modelsManager.compatibleLoRAs) { lora in
                                Button(lora.name) {
                                    addLoRA(lora)
                                }
                                .disabled(selectedLoRAs.contains(where: { $0.lora.id == lora.id }))
                            }
                        }
                    } label: {
                        Label("Add LoRA", systemImage: "plus.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(modelsManager.selectedCheckpoint == nil)
                    .help(modelsManager.selectedCheckpoint == nil ? "Select a checkpoint first" : "Add a LoRA model")

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

    public init(config: Binding<LoRAConfiguration>, onDelete: @escaping () -> Void) {
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
                    Text(config.lora.name)
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

            // Weight slider
            HStack {
                Text("Weight:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Slider(value: $config.weight, in: -1.5...2.5, step: 0.05)

                Text(String(format: "%.2f", config.weight))
                    .font(.caption)
                    .monospacedDigit()
                    .frame(width: 50, alignment: .trailing)
            }

            // Mode picker
            HStack {
                Text("Mode:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Picker("", selection: $config.mode) {
                    Text("All").tag(LoRAMode.all)
                    Text("Base").tag(LoRAMode.base)
                    Text("Refiner").tag(LoRAMode.refiner)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
        }
        .padding(.vertical, 4)
        .opacity(config.enabled ? 1.0 : 0.5)
    }
}

#Preview {
    let manager = ModelsManager()
    return Form {
        LoRASection(
            modelsManager: manager,
            selectedLoRAs: .constant([])
        )
    }
    .formStyle(.grouped)
    .frame(width: 400, height: 400)
}
