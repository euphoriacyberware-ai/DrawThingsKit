//
//  SaveConfigurationSheet.swift
//  DrawThingsKit
//
//  Created by euphoriacyberware-ai.
//  Copyright © 2025 euphoriacyberware-ai
//
//  Licensed under the MIT License.
//  See LICENSE file in the project root for license information.
//

import SwiftUI
import SwiftData

/// A sheet view for saving the current configuration as a preset.
///
/// Example usage:
/// ```swift
/// .sheet(isPresented: $showingSaveSheet) {
///     SaveConfigurationSheet()
/// }
/// ```
public struct SaveConfigurationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @EnvironmentObject private var configurationManager: ConfigurationManager

    @State private var name: String = ""
    @State private var tagsText: String = ""
    @State private var showingError = false
    @State private var errorMessage = ""

    public init() {}

    public var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Configuration name", text: $name)
                }

                Section {
                    TextField("Tags (comma separated)", text: $tagsText)
                } header: {
                    Text("Tags")
                } footer: {
                    Text("Enter tags separated by commas, e.g.: portrait, anime, high-detail")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Save Configuration")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveConfiguration()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
        #if os(macOS)
        .frame(width: 400, height: 250)
        #endif
    }

    private func saveConfiguration() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        let tags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        configurationManager.syncModelsToConfiguration()

        if let json = try? configurationManager.activeConfiguration.toJSON() {
            let preset = SavedConfiguration(name: trimmedName, tags: tags, configurationJSON: json)
            modelContext.insert(preset)
            dismiss()
        } else {
            errorMessage = "Failed to save configuration"
            showingError = true
        }
    }
}

#Preview {
    SaveConfigurationSheet()
        .environmentObject(ConfigurationManager())
        .modelContainer(for: SavedConfiguration.self, inMemory: true)
}
