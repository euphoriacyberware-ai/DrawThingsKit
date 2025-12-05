//
//  AdvancedSection.swift
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

/// A composable section for advanced generation settings.
///
/// Includes:
/// - Clip Skip
/// - Tiled Diffusion settings
/// - Tiled Decoding settings
/// - HiRes Fix settings
/// - Quality parameters (sharpness, aesthetic scores)
/// - Mask/Inpaint parameters
///
/// Example usage:
/// ```swift
/// AdvancedSection(
///     clipSkip: $clipSkip,
///     tiledDiffusion: $tiledDiffusion,
///     diffusionTileWidth: $diffusionTileWidth,
///     ...
/// )
/// ```
public struct AdvancedSection: View {
    // Clip Skip
    @Binding var clipSkip: Int32

    // Tiled Diffusion
    @Binding var tiledDiffusion: Bool
    @Binding var diffusionTileWidth: Int32
    @Binding var diffusionTileHeight: Int32
    @Binding var diffusionTileOverlap: Int32

    // Tiled Decoding
    @Binding var tiledDecoding: Bool
    @Binding var decodingTileWidth: Int32
    @Binding var decodingTileHeight: Int32
    @Binding var decodingTileOverlap: Int32

    // HiRes Fix
    @Binding var hiresFix: Bool
    @Binding var hiresFixWidth: Int32
    @Binding var hiresFixHeight: Int32
    @Binding var hiresFixStrength: Float

    // Quality
    @Binding var sharpness: Float
    @Binding var aestheticScore: Float
    @Binding var negativeAestheticScore: Float

    // Mask/Inpaint
    @Binding var maskBlur: Float
    @Binding var maskBlurOutset: Int32
    @Binding var preserveOriginalAfterInpaint: Bool

    public init(
        clipSkip: Binding<Int32>,
        tiledDiffusion: Binding<Bool>,
        diffusionTileWidth: Binding<Int32>,
        diffusionTileHeight: Binding<Int32>,
        diffusionTileOverlap: Binding<Int32>,
        tiledDecoding: Binding<Bool>,
        decodingTileWidth: Binding<Int32>,
        decodingTileHeight: Binding<Int32>,
        decodingTileOverlap: Binding<Int32>,
        hiresFix: Binding<Bool>,
        hiresFixWidth: Binding<Int32>,
        hiresFixHeight: Binding<Int32>,
        hiresFixStrength: Binding<Float>,
        sharpness: Binding<Float>,
        aestheticScore: Binding<Float>,
        negativeAestheticScore: Binding<Float>,
        maskBlur: Binding<Float>,
        maskBlurOutset: Binding<Int32>,
        preserveOriginalAfterInpaint: Binding<Bool>
    ) {
        self._clipSkip = clipSkip
        self._tiledDiffusion = tiledDiffusion
        self._diffusionTileWidth = diffusionTileWidth
        self._diffusionTileHeight = diffusionTileHeight
        self._diffusionTileOverlap = diffusionTileOverlap
        self._tiledDecoding = tiledDecoding
        self._decodingTileWidth = decodingTileWidth
        self._decodingTileHeight = decodingTileHeight
        self._decodingTileOverlap = decodingTileOverlap
        self._hiresFix = hiresFix
        self._hiresFixWidth = hiresFixWidth
        self._hiresFixHeight = hiresFixHeight
        self._hiresFixStrength = hiresFixStrength
        self._sharpness = sharpness
        self._aestheticScore = aestheticScore
        self._negativeAestheticScore = negativeAestheticScore
        self._maskBlur = maskBlur
        self._maskBlurOutset = maskBlurOutset
        self._preserveOriginalAfterInpaint = preserveOriginalAfterInpaint
    }

