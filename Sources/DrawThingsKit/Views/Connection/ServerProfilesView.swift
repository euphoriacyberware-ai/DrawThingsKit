//
//  ServerProfilesView.swift
//  DrawThingsKit
//
//  Created by euphoriacyberware-ai.
//  Copyright © 2025 euphoriacyberware-ai
//
//  Licensed under the MIT License.
//  See LICENSE file in the project root for license information.
//

import SwiftUI

/// A view for managing server profiles and connections.
///
/// Displays a list of saved server profiles with options to:
/// - Connect/disconnect from servers
/// - Add, edit, and delete profiles
/// - Set a default profile
///
/// Example usage:
/// ```swift
/// ServerProfilesView(connectionManager: connectionManager)
/// ```
public struct ServerProfilesView: View {
    @ObservedObject var connectionManager: ConnectionManager

    @State private var selectedProfileID: UUID?
    @State private var showAddSheet = false
    @State private var profileToEdit: ServerProfile?
    @State private var profileToDelete: ServerProfile?
    @State private var showDeleteConfirmation = false

    public init(connectionManager: ConnectionManager) {
        self.connectionManager = connectionManager
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Profile list
            List(selection: $selectedProfileID) {
                ForEach(connectionManager.profiles) { profile in
                    ServerProfileRow(
                        profile: profile,
                        isActive: connectionManager.activeProfile?.id == profile.id,
                        isConnected: connectionManager.activeProfile?.id == profile.id &&
                                     connectionManager.connectionState.isConnected,
                        isSelected: selectedProfileID == profile.id
                    )
                    .tag(profile.id)
                    .contextMenu {
                        profileContextMenu(for: profile)
                    }
                    .onTapGesture(count: 2) {
                        connectToProfile(profile)
                    }
                    .onTapGesture(count: 1) {
                        selectedProfileID = profile.id
                    }
                }
            }
            #if os(macOS)
            .listStyle(.inset(alternatesRowBackgrounds: true))
            #else
            .listStyle(.inset)
            #endif

            Divider()

            // Toolbar
            toolbarView
        }
        .sheet(isPresented: $showAddSheet) {
            ServerProfileEditorSheet(
                profile: nil,
                onSave: { profile in
                    connectionManager.addProfile(profile)
                    selectedProfileID = profile.id
                    showAddSheet = false
                },
                onCancel: {
                    showAddSheet = false
                }
            )
        }
        .sheet(item: $profileToEdit) { profile in
            ServerProfileEditorSheet(
                profile: profile,
                onSave: { updatedProfile in
                    connectionManager.updateProfile(updatedProfile)
                    profileToEdit = nil
                },
                onCancel: {
                    profileToEdit = nil
                }
            )
        }
        .alert("Delete Server?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                profileToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let profile = profileToDelete {
                    connectionManager.deleteProfile(profile)
                    if selectedProfileID == profile.id {
                        selectedProfileID = nil
                    }
                }
                profileToDelete = nil
            }
        } message: {
            if let profile = profileToDelete {
                Text("Are you sure you want to delete \"\(profile.name)\"? This action cannot be undone.")
            }
        }
        .onAppear {
            // Select the default or first profile on appear if nothing selected
            if selectedProfileID == nil {
                selectedProfileID = connectionManager.defaultProfile?.id ?? connectionManager.profiles.first?.id
            }
        }
    }

    private var selectedProfile: ServerProfile? {
        guard let id = selectedProfileID else { return nil }
        return connectionManager.profiles.first { $0.id == id }
    }

    private var toolbarView: some View {
        VStack(spacing: 8) {
            // Main toolbar row
            HStack {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .help("Add Server")

                Button {
                    if let profile = selectedProfile {
                        profileToEdit = profile
                    }
                } label: {
                    Image(systemName: "pencil")
                }
                .help("Edit Server")
                .disabled(selectedProfile == nil)

                Button {
                    if let profile = selectedProfile {
                        profileToDelete = profile
                        showDeleteConfirmation = true
                    }
                } label: {
                    Image(systemName: "minus")
                }
                .help("Delete Server")
                .disabled(selectedProfile == nil)

                Divider()
                    .frame(height: 16)

                Button {
                    if let profile = selectedProfile, !profile.isDefault {
                        connectionManager.setDefault(profile)
                    }
                } label: {
                    Image(systemName: "star")
                }
                .help("Set as Default")
                .disabled(selectedProfile == nil || selectedProfile?.isDefault == true)

                Spacer()

                connectionButton
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)

            // Error message
            if let error = connectionManager.connectionState.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 8)
            }
        }
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var connectionButton: some View {
        if connectionManager.connectionState.isConnected {
            Button("Disconnect") {
                connectionManager.disconnect()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        } else if connectionManager.connectionState.isConnecting {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Connecting...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        } else if let profile = selectedProfile {
            Button("Connect") {
                connectToProfile(profile)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        } else {
            Button("Connect") { }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(true)
        }
    }

    private func connectToProfile(_ profile: ServerProfile) {
        Task {
            await connectionManager.connect(to: profile)
        }
    }

    @ViewBuilder
    private func profileContextMenu(for profile: ServerProfile) -> some View {
        if connectionManager.activeProfile?.id == profile.id &&
           connectionManager.connectionState.isConnected {
            Button("Disconnect") {
                connectionManager.disconnect()
            }
        } else {
            Button("Connect") {
                connectToProfile(profile)
            }
        }

        Divider()

        Button("Edit...") {
            profileToEdit = profile
        }

        if !profile.isDefault {
            Button {
                connectionManager.setDefault(profile)
            } label: {
                Label("Set as Default", systemImage: "star")
            }
        }

        Divider()

        Button("Delete", role: .destructive) {
            profileToDelete = profile
            showDeleteConfirmation = true
        }
    }
}

/// A compact dropdown for quickly selecting and connecting to a server.
///
/// Useful for toolbars or compact UIs where a full profile list isn't needed.
public struct ServerProfilePicker: View {
    @ObservedObject var connectionManager: ConnectionManager

    public init(connectionManager: ConnectionManager) {
        self.connectionManager = connectionManager
    }

    public var body: some View {
        Menu {
            ForEach(connectionManager.profiles) { profile in
                Button {
                    Task {
                        await connectionManager.connect(to: profile)
                    }
                } label: {
                    HStack {
                        Text(profile.name)
                        if profile.isDefault {
                            Image(systemName: "star.fill")
                        }
                        if connectionManager.activeProfile?.id == profile.id &&
                           connectionManager.connectionState.isConnected {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }

            if connectionManager.connectionState.isConnected {
                Divider()
                Button("Disconnect") {
                    connectionManager.disconnect()
                }
            }
        } label: {
            HStack(spacing: 4) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)

                if let profile = connectionManager.activeProfile,
                   connectionManager.connectionState.isConnected {
                    Text(profile.name)
                } else if connectionManager.connectionState.isConnecting {
                    Text("Connecting...")
                } else {
                    Text("Connect...")
                }

                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .font(.caption)
        }
    }

    private var statusColor: Color {
        switch connectionManager.connectionState {
        case .disconnected: return .gray
        case .connecting: return .yellow
        case .connected: return .green
        case .error: return .red
        }
    }
}

#Preview("Profiles View") {
    ServerProfilesView(connectionManager: ConnectionManager())
        .frame(width: 300, height: 400)
}

#Preview("Profile Picker") {
    ServerProfilePicker(connectionManager: ConnectionManager())
        .padding()
}
