//
//  ConfigurationActionsView.swift
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
import DrawThingsClient

/// A view providing configuration management actions: Copy, Paste, Save, Presets, and JSON editor.
///
/// This view provides two rows of buttons:
/// - Row 1: Copy, Paste, Save (icon-only buttons)
/// - Row 2: Presets dropdown, JSON editor button
///
/// Example usage:
/// ```swift
/// struct MyView: View {
///     @EnvironmentObject var configurationManager: ConfigurationManager
///     @EnvironmentObject var connectionManager: ConnectionManager
///
///     var body: some View {
///         VStack {
///             ConfigurationActionsView()
///             // ... other content
///         }
///     }
/// }
/// ```
public struct ConfigurationActionsView: View {
    @EnvironmentObject private var configurationManager: ConfigurationManager

    @State private var showingSaveSheet = false
    @State private var showingPresetBrowser = false
    @State private var showingJSONEditor = false
    @State private var pasteError = false
    @State private var editorJSON: String = "{}"

    /// Optional callback when paste fails
    public var onPasteError: (() -> Void)?

    /// Optional callback when a preset is loaded (receives the ModelsManager to resolve models)
    public var onPresetLoaded: ((ModelsManager) -> Void)?

    /// Optional ModelsManager for resolving models after loading
    private var modelsManager: ModelsManager?

    public init(
        modelsManager: ModelsManager? = nil,
        onPasteError: (() -> Void)? = nil,
        onPresetLoaded: ((ModelsManager) -> Void)? = nil
    ) {
        self.modelsManager = modelsManager
        self.onPasteError = onPasteError
        self.onPresetLoaded = onPresetLoaded
    }

    public var body: some View {
        VStack(spacing: 12) {
            // Copy, Paste, Save row
            HStack(spacing: 6) {
                Button {
                    configurationManager.copyToClipboard()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .labelStyle(.iconOnly)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .help("Copy configuration to clipboard")

                Button {
                    if !configurationManager.pasteFromClipboard() {
                        pasteError = true
                        onPasteError?()
                    } else if let manager = modelsManager {
                        configurationManager.resolveModels(from: manager)
                    }
                } label: {
                    Label("Paste", systemImage: "doc.on.clipboard")
                        .labelStyle(.iconOnly)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .help("Paste configuration from clipboard")

                Button {
                    showingSaveSheet = true
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                        .labelStyle(.iconOnly)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .help("Save configuration as preset")
            }

            // Presets and JSON editor row
            HStack(spacing: 6) {
                PresetMenuView(modelsManager: modelsManager)
                    .buttonStyle(.bordered)
                    .help("Load saved preset")

                Button {
                    configurationManager.syncModelsToConfiguration()
                    editorJSON = (try? configurationManager.activeConfiguration.toJSON()) ?? "{}"
                    showingJSONEditor = true
                } label: {
                    Label("JSON", systemImage: "curlybraces")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .help("Edit configuration JSON")
            }
        }
        .sheet(isPresented: $showingSaveSheet) {
            SaveConfigurationSheet()
        }
        .sheet(isPresented: $showingPresetBrowser) {
            PresetBrowserView()
        }
        .sheet(isPresented: $showingJSONEditor) {
            ConfigurationEditorView(
                json: $editorJSON,
                title: "Configuration JSON",
                onDismiss: {
                    // Merge JSON into existing configuration (only updates fields present in JSON)
                    try? configurationManager.activeConfiguration.mergeJSON(editorJSON)
                    if let manager = modelsManager {
                        configurationManager.resolveModels(from: manager)
                    }
                }
            )
        }
        .alert("Paste Error", isPresented: $pasteError) {
            Button("OK") { }
        } message: {
            Text("Clipboard does not contain a valid configuration")
        }
    }
}

/// A compact version of ConfigurationActionsView with all buttons in a single row.
public struct ConfigurationActionsCompactView: View {
    @EnvironmentObject private var configurationManager: ConfigurationManager

    @State private var showingSaveSheet = false
    @State private var showingJSONEditor = false
    @State private var pasteError = false
    @State private var editorJSON: String = "{}"

    private var modelsManager: ModelsManager?

    public init(modelsManager: ModelsManager? = nil) {
        self.modelsManager = modelsManager
    }

    public var body: some View {
        HStack(spacing: 6) {
            Button {
                configurationManager.copyToClipboard()
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.bordered)
            .help("Copy configuration to clipboard")

            Button {
                if !configurationManager.pasteFromClipboard() {
                    pasteError = true
                } else if let manager = modelsManager {
                    configurationManager.resolveModels(from: manager)
                }
            } label: {
                Label("Paste", systemImage: "doc.on.clipboard")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.bordered)
            .help("Paste configuration from clipboard")

            Button {
                showingSaveSheet = true
            } label: {
                Label("Save", systemImage: "square.and.arrow.down")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.bordered)
            .help("Save configuration as preset")

            PresetMenuView(modelsManager: modelsManager)
                .buttonStyle(.bordered)
                .help("Load saved preset")

            Button {
                configurationManager.syncModelsToConfiguration()
                editorJSON = (try? configurationManager.activeConfiguration.toJSON()) ?? "{}"
                showingJSONEditor = true
            } label: {
                Label("JSON", systemImage: "curlybraces")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.bordered)
            .help("Edit configuration JSON")
        }
        .sheet(isPresented: $showingSaveSheet) {
            SaveConfigurationSheet()
        }
        .sheet(isPresented: $showingJSONEditor) {
            ConfigurationEditorView(
                json: $editorJSON,
                title: "Configuration JSON",
                onDismiss: {
                    // Merge JSON into existing configuration (only updates fields present in JSON)
                    try? configurationManager.activeConfiguration.mergeJSON(editorJSON)
                    if let manager = modelsManager {
                        configurationManager.resolveModels(from: manager)
                    }
                }
            )
        }
        .alert("Paste Error", isPresented: $pasteError) {
            Button("OK") { }
        } message: {
            Text("Clipboard does not contain a valid configuration")
        }
    }
}

#Preview("Standard") {
    ConfigurationActionsView()
        .environmentObject(ConfigurationManager())
        .modelContainer(for: SavedConfiguration.self, inMemory: true)
        .padding()
        .frame(width: 280)
}

#Preview("Compact") {
    ConfigurationActionsCompactView()
        .environmentObject(ConfigurationManager())
        .modelContainer(for: SavedConfiguration.self, inMemory: true)
        .padding()
}