    public var body: some View {
        //DisclosureGroup("Advanced") {
            // Clip Skip
            ParameterSlider(
                label: "Clip Skip",
                value: Binding(
                    get: { Double(clipSkip) },
                    set: { clipSkip = Int32($0) }
                ),
                range: 1...4,
                step: 1,
                format: "%.0f"
            )

            // Tiled Diffusion
            TiledDiffusionSubSection(
                tiledDiffusion: $tiledDiffusion,
                tileWidth: $diffusionTileWidth,
                tileHeight: $diffusionTileHeight,
                tileOverlap: $diffusionTileOverlap
            )

            // Tiled Decoding
            TiledDecodingSubSection(
                tiledDecoding: $tiledDecoding,
                tileWidth: $decodingTileWidth,
                tileHeight: $decodingTileHeight,
                tileOverlap: $decodingTileOverlap
            )

            // HiRes Fix
            HiResFixSubSection(
                hiresFix: $hiresFix,
                hiresFixWidth: $hiresFixWidth,
                hiresFixHeight: $hiresFixHeight,
                hiresFixStrength: $hiresFixStrength
            )

            // Quality
            QualitySubSection(
                sharpness: $sharpness,
                aestheticScore: $aestheticScore,
                negativeAestheticScore: $negativeAestheticScore
            )

            // Inpaint
            InpaintSubSection(
                maskBlur: $maskBlur,
                maskBlurOutset: $maskBlurOutset,
                preserveOriginalAfterInpaint: $preserveOriginalAfterInpaint
            )
        }
    //}
}

// MARK: - Sub-Sections

public struct TiledDiffusionSubSection: View {
    @Binding var tiledDiffusion: Bool
    @Binding var tileWidth: Int32
    @Binding var tileHeight: Int32
    @Binding var tileOverlap: Int32

    public init(
        tiledDiffusion: Binding<Bool>,
        tileWidth: Binding<Int32>,
        tileHeight: Binding<Int32>,
        tileOverlap: Binding<Int32>
    ) {
        self._tiledDiffusion = tiledDiffusion
        self._tileWidth = tileWidth
        self._tileHeight = tileHeight
        self._tileOverlap = tileOverlap
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Tiled Diffusion", isOn: $tiledDiffusion)

            if tiledDiffusion {
                ParameterSlider(
                    label: "Tile Width",
                    value: Binding(get: { Double(tileWidth) }, set: { tileWidth = Int32($0) }),
                    range: 8...32,
                    step: 1,
                    format: "%.0f"
                )
                ParameterSlider(
                    label: "Tile Height",
                    value: Binding(get: { Double(tileHeight) }, set: { tileHeight = Int32($0) }),
                    range: 8...32,
                    step: 1,
                    format: "%.0f"
                )
                ParameterSlider(
                    label: "Overlap",
                    value: Binding(get: { Double(tileOverlap) }, set: { tileOverlap = Int32($0) }),
                    range: 0...8,
                    step: 1,
                    format: "%.0f"
                )
            }
        }
    }
}

public struct TiledDecodingSubSection: View {
    @Binding var tiledDecoding: Bool
    @Binding var tileWidth: Int32
    @Binding var tileHeight: Int32
    @Binding var tileOverlap: Int32

    public init(
        tiledDecoding: Binding<Bool>,
        tileWidth: Binding<Int32>,
        tileHeight: Binding<Int32>,
        tileOverlap: Binding<Int32>
    ) {
        self._tiledDecoding = tiledDecoding
        self._tileWidth = tileWidth
        self._tileHeight = tileHeight
        self._tileOverlap = tileOverlap
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Tiled Decoding", isOn: $tiledDecoding)

            if tiledDecoding {
                ParameterSlider(
                    label: "Tile Width",
                    value: Binding(get: { Double(tileWidth) }, set: { tileWidth = Int32($0) }),
                    range: 4...20,
                    step: 1,
                    format: "%.0f"
                )
                ParameterSlider(
                    label: "Tile Height",
                    value: Binding(get: { Double(tileHeight) }, set: { tileHeight = Int32($0) }),
                    range: 4...20,
                    step: 1,
                    format: "%.0f"
                )
                ParameterSlider(
                    label: "Overlap",
                    value: Binding(get: { Double(tileOverlap) }, set: { tileOverlap = Int32($0) }),
                    range: 0...8,
                    step: 1,
                    format: "%.0f"
                )
            }
        }
    }
}

public struct HiResFixSubSection: View {
    @Binding var hiresFix: Bool
    @Binding var hiresFixWidth: Int32
    @Binding var hiresFixHeight: Int32
    @Binding var hiresFixStrength: Float

