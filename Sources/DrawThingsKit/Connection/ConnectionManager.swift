//
//  ConnectionManager.swift
//  DrawThingsKit
//
//  Manages server profiles and connection state for Draw Things clients.
//

import Foundation
import SwiftUI
import DrawThingsClient

// MARK: - Connection State

/// Represents the current connection state.
public enum ConnectionState: Equatable, Sendable {
    case disconnected
    case connecting
    case connected
    case error(String)

    public var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    public var isConnecting: Bool {
        if case .connecting = self { return true }
        return false
    }

    public var errorMessage: String? {
        if case .error(let message) = self { return message }
        return nil
    }
}

// MARK: - Connection Manager

/// Manages server profiles and connection lifecycle for Draw Things applications.
///
/// This class handles:
/// - Storing and managing multiple server profiles
/// - Connecting to and disconnecting from servers
/// - Tracking connection state
/// - Managing the models catalog from the connected server
///
/// Example usage:
/// ```swift
/// @StateObject private var connectionManager = ConnectionManager()
///
/// // Connect to a profile
/// await connectionManager.connect(to: profile)
///
/// // Access the service for generation
/// if let service = connectionManager.service {
///     // Use service for generation
/// }
/// ```
@MainActor
public final class ConnectionManager: ObservableObject {
    // MARK: - Published Properties

    /// All saved server profiles.
    @Published public private(set) var profiles: [ServerProfile] = []

    /// The currently active profile (connected or attempting to connect).
    @Published public private(set) var activeProfile: ServerProfile?

    /// Current connection state.
    @Published public private(set) var connectionState: ConnectionState = .disconnected

    /// Models manager populated from the connected server.
    @Published public private(set) var modelsManager = ModelsManager()

    // MARK: - Private Properties

    private var service: DrawThingsService?
    private let storage: ProfileStorage

    // MARK: - Initialization

    /// Initialize with optional custom storage.
    /// - Parameter storage: Custom ProfileStorage instance. Defaults to standard UserDefaults storage.
    public init(storage: ProfileStorage = ProfileStorage()) {
        self.storage = storage
        loadProfiles()
    }

    // MARK: - Public Properties

    /// The active DrawThingsService for making RPC calls.
    /// Returns nil if not connected.
    public var activeService: DrawThingsService? {
        guard connectionState.isConnected else { return nil }
        return service
    }

    /// The default profile, if one is set.
    public var defaultProfile: ServerProfile? {
        profiles.first { $0.isDefault }
    }

    // MARK: - Profile Management

    /// Add a new server profile.
    /// - Parameter profile: The profile to add.
    public func addProfile(_ profile: ServerProfile) {
        var newProfile = profile

        // If this is marked as default, clear default from others
        if newProfile.isDefault {
            clearDefaultFlag()
        }

        // If this is the first profile, make it default
        if profiles.isEmpty {
            newProfile.isDefault = true
        }

        profiles.append(newProfile)
        saveProfiles()
    }

    /// Update an existing profile.
    /// - Parameter profile: The updated profile.
    public func updateProfile(_ profile: ServerProfile) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else {
            return
        }

        var updatedProfile = profile

        // If this is marked as default, clear default from others
        if updatedProfile.isDefault {
            clearDefaultFlag(except: profile.id)
        }

        profiles[index] = updatedProfile
        saveProfiles()

        // If we updated the active profile, update our reference
        if activeProfile?.id == profile.id {
            activeProfile = updatedProfile
        }
    }

    /// Delete a profile.
    /// - Parameter profile: The profile to delete.
    public func deleteProfile(_ profile: ServerProfile) {
        // Disconnect if this is the active profile
        if activeProfile?.id == profile.id {
            disconnect()
        }

        profiles.removeAll { $0.id == profile.id }

        // If we deleted the default, make the first profile default
        if profile.isDefault, let first = profiles.first {
            var newDefault = first
            newDefault.isDefault = true
            if let index = profiles.firstIndex(where: { $0.id == first.id }) {
                profiles[index] = newDefault
            }
        }

        saveProfiles()
    }

    /// Set a profile as the default.
    /// - Parameter profile: The profile to set as default.
    public func setDefault(_ profile: ServerProfile) {
        clearDefaultFlag()

        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index].isDefault = true
            saveProfiles()
        }
    }

    // MARK: - Connection Management

    /// Connect to a server profile.
    /// - Parameter profile: The profile to connect to.
    public func connect(to profile: ServerProfile) async {
        // Disconnect from any existing connection
        if connectionState.isConnected {
            disconnect()
        }

        activeProfile = profile
        connectionState = .connecting

        do {
            // Create the service
            let newService = try DrawThingsService(
                address: profile.address,
                useTLS: profile.useTLS
            )
            self.service = newService

            // Test connection with echo
            let response = try await newService.echo(name: "DrawThingsKit")

            // Update models from metadata
            if response.hasOverride {
                modelsManager.updateFromMetadata(response.override)
            }

            connectionState = .connected

        } catch {
            service = nil
            connectionState = .error(error.localizedDescription)
        }
    }

    /// Connect to the default profile, if one exists.
    public func connectToDefault() async {
        guard let defaultProfile = defaultProfile else {
            connectionState = .error("No default profile configured")
            return
        }
        await connect(to: defaultProfile)
    }

    /// Disconnect from the current server.
    public func disconnect() {
        service = nil
        activeProfile = nil
        connectionState = .disconnected
        modelsManager.clear()
    }

    /// Attempt to reconnect to the active profile.
    public func reconnect() async {
        guard let profile = activeProfile else {
            return
        }
        await connect(to: profile)
    }

    // MARK: - Private Methods

    private func loadProfiles() {
        profiles = storage.loadProfiles()

        // If no profiles exist, add a default localhost profile
        if profiles.isEmpty {
            addProfile(.localhost)
        }
    }

    private func saveProfiles() {
        storage.saveProfiles(profiles)
    }

    private func clearDefaultFlag(except excludeId: UUID? = nil) {
        for index in profiles.indices {
            if profiles[index].id != excludeId {
                profiles[index].isDefault = false
            }
        }
    }
}
