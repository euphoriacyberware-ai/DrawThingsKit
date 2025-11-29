//
//  DimensionsSection.swift
//  DrawThingsKit
//
//  Composable dimensions section for configuration UI.
//

import SwiftUI

/// A composable section for setting image dimensions.
///
/// Example usage:
/// ```swift
/// DimensionsSection(width: $width, height: $height)
/// ```
public struct DimensionsSection: View {
    @Binding var width: Int32
    @Binding var height: Int32

    var showPresets: Bool
    var minDimension: Int32
    var maxDimension: Int32
    var step: Int32

    public init(
        width: Binding<Int32>,
        height: Binding<Int32>,
        showPresets: Bool = true,
        minDimension: Int32 = 256,
        maxDimension: Int32 = 2048,
        step: Int32 = 64
    ) {
        self._width = width
        self._height = height
        self.showPresets = showPresets
        self.minDimension = minDimension
        self.maxDimension = maxDimension
        self.step = step
    }

    public var body: some View {
        Section("Dimensions") {
            // Dimension display
            HStack {
                Text("\(width) × \(height)")
                    .font(.headline)
                    .monospacedDigit()

                Spacer()

                Text(aspectRatioLabel)
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Swap button
                Button {
                    let temp = width
                    width = height
                    height = temp
                } label: {
                    Image(systemName: "arrow.left.arrow.right")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Swap width and height")
            }

            // Width slider
            HStack {
                Text("Width")
                    .frame(width: 50, alignment: .leading)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Slider(
                    value: Binding(
                        get: { Double(width) },
                        set: { width = Int32($0).roundedToStep(step) }
                    ),
                    in: Double(minDimension)...Double(maxDimension),
                    step: Double(step)
                )

                Text("\(width)")
                    .frame(width: 50, alignment: .trailing)
                    .monospacedDigit()
                    .font(.caption)
            }

            // Height slider
            HStack {
                Text("Height")
                    .frame(width: 50, alignment: .leading)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Slider(
                    value: Binding(
                        get: { Double(height) },
                        set: { height = Int32($0).roundedToStep(step) }
                    ),
                    in: Double(minDimension)...Double(maxDimension),
                    step: Double(step)
                )

                Text("\(height)")
                    .frame(width: 50, alignment: .trailing)
                    .monospacedDigit()
                    .font(.caption)
            }

            // Presets
            if showPresets {
                Divider()

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(DimensionPresets.common) { preset in
                            Button {
                                width = Int32(preset.width)
                                height = Int32(preset.height)
                            } label: {
                                VStack(spacing: 2) {
                                    Text(preset.name)
                                        .font(.caption2)
                                    Text("\(preset.width)×\(preset.height)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var aspectRatioLabel: String {
        let gcd = gcd(Int(width), Int(height))
        let w = Int(width) / gcd
        let h = Int(height) / gcd
        return "\(w):\(h)"
    }

    private func gcd(_ a: Int, _ b: Int) -> Int {
        b == 0 ? a : gcd(b, a % b)
    }
}

extension Int32 {
    fileprivate func roundedToStep(_ step: Int32) -> Int32 {
        (self / step) * step
    }
}

#Preview {
    Form {
        DimensionsSection(
            width: .constant(1024),
            height: .constant(768)
        )
    }
    .formStyle(.grouped)
    .frame(width: 400, height: 350)
}
