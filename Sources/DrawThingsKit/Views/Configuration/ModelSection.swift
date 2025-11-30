//
//  ModelSection.swift
//  DrawThingsKit
//
//  Composable model selection section for configuration UI.
//

import SwiftUI

/// A composable section for selecting base and refiner models.
///
/// When connected to a server with available models, displays pickers.
/// When not connected (no models available), displays text fields for manual entry.
///
/// Example usage:
/// ```swift
/// ModelSection(
///     modelsManager: modelsManager,
///     selectedCheckpoint: $selectedCheckpoint,
///     selectedRefiner: $selectedRefiner,
///     refinerStart: $refinerStart,
///     modelName: $configuration.model,
///     refinerName: $configuration.refinerModel
/// )
/// ```
public struct ModelSection: View {
    @ObservedObject var modelsManager: ModelsManager

    @Binding var selectedCheckpoint: CheckpointModel?
    @Binding var selectedRefiner: CheckpointModel?
    @Binding var refinerStart: Float
    @Binding var modelName: String
    @Binding var refinerName: String?

    @State private var allowAnyRefiner: Bool = false

    /// Whether models are available from the server
    private var hasModels: Bool {
        !modelsManager.baseModels.isEmpty
    }

    public init(
        modelsManager: ModelsManager,
        selectedCheckpoint: Binding<CheckpointModel?>,
        selectedRefiner: Binding<CheckpointModel?>,
        refinerStart: Binding<Float>,
        modelName: Binding<String>,
        refinerName: Binding<String?>
    ) {
        self.modelsManager = modelsManager
        self._selectedCheckpoint = selectedCheckpoint
        self._selectedRefiner = selectedRefiner
        self._refinerStart = refinerStart
        self._modelName = modelName
        self._refinerName = refinerName
    }

