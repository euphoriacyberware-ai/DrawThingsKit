//
//  StrengthSection.swift
//  DrawThingsKit
//
//  Composable strength section for image-to-image configuration UI.
//

import SwiftUI

/// A section for strength-related parameters (img2img).
public struct StrengthSection: View {
    @Binding var strength: Float
    @Binding var imageGuidanceScale: Float

    var showImageGuidance: Bool

    public init(
        strength: Binding<Float>,
        imageGuidanceScale: Binding<Float>,
        showImageGuidance: Bool = true
    ) {
        self._strength = strength
        self._imageGuidanceScale = imageGuidanceScale
        self.showImageGuidance = showImageGuidance
    }

    public var body: some View {
        Section("Image-to-Image") {
            ParameterSlider(
                label: "Strength",
                value: Binding(
                    get: { Double(strength) },
                    set: { strength = Float($0) }
                ),
                range: 0...1,
                step: 0.05,
                format: "%.2f"
            )

            if showImageGuidance {
                ParameterSlider(
                    label: "Image Guidance",
                    value: Binding(
                        get: { Double(imageGuidanceScale) },
                        set: { imageGuidanceScale = Float($0) }
                    ),
                    range: 0...10,
                    step: 0.1,
                    format: "%.1f"
                )
            }
        }
    }
}

#Preview {
    Form {
        StrengthSection(
            strength: .constant(0.75),
            imageGuidanceScale: .constant(1.5)
        )
    }
    .formStyle(.grouped)
    .frame(width: 400, height: 200)
}
