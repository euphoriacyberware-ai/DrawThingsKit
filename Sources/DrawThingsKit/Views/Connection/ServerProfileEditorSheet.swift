//
//  ServerProfileEditorSheet.swift
//  DrawThingsKit
//
//  Created by euphoriacyberware-ai.
//  Copyright © 2025 euphoriacyberware-ai
//
//  Licensed under the MIT License.
//  See LICENSE file in the project root for license information.
//

import SwiftUI

/// A sheet for creating or editing a server profile.
///
/// Example usage:
/// ```swift
/// .sheet(isPresented: $showEditor) {
///     ServerProfileEditorSheet(
///         profile: existingProfile,  // nil for new profile
///         onSave: { profile in
///             connectionManager.addProfile(profile)
///         },
///         onCancel: {
///             showEditor = false
///         }
///     )
/// }
/// ```
public struct ServerProfileEditorSheet: View {
    /// The profile being edited, or nil for a new profile.
    let existingProfile: ServerProfile?

    /// Called when the user saves the profile.
    let onSave: (ServerProfile) -> Void

    /// Called when the user cancels.
    let onCancel: () -> Void

    @State private var name: String = ""
    @State private var host: String = "localhost"
    @State private var port: String = "7859"
    @State private var useTLS: Bool = true
    @State private var isDefault: Bool = false

    @State private var showValidationError: Bool = false
    @State private var validationMessage: String = ""

    private var isEditing: Bool {
        existingProfile != nil
    }

    public init(
        profile: ServerProfile? = nil,
        onSave: @escaping (ServerProfile) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.existingProfile = profile
        self.onSave = onSave
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(isEditing ? "Edit Server" : "Add Server")
                    .font(.headline)
                Spacer()
            }
            .padding()

            Divider()

            // Form
            Form {
                Section {
                    TextField("Name", text: $name)
                        .textFieldStyle(.roundedBorder)

                    TextField("Host", text: $host)
                        .textFieldStyle(.roundedBorder)
                        #if os(macOS)
                        .disableAutocorrection(true)
                        #endif

                    TextField("Port", text: $port)
                        .textFieldStyle(.roundedBorder)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                }

                Section {
                    Toggle("Use TLS", isOn: $useTLS)

                    Toggle("Default Server", isOn: $isDefault)
                }

                if !isEditing {
                    Section {
                        Text("The server must be running Draw Things with API access enabled.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            // Buttons
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(isEditing ? "Save" : "Add") {
                    save()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
            .padding()
        }
        .frame(width: 400, height: 380)
        .onAppear {
            if let profile = existingProfile {
                name = profile.name
                host = profile.host
                port = String(profile.port)
                useTLS = profile.useTLS
                isDefault = profile.isDefault
            }
        }
        .alert("Invalid Configuration", isPresented: $showValidationError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(validationMessage)
        }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !host.trimmingCharacters(in: .whitespaces).isEmpty &&
        Int(port) != nil &&
        (1...65535).contains(Int(port) ?? 0)
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedHost = host.trimmingCharacters(in: .whitespaces)

        guard !trimmedName.isEmpty else {
            validationMessage = "Please enter a name for this server."
            showValidationError = true
            return
        }

        guard !trimmedHost.isEmpty else {
            validationMessage = "Please enter a host address."
            showValidationError = true
            return
        }

        guard let portNumber = Int(port), (1...65535).contains(portNumber) else {
            validationMessage = "Please enter a valid port number (1-65535)."
            showValidationError = true
            return
        }

        let profile = ServerProfile(
            id: existingProfile?.id ?? UUID(),
            name: trimmedName,
            host: trimmedHost,
            port: portNumber,
            useTLS: useTLS,
            isDefault: isDefault
        )

        onSave(profile)
    }
}

#Preview("New Profile") {
    ServerProfileEditorSheet(
        profile: nil,
        onSave: { _ in },
        onCancel: {}
    )
}

#Preview("Edit Profile") {
    ServerProfileEditorSheet(
        profile: .localhost,
        onSave: { _ in },
        onCancel: {}
    )
}