    public var body: some View {
        Section("Models") {
            if hasModels {
                // Connected: show pickers
                modelPicker
                refinerPicker
            } else {
                // Not connected: show text fields
                modelTextField
                refinerTextField
            }

            // Refiner Start Slider (show if refiner is selected or refiner name is set)
            if selectedRefiner != nil || (refinerName != nil && !refinerName!.isEmpty) {
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
        .onChange(of: modelsManager.baseModels) { _, newModels in
            // When models become available, try to match text field values to actual models
            if !newModels.isEmpty {
                resolveSelectionsFromNames()
            }
        }
        .onAppear {
            // Also check on appear in case models are already loaded
            if hasModels {
                resolveSelectionsFromNames()
            }
        }
    }

    /// Try to match the model/refiner name strings to actual CheckpointModel selections
    private func resolveSelectionsFromNames() {
        // Match base model by filename
        if selectedCheckpoint == nil && !modelName.isEmpty {
            if let match = modelsManager.checkpoints.first(where: { $0.file == modelName }) {
                selectedCheckpoint = match
            }
        }

        // Match refiner by filename
        if selectedRefiner == nil, let refiner = refinerName, !refiner.isEmpty {
            if let match = modelsManager.checkpoints.first(where: { $0.file == refiner }) {
                selectedRefiner = match
            }
        }
    }

    // MARK: - Picker Views (when connected)

    private var modelPicker: some View {
        Picker("Model", selection: $selectedCheckpoint) {
            Text("Select a model...").tag(nil as CheckpointModel?)
            ForEach(modelsManager.baseModels) { checkpoint in
                Text(checkpoint.name).tag(checkpoint as CheckpointModel?)
            }
        }
        .onChange(of: selectedCheckpoint) { _, newValue in
            modelsManager.selectedCheckpoint = newValue
            modelName = newValue?.file ?? ""
        }
    }

    private var refinerPicker: some View {
        Picker("Refiner", selection: $selectedRefiner) {
            Text("None").tag(nil as CheckpointModel?)

            // Show either all base models or just refiners
            let availableRefiners = allowAnyRefiner ? modelsManager.baseModels : modelsManager.refinerModels
            ForEach(availableRefiners) { refiner in
                Text(refiner.name).tag(refiner as CheckpointModel?)
            }
        }
        .help(allowAnyRefiner ? "Any model can be selected as refiner" : "Only refiner-flagged models available")
        .onChange(of: selectedRefiner) { _, newValue in
            refinerName = newValue?.file
        }
    }

    // MARK: - Text Field Views (when not connected)

    private var modelTextField: some View {
        HStack {
            Text("Model")
            Spacer()
            TextField("", text: $modelName)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 200)
                #if os(iOS)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                #endif
        }
    }

    private var refinerTextField: some View {
        HStack {
            Text("Refiner")
            Spacer()
            TextField("", text: Binding(
                get: { refinerName ?? "" },
                set: { refinerName = $0.isEmpty ? nil : $0 }
            ))
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: 200)
            #if os(iOS)
            .autocapitalization(.none)
            .disableAutocorrection(true)
            #endif
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

#Preview("Not Connected - Text Fields") {
    // Empty ModelsManager = text fields shown
    Form {
        ModelSection(
            modelsManager: ModelsManager(),
            selectedCheckpoint: .constant(nil),
            selectedRefiner: .constant(nil),
            refinerStart: .constant(0.85),
            modelName: .constant("sd_xl_base_1.0.safetensors"),
            refinerName: .constant(nil)
        )
    }
    .formStyle(.grouped)
    .frame(width: 400, height: 300)
}

#Preview("Not Connected - With Refiner") {
    // Shows refiner start slider when refiner name is set
    Form {
        ModelSection(
            modelsManager: ModelsManager(),
            selectedCheckpoint: .constant(nil),
            selectedRefiner: .constant(nil),
            refinerStart: .constant(0.85),
            modelName: .constant("sd_xl_base_1.0.safetensors"),
            refinerName: .constant("sd_xl_refiner_1.0.safetensors")
        )
    }
    .formStyle(.grouped)
    .frame(width: 400, height: 350)
}

#if DEBUG
#Preview("Connected - With Models") {
    // ModelsManager with mock models = pickers shown
    let manager = ModelsManager.preview(withCheckpoints: [
        .mock(name: "SDXL Base 1.0", file: "sd_xl_base_1.0.safetensors", version: "sdxl"),
        .mock(name: "SDXL Refiner 1.0", file: "sd_xl_refiner_1.0.safetensors", version: "sdxl-refiner"),
        .mock(name: "Juggernaut XL", file: "juggernaut_xl.safetensors", version: "sdxl"),
        .mock(name: "DreamShaper XL", file: "dreamshaper_xl.safetensors", version: "sdxl"),
    ])
    return Form {
        ModelSection(
            modelsManager: manager,
            selectedCheckpoint: .constant(nil),
            selectedRefiner: .constant(nil),
            refinerStart: .constant(0.85),
            modelName: .constant(""),
            refinerName: .constant(nil)
        )
    }
    .formStyle(.grouped)
    .frame(width: 400, height: 300)
}

#Preview("Connected - With Refiner Selected") {
    let refiner = CheckpointModel.mock(name: "SDXL Refiner 1.0", file: "sd_xl_refiner_1.0.safetensors", version: "sdxl-refiner")
    let manager = ModelsManager.preview(withCheckpoints: [
        .mock(name: "SDXL Base 1.0", file: "sd_xl_base_1.0.safetensors", version: "sdxl"),
        refiner,
        .mock(name: "Juggernaut XL", file: "juggernaut_xl.safetensors", version: "sdxl"),
    ])
    return Form {
        ModelSection(
            modelsManager: manager,
            selectedCheckpoint: .constant(manager.baseModels.first),
            selectedRefiner: .constant(refiner),
            refinerStart: .constant(0.85),
            modelName: .constant("sd_xl_base_1.0.safetensors"),
            refinerName: .constant("sd_xl_refiner_1.0.safetensors")
        )
    }
    .formStyle(.grouped)
    .frame(width: 400, height: 350)
}
#endif
