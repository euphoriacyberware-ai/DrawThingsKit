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

    public init(strength: Binding<Float>) {
        self._strength = strength
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
        }
    }
}

#Preview {
    Form {
        StrengthSection(strength: .constant(0.75))
    }
    .formStyle(.grouped)
    .frame(width: 400, height: 150)
}
