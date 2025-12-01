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
/// - Resolution Dependent Shift toggle
/// - Shift (hidden when Resolution Dependent Shift is enabled)
///
/// Example usage:
/// ```swift
/// ParametersSection(
///     steps: $steps,
///     guidanceScale: $guidanceScale,
///     resolutionDependentShift: $resolutionDependentShift,
///     shift: $shift
/// )
/// ```
public struct ParametersSection: View {
    @Binding var steps: Int32
    @Binding var guidanceScale: Float
    @Binding var resolutionDependentShift: Bool
    @Binding var shift: Float

    public init(
        steps: Binding<Int32>,
        guidanceScale: Binding<Float>,
        resolutionDependentShift: Binding<Bool>,
        shift: Binding<Float>
    ) {
        self._steps = steps
        self._guidanceScale = guidanceScale
        self._resolutionDependentShift = resolutionDependentShift
        self._shift = shift
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

            // Resolution Dependent Shift toggle
            Toggle("Resolution Dependent Shift", isOn: $resolutionDependentShift)
                .help("Automatically adjust shift based on image resolution")

            // Shift (only shown when Resolution Dependent Shift is disabled)
            if !resolutionDependentShift {
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
        }
    }
}

/// A reusable slider for numeric parameters.
///
/// The slider does not display tick marks (which become visually cluttered for large ranges).
/// Values are snapped to the specified step when the slider is released.
public struct ParameterSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: String

    @State private var isEditing = false

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

            // Slider without step parameter to avoid dense tick marks
            Slider(value: $value, in: range) { editing in
                isEditing = editing
                if !editing {
                    // Snap to step when user releases the slider
                    value = (value / step).rounded() * step
                }
            }

            Text(String(format: format, value))
                .frame(width: 50, alignment: .trailing)
                .monospacedDigit()
        }
    }
}

#Preview {
    Form {
        ParametersSection(
            steps: .constant(28),
            guidanceScale: .constant(3.5),
            resolutionDependentShift: .constant(true),
            shift: .constant(1.0)
        )
    }
    .formStyle(.grouped)
    .frame(width: 400, height: 250)
}
