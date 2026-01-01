//
//  TeaCacheSection.swift
//  DrawThingsKit
//
//  Created by euphoriacyberware-ai.
//  Copyright © 2025 euphoriacyberware-ai
//
//  Licensed under the MIT License.
//  See LICENSE file in the project root for license information.
//

import SwiftUI

/// A section for TEA Cache parameters.
///
/// TEA Cache is a caching mechanism that can speed up generation
/// by reusing computations from previous steps.
///
/// Example usage:
/// ```swift
/// TeaCacheSection(
///     teaCache: $teaCache,
///     teaCacheStart: $teaCacheStart,
///     teaCacheEnd: $teaCacheEnd,
///     teaCacheThreshold: $teaCacheThreshold,
///     teaCacheMaxSkipSteps: $teaCacheMaxSkipSteps
/// )
/// ```
public struct TeaCacheSection: View {
    @Binding var teaCache: Bool
    @Binding var teaCacheStart: Int32
    @Binding var teaCacheEnd: Int32
    @Binding var teaCacheThreshold: Float
    @Binding var teaCacheMaxSkipSteps: Int32

    public init(
        teaCache: Binding<Bool>,
        teaCacheStart: Binding<Int32>,
        teaCacheEnd: Binding<Int32>,
        teaCacheThreshold: Binding<Float>,
        teaCacheMaxSkipSteps: Binding<Int32>
    ) {
        self._teaCache = teaCache
        self._teaCacheStart = teaCacheStart
        self._teaCacheEnd = teaCacheEnd
        self._teaCacheThreshold = teaCacheThreshold
        self._teaCacheMaxSkipSteps = teaCacheMaxSkipSteps
    }

    public var body: some View {
        Section {
            Toggle("Enable TEA Cache", isOn: $teaCache)
                .help("Enable TEA Cache for faster generation")

            if teaCache {
                ParameterSlider(
                    label: "Start Step",
                    value: Binding(
                        get: { Double(teaCacheStart) },
                        set: { teaCacheStart = Int32($0) }
                    ),
                    range: 0...50,
                    step: 1,
                    format: "%.0f"
                )

                ParameterSlider(
                    label: "End Step",
                    value: Binding(
                        get: { Double(teaCacheEnd) },
                        set: { teaCacheEnd = Int32($0) }
                    ),
                    range: -1...50,
                    step: 1,
                    format: "%.0f"
                )
                .help("Use -1 to run until the last step")

                ParameterSlider(
                    label: "Threshold",
                    value: Binding(
                        get: { Double(teaCacheThreshold) },
                        set: { teaCacheThreshold = Float($0) }
                    ),
                    range: 0...1,
                    step: 0.01,
                    format: "%.2f"
                )

                ParameterSlider(
                    label: "Max Skip",
                    value: Binding(
                        get: { Double(teaCacheMaxSkipSteps) },
                        set: { teaCacheMaxSkipSteps = Int32($0) }
                    ),
                    range: 1...10,
                    step: 1,
                    format: "%.0f"
                )
            }
        }
    }
}

#Preview {
    Form {
        TeaCacheSection(
            teaCache: .constant(true),
            teaCacheStart: .constant(5),
            teaCacheEnd: .constant(-1),
            teaCacheThreshold: .constant(0.06),
            teaCacheMaxSkipSteps: .constant(3)
        )
    }
    .formStyle(.grouped)
    .frame(width: 400, height: 300)
}
