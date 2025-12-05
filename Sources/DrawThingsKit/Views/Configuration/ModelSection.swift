//
//  ModelSection.swift
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
///     sampler: $sampler,
///     modelName: $configuration.model,
///     refinerName: $configuration.refinerModel
/// )
/// ```
public struct ModelSection: View {
    @ObservedObject var modelsManager: ModelsManager

    @Binding var selectedCheckpoint: CheckpointModel?
    @Binding var selectedRefiner: CheckpointModel?
    @Binding var refinerStart: Float
    @Binding var sampler: SamplerType
    @Binding var modelName: String
    @Binding var refinerName: String?

    /// Whether models are available from the server
    private var hasModels: Bool {
        !modelsManager.baseModels.isEmpty
    }

    public init(
        modelsManager: ModelsManager,
        selectedCheckpoint: Binding<CheckpointModel?>,
        selectedRefiner: Binding<CheckpointModel?>,
        refinerStart: Binding<Float>,
        sampler: Binding<SamplerType>,
        modelName: Binding<String>,
        refinerName: Binding<String?>
    ) {
        self.modelsManager = modelsManager
        self._selectedCheckpoint = selectedCheckpoint
        self._selectedRefiner = selectedRefiner
        self._refinerStart = refinerStart
        self._sampler = sampler
        self._modelName = modelName
        self._refinerName = refinerName
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            // Bridge Mode toggle - on = cloud models, off = local models
            Toggle("Bridge Mode", isOn: $modelsManager.bridgeMode)
                .help(modelsManager.bridgeMode
                    ? "Using cloud models (official + community)"
                    : "Using local models from connected server")

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
                    Slider(value: $refinerStart, in: 0...1) { editing in
                        if !editing {
                            // Snap to 5% increments
                            refinerStart = (refinerStart / 0.05).rounded() * 0.05
                        }
                    }
                    Text(String(format: "%.0f%%", refinerStart * 100))
                        .frame(width: 50, alignment: .trailing)
                        .monospacedDigit()
                }
            }

            // Sampler Picker
            Picker("Sampler", selection: $sampler) {
                ForEach(SamplerPresets.all) { info in
                    Text(info.name).tag(info.type)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        SearchableModelPicker(
            selection: $selectedCheckpoint,
            models: modelsManager.baseModels,
            label: "Model"
        )
        .onChange(of: selectedCheckpoint) { _, newValue in
            modelsManager.selectedCheckpoint = newValue
            modelName = newValue?.file ?? ""
        }
    }

    private var refinerPicker: some View {
        SearchableModelPicker(
            selection: $selectedRefiner,
            models: modelsManager.baseModels,
            label: "Refiner",
            placeholder: "None",
            allowNone: true
        )
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
        SearchableModelPicker(
            selection: $selectedCheckpoint,
            models: modelsManager.baseModels,
            label: label
        )
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
            sampler: .constant(.dpmpp2mkarras),
            modelName: .constant("sd_xl_base_1.0.safetensors"),
            refinerName: .constant(nil)
        )
    }
    .formStyle(.grouped)
    .frame(width: 400, height: 350)
}

#Preview("Not Connected - With Refiner") {
    // Shows refiner start slider when refiner name is set
    Form {
        ModelSection(
            modelsManager: ModelsManager(),
            selectedCheckpoint: .constant(nil),
            selectedRefiner: .constant(nil),
            refinerStart: .constant(0.85),
            sampler: .constant(.dpmpp2mkarras),
            modelName: .constant("sd_xl_base_1.0.safetensors"),
            refinerName: .constant("sd_xl_refiner_1.0.safetensors")
        )
    }
    .formStyle(.grouped)
    .frame(width: 400, height: 400)
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
            sampler: .constant(.dpmpp2mkarras),
            modelName: .constant(""),
            refinerName: .constant(nil)
        )
    }
    .formStyle(.grouped)
    .frame(width: 400, height: 350)
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
            sampler: .constant(.dpmpp2mkarras),
            modelName: .constant("sd_xl_base_1.0.safetensors"),
            refinerName: .constant("sd_xl_refiner_1.0.safetensors")
        )
    }
    .formStyle(.grouped)
    .frame(width: 400, height: 400)
}

