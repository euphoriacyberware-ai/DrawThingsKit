//
//  ServerProfilesView.swift
//  DrawThingsKit
//
//  A view for managing server profiles and connections.
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
            List {
                ForEach(connectionManager.profiles) { profile in
                    ServerProfileRow(
                        profile: profile,
                        isActive: connectionManager.activeProfile?.id == profile.id,
                        isConnected: connectionManager.activeProfile?.id == profile.id &&
                                     connectionManager.connectionState.isConnected
                    )
                    .contextMenu {
                        profileContextMenu(for: profile)
                    }
                    .onTapGesture(count: 2) {
                        Task {
                            await connectionManager.connect(to: profile)
                        }
                    }
                }
            }
            .listStyle(.inset)

            Divider()

            // Toolbar
            HStack {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .help("Add Server")

                Spacer()

                if connectionManager.connectionState.isConnected {
                    Button("Disconnect") {
                        connectionManager.disconnect()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                } else if let activeProfile = connectionManager.activeProfile,
                          connectionManager.connectionState.isConnecting {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Connecting to \(activeProfile.name)...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if let selected = selectedProfile {
                    Button("Connect") {
                        Task {
                            await connectionManager.connect(to: selected)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            .padding(8)

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
                .padding(.bottom, 8)
            }
        }
        .sheet(isPresented: $showAddSheet) {
            ServerProfileEditorSheet(
                profile: nil,
                onSave: { profile in
                    connectionManager.addProfile(profile)
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
                }
                profileToDelete = nil
            }
        } message: {
            if let profile = profileToDelete {
                Text("Are you sure you want to delete \"\(profile.name)\"? This action cannot be undone.")
            }
        }
    }

    private var selectedProfile: ServerProfile? {
        // For now, use the first profile or the default
        connectionManager.defaultProfile ?? connectionManager.profiles.first
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
                Task {
                    await connectionManager.connect(to: profile)
                }
            }
        }

        Divider()

        Button("Edit...") {
            profileToEdit = profile
        }

        if !profile.isDefault {
            Button("Set as Default") {
                connectionManager.setDefault(profile)
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
