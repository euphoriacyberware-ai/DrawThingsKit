//
//  ParametersSection.swift
//  DrawThingsKit
//
//  Composable generation parameters section for configuration UI.
//

import SwiftUI
import DrawThingsClient

/// A composable section for core generation parameters.
///
/// Includes:
/// - Steps
/// - Guidance Scale (CFG)
/// - Sampler
/// - Shift
/// - Clip Skip
///
/// Example usage:
/// ```swift
/// ParametersSection(
///     steps: $steps,
///     guidanceScale: $guidanceScale,
///     sampler: $sampler,
///     shift: $shift,
///     clipSkip: $clipSkip
/// )
/// ```
public struct ParametersSection: View {
    @Binding var steps: Int32
    @Binding var guidanceScale: Float
    @Binding var sampler: SamplerType
    @Binding var shift: Float
    @Binding var clipSkip: Int32

    var showClipSkip: Bool
    var showShift: Bool

    public init(
        steps: Binding<Int32>,
        guidanceScale: Binding<Float>,
        sampler: Binding<SamplerType>,
        shift: Binding<Float>,
        clipSkip: Binding<Int32>,
        showClipSkip: Bool = true,
        showShift: Bool = true
    ) {
        self._steps = steps
        self._guidanceScale = guidanceScale
        self._sampler = sampler
        self._shift = shift
        self._clipSkip = clipSkip
        self.showClipSkip = showClipSkip
        self.showShift = showShift
    }

    public var body: some View {
        Section("Parameters") {
            // Steps
            ParameterSlider(
                label: "Steps",
                value: Binding(
                    get: { Double(steps) },
                    set: { steps = Int32($0) }
                ),
                range: 1...150,
                step: 1,
                format: "%.0f"
            )

            // Guidance Scale
            ParameterSlider(
                label: "CFG Scale",
                value: Binding(
                    get: { Double(guidanceScale) },
                    set: { guidanceScale = Float($0) }
                ),
                range: 0...30,
                step: 0.5,
                format: "%.1f"
            )

            // Sampler Picker
            Picker("Sampler", selection: $sampler) {
                ForEach(SamplerPresets.all) { info in
                    Text(info.name).tag(info.type)
                }
            }

            // Shift
            if showShift {
                ParameterSlider(
                    label: "Shift",
                    value: Binding(
                        get: { Double(shift) },
                        set: { shift = Float($0) }
                    ),
                    range: 0...10,
                    step: 0.1,
                    format: "%.2f"
                )
            }

            // Clip Skip
            if showClipSkip {
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
            }
        }
    }
}

/// A reusable slider for numeric parameters.
public struct ParameterSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: String

    public init(
        label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double = 1,
        format: String = "%.1f"
    ) {
        self.label = label
        self._value = value
        self.range = range
        self.step = step
        self.format = format
    }

    public var body: some View {
        HStack {
            Text(label)
                .frame(width: 80, alignment: .leading)
                .foregroundColor(.secondary)

            Slider(value: $value, in: range, step: step)

            Text(String(format: format, value))
                .frame(width: 50, alignment: .trailing)
                .monospacedDigit()
        }
    }
}

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

/// A section for batch parameters.
public struct BatchSection: View {
    @Binding var batchCount: Int32
    @Binding var batchSize: Int32

    public init(
        batchCount: Binding<Int32>,
        batchSize: Binding<Int32>
    ) {
        self._batchCount = batchCount
        self._batchSize = batchSize
    }

    public var body: some View {
        Section("Batch") {
            ParameterSlider(
                label: "Batch Count",
                value: Binding(
                    get: { Double(batchCount) },
                    set: { batchCount = Int32($0) }
                ),
                range: 1...10,
                step: 1,
                format: "%.0f"
            )

            ParameterSlider(
                label: "Batch Size",
                value: Binding(
                    get: { Double(batchSize) },
                    set: { batchSize = Int32($0) }
                ),
                range: 1...4,
                step: 1,
                format: "%.0f"
            )

            let total = Int(batchCount * batchSize)
            Text("Total: \(total) image\(total == 1 ? "" : "s")")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    Form {
        ParametersSection(
            steps: .constant(30),
            guidanceScale: .constant(7.0),
            sampler: .constant(.dpmpp2mkarras),
            shift: .constant(1.0),
            clipSkip: .constant(1)
        )

        StrengthSection(
            strength: .constant(0.75),
            imageGuidanceScale: .constant(1.5)
        )

        BatchSection(
            batchCount: .constant(1),
            batchSize: .constant(1)
        )
    }
    .formStyle(.grouped)
    .frame(width: 400, height: 600)
}
