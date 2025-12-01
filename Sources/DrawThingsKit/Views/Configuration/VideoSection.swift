//
//  VideoSection.swift
//  DrawThingsKit
//
//  Composable video configuration section for configuration UI.
//

import SwiftUI

/// A section for video generation parameters.
///
/// Example usage:
/// ```swift
/// VideoSection(numFrames: $numFrames)
/// ```
public struct VideoSection: View {
    @Binding var numFrames: Int32

    public init(numFrames: Binding<Int32>) {
        self._numFrames = numFrames
    }

    public var body: some View {
        Section("Video") {
            ParameterSlider(
                label: "Num Frames",
                value: Binding(
                    get: { Double(numFrames) },
                    set: { numFrames = Int32($0) }
                ),
                range: 1...128,
                step: 1,
                format: "%.0f"
            )
        }
    }
}

#Preview {
    Form {
        VideoSection(numFrames: .constant(14))
    }
    .formStyle(.grouped)
    .frame(width: 400, height: 150)
}
