//
//  CausalInferenceSection.swift
//  DrawThingsKit
//
//  Composable causal inference section for configuration UI.
//

import SwiftUI

/// A section for Causal Inference parameters.
///
/// Causal inference generates frames using only preceding frames as context (CausVid).
/// This is available for video models specifically fine-tuned for causal generation.
///
/// Example usage:
/// ```swift
/// CausalInferenceSection(
///     causalInferenceEnabled: $causalInferenceEnabled,
///     causalInference: $causalInference,
///     causalInferencePad: $causalInferencePad
/// )
/// ```
public struct CausalInferenceSection: View {
    @Binding var causalInferenceEnabled: Bool
    @Binding var causalInference: Int32
    @Binding var causalInferencePad: Int32

    public init(
        causalInferenceEnabled: Binding<Bool>,
        causalInference: Binding<Int32>,
        causalInferencePad: Binding<Int32>
    ) {
        self._causalInferenceEnabled = causalInferenceEnabled
        self._causalInference = causalInference
        self._causalInferencePad = causalInferencePad
    }

    public var body: some View {
        Section("Causal Inference") {
            Toggle("Enable", isOn: $causalInferenceEnabled)
                .help("Generate frames using only preceding frames as context (CausVid)")

            if causalInferenceEnabled {
                ParameterSlider(
                    label: "Every N Frames",
                    value: Binding(get: { Double(causalInference) }, set: { causalInference = Int32($0) }),
                    range: 1...32,
                    step: 1,
                    format: "%.0f"
                )
                .help("Generate frames in chunks of N using all frames up to that point as context")

                ParameterSlider(
                    label: "Pad",
                    value: Binding(get: { Double(causalInferencePad) }, set: { causalInferencePad = Int32($0) }),
                    range: 0...32,
                    step: 1,
                    format: "%.0f"
                )
            }
        }
    }
}

#Preview {
    Form {
        CausalInferenceSection(
            causalInferenceEnabled: .constant(true),
            causalInference: .constant(1),
            causalInferencePad: .constant(32)
        )
    }
    .formStyle(.grouped)
    .frame(width: 400, height: 250)
}
