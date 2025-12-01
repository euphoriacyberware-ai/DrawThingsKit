//
//  BatchSection.swift
//  DrawThingsKit
//
//  Composable batch section for configuration UI.
//

import SwiftUI

/// A section for batch parameters.
public struct BatchSection: View {
    @Binding var batchSize: Int32

    public init(batchSize: Binding<Int32>) {
        self._batchSize = batchSize
    }

    public var body: some View {
        Section("Batch") {
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
        }
    }
}

#Preview {
    Form {
        BatchSection(batchSize: .constant(1))
    }
    .formStyle(.grouped)
    .frame(width: 400, height: 150)
}
