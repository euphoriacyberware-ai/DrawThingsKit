//
//  ConfigurationEditorView.swift
//  DrawThingsKit
//
//  A reusable JSON configuration editor for Draw Things configurations.
//

import SwiftUI
import DrawThingsClient

#if os(macOS)

/// A reusable view for editing Draw Things configuration JSON.
///
/// This view provides:
/// - A JSON text editor with monospace font
/// - Toolbar with Paste, Copy, Format, Validate, and Clear buttons
/// - Real-time validation status display
/// - Automatic formatting on paste
///
/// Example usage:
/// ```swift
/// struct MyView: View {
///     @State private var configJSON = "{}"
///     @State private var showingEditor = false
///
///     var body: some View {
///         Button("Edit Configuration") {
///             showingEditor = true
///         }
///         .sheet(isPresented: $showingEditor) {
///             ConfigurationEditorView(
///                 json: $configJSON,
///                 title: "My Configuration"
///             )
///         }
///     }
/// }
/// ```
public struct ConfigurationEditorView: View {
    @Binding var json: String
    let title: String
    let onDismiss: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    @State private var jsonText: String = ""
    @State private var validationResult: DrawThingsConfiguration.ValidationResult?

    /// Create a configuration editor view.
    ///
    /// - Parameters:
    ///   - json: Binding to the JSON string to edit.
    ///   - title: Title to display in the header.
    ///   - onDismiss: Optional callback when the editor is dismissed.
    public init(
        json: Binding<String>,
        title: String = "Configuration",
        onDismiss: (() -> Void)? = nil
    ) {
        self._json = json
        self.title = title
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Toolbar
            toolbar
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // JSON Editor
            TextEditor(text: $jsonText)
                .font(.system(.body, design: .monospaced))
                .onChange(of: jsonText) { _, newValue in
                    validate(newValue)
                }

            Divider()

            // Help text
            footer
        }
        .frame(width: 700, height: 600)
        .onAppear {
            jsonText = json.isEmpty ? "{}" : DrawThingsConfiguration.formatJSON(json) ?? json
            validate(jsonText)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button("Cancel") {
                onDismiss?()
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Spacer()

            Text(title)
                .font(.headline)

            Spacer()

            Button("Apply") {
                applyConfiguration()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!(validationResult?.isValid ?? false))
        }
        .padding()
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            Button {
                pasteFromClipboard()
            } label: {
                Label("Paste", systemImage: "doc.on.clipboard")
            }
            .help("Paste JSON from clipboard")

            Button {
                copyToClipboard()
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .help("Copy JSON to clipboard")

            Divider()
                .frame(height: 20)

            Button {
                formatJSON()
            } label: {
                Label("Format", systemImage: "text.alignleft")
            }
            .help("Format JSON")

            Button {
                validate(jsonText)
            } label: {
                Label("Validate", systemImage: "checkmark.circle")
            }
            .help("Validate configuration")

            Divider()
                .frame(height: 20)

            Button {
                clearConfiguration()
            } label: {
                Label("Clear", systemImage: "trash")
            }
            .help("Clear configuration (use defaults)")

            Spacer()

            // Validation status
            validationStatus
        }
    }

    private var validationStatus: some View {
        Group {
            if let result = validationResult {
                if let error = result.error {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    .help(error)
                } else if result.isValid && !jsonText.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Valid configuration")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Text("Paste a Draw Things configuration JSON exported from the app, or edit manually.")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Actions

    private func pasteFromClipboard() {
        let pasteboard = NSPasteboard.general
        if let string = pasteboard.string(forType: .string) {
            jsonText = DrawThingsConfiguration.formatJSON(string) ?? string
            validate(jsonText)
        }
    }

    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(jsonText, forType: .string)
    }

    private func formatJSON() {
        if let formatted = DrawThingsConfiguration.formatJSON(jsonText) {
            jsonText = formatted
        }
    }

    private func validate(_ text: String) {
        validationResult = DrawThingsConfiguration.validateJSON(text)
    }

    private func clearConfiguration() {
        jsonText = "{}"
        validate(jsonText)
    }

    private func applyConfiguration() {
        let trimmed = jsonText.trimmingCharacters(in: .whitespacesAndNewlines)
        json = trimmed.isEmpty ? "{}" : trimmed
        onDismiss?()
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    ConfigurationEditorView(
        json: .constant("{}"),
        title: "Test Configuration"
    )
}

#endif