    public init(
        hiresFix: Binding<Bool>,
        hiresFixWidth: Binding<Int32>,
        hiresFixHeight: Binding<Int32>,
        hiresFixStrength: Binding<Float>
    ) {
        self._hiresFix = hiresFix
        self._hiresFixWidth = hiresFixWidth
        self._hiresFixHeight = hiresFixHeight
        self._hiresFixStrength = hiresFixStrength
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("HiRes Fix", isOn: $hiresFix)

            if hiresFix {
                ParameterSlider(
                    label: "Width",
                    value: Binding(get: { Double(hiresFixWidth) }, set: { hiresFixWidth = Int32($0) }),
                    range: 256...2048,
                    step: 64,
                    format: "%.0f"
                )
                ParameterSlider(
                    label: "Height",
                    value: Binding(get: { Double(hiresFixHeight) }, set: { hiresFixHeight = Int32($0) }),
                    range: 256...2048,
                    step: 64,
                    format: "%.0f"
                )
                ParameterSlider(
                    label: "Strength",
                    value: Binding(get: { Double(hiresFixStrength) }, set: { hiresFixStrength = Float($0) }),
                    range: 0...1,
                    step: 0.05,
                    format: "%.2f"
                )
            }
        }
    }
}

public struct QualitySubSection: View {
    @Binding var sharpness: Float
    @Binding var aestheticScore: Float
    @Binding var negativeAestheticScore: Float

    public init(
        sharpness: Binding<Float>,
        aestheticScore: Binding<Float>,
        negativeAestheticScore: Binding<Float>
    ) {
        self._sharpness = sharpness
        self._aestheticScore = aestheticScore
        self._negativeAestheticScore = negativeAestheticScore
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ParameterSlider(
                label: "Sharpness",
                value: Binding(get: { Double(sharpness) }, set: { sharpness = Float($0) }),
                range: 0...2,
                step: 0.1,
                format: "%.1f"
            )
        }
    }
}

public struct InpaintSubSection: View {
    @Binding var maskBlur: Float
    @Binding var maskBlurOutset: Int32
    @Binding var preserveOriginalAfterInpaint: Bool

    public init(
        maskBlur: Binding<Float>,
        maskBlurOutset: Binding<Int32>,
        preserveOriginalAfterInpaint: Binding<Bool>
    ) {
        self._maskBlur = maskBlur
        self._maskBlurOutset = maskBlurOutset
        self._preserveOriginalAfterInpaint = preserveOriginalAfterInpaint
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Inpainting")
                .font(.caption)
                .foregroundColor(.secondary)

            ParameterSlider(
                label: "Mask Blur",
                value: Binding(get: { Double(maskBlur) }, set: { maskBlur = Float($0) }),
                range: 0...10,
                step: 0.5,
                format: "%.1f"
            )
            ParameterSlider(
                label: "Blur Outset",
                value: Binding(get: { Double(maskBlurOutset) }, set: { maskBlurOutset = Int32($0) }),
                range: -20...20,
                step: 1,
                format: "%.0f"
            )

            Toggle("Preserve Original", isOn: $preserveOriginalAfterInpaint)
        }
    }
}

#Preview {
    Form {
        AdvancedSection(
            clipSkip: .constant(1),
            tiledDiffusion: .constant(false),
            diffusionTileWidth: .constant(16),
            diffusionTileHeight: .constant(16),
            diffusionTileOverlap: .constant(2),
            tiledDecoding: .constant(false),
            decodingTileWidth: .constant(10),
            decodingTileHeight: .constant(10),
            decodingTileOverlap: .constant(2),
            hiresFix: .constant(false),
            hiresFixWidth: .constant(512),
            hiresFixHeight: .constant(512),
            hiresFixStrength: .constant(0.7),
            sharpness: .constant(0.0),
            aestheticScore: .constant(6.0),
            negativeAestheticScore: .constant(2.5),
            maskBlur: .constant(1.5),
            maskBlurOutset: .constant(0),
            preserveOriginalAfterInpaint: .constant(true)
        )
    }
    .formStyle(.grouped)
    .frame(width: 400, height: 600)
}
