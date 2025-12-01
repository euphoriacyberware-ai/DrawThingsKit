//
//  BatchSection.swift
//  DrawThingsKit
//
//  Composable batch section for configuration UI.
//

import SwiftUI

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
        BatchSection(
            batchCount: .constant(2),
            batchSize: .constant(1)
        )
    }
    .formStyle(.grouped)
    .frame(width: 400, height: 200)
}
