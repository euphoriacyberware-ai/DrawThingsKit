//
//  ControlNetSection.swift
//  DrawThingsKit
//
//  Composable ControlNet selection section for configuration UI.
//

import SwiftUI
import DrawThingsClient

/// A composable section for managing ControlNet models.
///
/// Example usage:
/// ```swift
/// ControlNetSection(
///     modelsManager: modelsManager,
///     selectedControls: $selectedControls
/// )
/// ```
public struct ControlNetSection: View {
    @ObservedObject var modelsManager: ModelsManager
    @Binding var selectedControls: [ControlNetConfiguration]

    public init(
        modelsManager: ModelsManager,
        selectedControls: Binding<[ControlNetConfiguration]>
    ) {
        self.modelsManager = modelsManager
        self._selectedControls = selectedControls
    }

    private var enabledCount: Int {
        selectedControls.filter(\.enabled).count
    }

    public var body: some View {
        Section {
            DisclosureGroup("ControlNet (\(enabledCount)/\(selectedControls.count))") {
                VStack(spacing: 12) {
                    // Add ControlNet menu
                    Menu {
                        if modelsManager.compatibleControlNets.isEmpty {
                            Text("No compatible ControlNets")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(modelsManager.compatibleControlNets) { control in
                                Button {
                                    addControlNet(control)
                                } label: {
                                    ModelLabelView(name: control.name, source: control.source)
                                }
                                .disabled(selectedControls.contains(where: { $0.controlNet.id == control.id }))
                            }
                        }
                    } label: {
                        Label("Add ControlNet", systemImage: "plus.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(modelsManager.selectedCheckpoint == nil)
                    .help(modelsManager.selectedCheckpoint == nil ? "Select a checkpoint first" : "Add a ControlNet model")

                    // ControlNet list
                    if selectedControls.isEmpty {
                        Text("No ControlNets added")
                            .foregroundColor(.secondary)
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    } else {
                        ForEach($selectedControls) { $controlConfig in
                            ControlNetRow(config: $controlConfig) {
                                removeControlNet(controlConfig)
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }

    private func addControlNet(_ controlNet: ControlNetModel) {
        guard !selectedControls.contains(where: { $0.controlNet.id == controlNet.id }) else {
            return
        }
        selectedControls.append(ControlNetConfiguration(controlNet: controlNet))
    }

    private func removeControlNet(_ config: ControlNetConfiguration) {
        selectedControls.removeAll { $0.id == config.id }
    }
}

/// A row view for a single ControlNet configuration.
public struct ControlNetRow: View {
    @Binding var config: ControlNetConfiguration
    let onDelete: () -> Void

    public init(config: Binding<ControlNetConfiguration>, onDelete: @escaping () -> Void) {
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
                    ModelLabelView(name: config.controlNet.name, source: config.controlNet.source)
                        .font(.body)

                    if let prefix = config.controlNet.prefix, !prefix.isEmpty {
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
                .help("Remove ControlNet")
            }

            // Weight slider (no step to avoid tick marks, snaps on release)
            HStack {
                Text("Weight:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Slider(value: $config.weight, in: 0...2) { editing in
                    if !editing {
                        config.weight = (config.weight / 0.05).rounded() * 0.05
                    }
                }

                Text(String(format: "%.2f", config.weight))
                    .font(.caption)
                    .monospacedDigit()
                    .frame(width: 50, alignment: .trailing)
            }

            // Guidance range (no step to avoid tick marks, snaps on release)
            HStack {
                Text("Guidance:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(String(format: "%.0f%%", config.guidanceStart * 100))
                    .font(.caption2)
                    .monospacedDigit()
                    .frame(width: 35)

                Slider(value: $config.guidanceStart, in: 0...1) { editing in
                    if !editing {
                        config.guidanceStart = (config.guidanceStart / 0.05).rounded() * 0.05
                    }
                }
                Slider(value: $config.guidanceEnd, in: 0...1) { editing in
                    if !editing {
                        config.guidanceEnd = (config.guidanceEnd / 0.05).rounded() * 0.05
                    }
                }

                Text(String(format: "%.0f%%", config.guidanceEnd * 100))
                    .font(.caption2)
                    .monospacedDigit()
                    .frame(width: 35)
            }

            // Mode picker
            HStack {
                Text("Mode:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Picker("", selection: $config.controlMode) {
                    Text("Balanced").tag(ControlMode.balanced)
                    Text("Prompt").tag(ControlMode.prompt)
                    Text("Control").tag(ControlMode.control)
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
        ControlNetSection(
            modelsManager: manager,
            selectedControls: .constant([])
        )
    }
    .formStyle(.grouped)
    .frame(width: 400, height: 400)
}
