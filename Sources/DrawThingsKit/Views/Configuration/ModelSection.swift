//
//  ModelSection.swift
//  DrawThingsKit
//
//  Composable model selection section for configuration UI.
//

import SwiftUI

/// A composable section for selecting base and refiner models.
///
/// Example usage:
/// ```swift
/// ModelSection(
///     modelsManager: modelsManager,
///     selectedCheckpoint: $selectedCheckpoint,
///     selectedRefiner: $selectedRefiner,
///     refinerStart: $refinerStart
/// )
/// ```
public struct ModelSection: View {
    @ObservedObject var modelsManager: ModelsManager

    @Binding var selectedCheckpoint: CheckpointModel?
    @Binding var selectedRefiner: CheckpointModel?
    @Binding var refinerStart: Float

    @State private var allowAnyRefiner: Bool = false

    public init(
        modelsManager: ModelsManager,
        selectedCheckpoint: Binding<CheckpointModel?>,
        selectedRefiner: Binding<CheckpointModel?>,
        refinerStart: Binding<Float>
    ) {
        self.modelsManager = modelsManager
        self._selectedCheckpoint = selectedCheckpoint
        self._selectedRefiner = selectedRefiner
        self._refinerStart = refinerStart
    }

    public var body: some View {
        Section("Models") {
            // Base Model Picker
            Picker("Model", selection: $selectedCheckpoint) {
                Text("Select a model...").tag(nil as CheckpointModel?)
                ForEach(modelsManager.baseModels) { checkpoint in
                    Text(checkpoint.name).tag(checkpoint as CheckpointModel?)
                }
            }
            .onChange(of: selectedCheckpoint) { _, newValue in
                modelsManager.selectedCheckpoint = newValue
            }

            // Refiner Model Picker
            Picker("Refiner", selection: $selectedRefiner) {
                Text("None").tag(nil as CheckpointModel?)

                // Show either all base models or just refiners
                let availableRefiners = allowAnyRefiner ? modelsManager.baseModels : modelsManager.refinerModels
                ForEach(availableRefiners) { refiner in
                    Text(refiner.name).tag(refiner as CheckpointModel?)
                }
            }
            .help(allowAnyRefiner ? "Any model can be selected as refiner" : "Only refiner-flagged models available")

            // Refiner Start Slider (only show if refiner is selected)
            if selectedRefiner != nil {
                HStack {
                    Text("Refiner Start")
                        .foregroundColor(.secondary)
                    Slider(value: $refinerStart, in: 0...1, step: 0.05)
                    Text(String(format: "%.0f%%", refinerStart * 100))
                        .frame(width: 50, alignment: .trailing)
                        .monospacedDigit()
                }
            }

            Toggle("MOE", isOn: $allowAnyRefiner)
                .help("Mixture of Experts - allows any model to be used as refiner")
        }
    }
}

/// A simplified model picker without the section wrapper.
public struct ModelPicker: View {
    @ObservedObject var modelsManager: ModelsManager
    @Binding var selectedCheckpoint: CheckpointModel?

    var label: String

    public init(
        modelsManager: ModelsManager,
        selectedCheckpoint: Binding<CheckpointModel?>,
        label: String = "Model"
    ) {
        self.modelsManager = modelsManager
        self._selectedCheckpoint = selectedCheckpoint
        self.label = label
    }

    public var body: some View {
        Picker(label, selection: $selectedCheckpoint) {
            Text("Select a model...").tag(nil as CheckpointModel?)
            ForEach(modelsManager.baseModels) { checkpoint in
                Text(checkpoint.name).tag(checkpoint as CheckpointModel?)
            }
        }
        .onChange(of: selectedCheckpoint) { _, newValue in
            modelsManager.selectedCheckpoint = newValue
        }
    }
}

#Preview {
    let manager = ModelsManager()
    return Form {
        ModelSection(
            modelsManager: manager,
            selectedCheckpoint: .constant(nil),
            selectedRefiner: .constant(nil),
            refinerStart: .constant(0.85)
        )
    }
    .formStyle(.grouped)
    .frame(width: 400, height: 300)
}
