//
//  SeedSection.swift
//  DrawThingsKit
//
//  Composable seed editor section for configuration UI.
//

import SwiftUI

/// A composable section for editing the generation seed.
///
/// Provides:
/// - Seed input field
/// - Random seed button (-1 means random)
/// - Optional seed mode selector (advanced)
///
/// Example usage:
/// ```swift
/// SeedSection(seed: $seed)
/// ```
public struct SeedSection: View {
    @Binding var seed: Int64
    @Binding var seedMode: Int32

    var showAdvanced: Bool

    public init(
        seed: Binding<Int64>,
        seedMode: Binding<Int32> = .constant(2),
        showAdvanced: Bool = false
    ) {
        self._seed = seed
        self._seedMode = seedMode
        self.showAdvanced = showAdvanced
    }

    public var body: some View {
        Section("Seed") {
            HStack {
                #if os(macOS)
                TextField("Seed", value: $seed, format: .number)
                    .textFieldStyle(.roundedBorder)
                #else
                TextField("Seed", value: $seed, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                #endif

                Spacer()

                Button("Random") {
                    seed = -1
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

//            if seed == -1 {
//                Text("A random seed will be generated")
//                    .font(.caption)
//                    .foregroundColor(.secondary)
//            }

            if showAdvanced {
                Picker("Seed Mode", selection: $seedMode) {
                    Text("NVIDIA").tag(Int32(0))
                    Text("Torch CPU").tag(Int32(1))
                    Text("Scale Alike").tag(Int32(2))
                }
                .pickerStyle(.segmented)
            }
        }
    }
}

#Preview {
    Form {
        SeedSection(seed: .constant(-1), showAdvanced: true)
        SeedSection(seed: .constant(12345))
    }
    .formStyle(.grouped)
    .frame(width: 400, height: 300)
}
