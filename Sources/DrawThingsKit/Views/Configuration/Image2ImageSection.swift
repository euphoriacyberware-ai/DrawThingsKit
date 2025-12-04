//
//  Image2ImageSection.swift
//  DrawThingsKit
//
//  Created by euphoriacyberware-ai.
//  Copyright © 2025 euphoriacyberware-ai
//
//  Licensed under the MIT License.
//  See LICENSE file in the project root for license information.
//

import SwiftUI

/// A section for strength-related parameters (img2img).
public struct Image2ImageSection: View {
    @Binding var strength: Float

    public init(strength: Binding<Float>) {
        self._strength = strength
    }

    public var body: some View {
        Section {
            ParameterSlider(
                label: "Image-to-Image",
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
        Image2ImageSection(strength: .constant(0.75))
    }
    .formStyle(.grouped)
    .frame(width: 400, height: 150)
}