#Preview("Connected - Video Model") {
    // Video models like Wan 2.2
    let wan22Model = CheckpointModel.mock(name: "Wan 2.2 14B I2V", file: "wan_v2.2_fun_14b_control_i2v.safetensors", version: "wan22")
    let manager = ModelsManager.preview(withCheckpoints: [
        wan22Model,
        .mock(name: "Wan 2.2 1.3B T2V", file: "wan_v2.2_1.3b_t2v.safetensors", version: "wan22"),
        .mock(name: "SDXL Base 1.0", file: "sd_xl_base_1.0.safetensors", version: "sdxl"),
    ])
    return Form {
        ModelSection(
            modelsManager: manager,
            selectedCheckpoint: .constant(wan22Model),
            selectedRefiner: .constant(nil),
            refinerStart: .constant(0.85),
            sampler: .constant(.dpmpp2mkarras),
            modelName: .constant("wan_v2.2_fun_14b_control_i2v.safetensors"),
            refinerName: .constant(nil)
        )
    }
    .formStyle(.grouped)
    .frame(width: 400, height: 400)
}

#Preview("Searchable Picker - Many Models") {
    // Test the searchable picker with a large list including all sources
    let manager = ModelsManager.preview(withCheckpoints: [
        // Local models
        .mock(name: "SDXL Base 1.0", file: "sd_xl_base_1.0.safetensors", version: "sdxl", source: .local),
        .mock(name: "SDXL Refiner 1.0", file: "sd_xl_refiner_1.0.safetensors", version: "sdxl-refiner", source: .local),
        .mock(name: "Juggernaut XL v9", file: "juggernaut_xl_v9.safetensors", version: "sdxl", source: .local),
        .mock(name: "RealVisXL V5", file: "realvisxl_v5.safetensors", version: "sdxl", source: .local),
        .mock(name: "Wan 2.2 14B I2V", file: "wan_v2.2_fun_14b_control_i2v.safetensors", version: "wan22", source: .local),
        // Official models
        .mock(name: "Stable Diffusion 3.5 Large", file: "sd3.5_large.safetensors", version: "sd3", source: .official),
        .mock(name: "Stable Diffusion 3.5 Medium", file: "sd3.5_medium.safetensors", version: "sd3", source: .official),
        .mock(name: "FLUX.1 Dev", file: "flux1-dev.safetensors", version: "flux", source: .official),
        .mock(name: "FLUX.1 Schnell", file: "flux1-schnell.safetensors", version: "flux", source: .official),
        // Community models
        .mock(name: "DreamShaper XL", file: "dreamshaper_xl.safetensors", version: "sdxl", source: .community),
        .mock(name: "Proteus v0.5", file: "proteus_v0.5.safetensors", version: "sdxl", source: .community),
        .mock(name: "NightVision XL", file: "nightvision_xl.safetensors", version: "sdxl", source: .community),
        .mock(name: "Animagine XL 3.1", file: "animagine_xl_3.1.safetensors", version: "sdxl", source: .community),
        .mock(name: "Pony Diffusion V6", file: "pony_v6.safetensors", version: "sdxl", source: .community),
    ])
    return Form {
        ModelSection(
            modelsManager: manager,
            selectedCheckpoint: .constant(nil),
            selectedRefiner: .constant(nil),
            refinerStart: .constant(0.85),
            sampler: .constant(.dpmpp2mkarras),
            modelName: .constant(""),
            refinerName: .constant(nil)
        )
    }
    .formStyle(.grouped)
    .frame(width: 400, height: 400)
}
#endif
