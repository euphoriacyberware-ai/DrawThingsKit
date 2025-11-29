//
//  ProfileStorage.swift
//  DrawThingsKit
//
//  UserDefaults-based persistence for server profiles.
//

import Foundation

/// Handles persistence of server profiles to UserDefaults.
/// Profiles are stored per-app using the bundle identifier as a key prefix.
public final class ProfileStorage: Sendable {
    private let userDefaults: UserDefaults
    private let storageKey: String

    /// Initialize with optional custom UserDefaults and key prefix.
    /// - Parameters:
    ///   - userDefaults: The UserDefaults instance to use. Defaults to `.standard`.
    ///   - keyPrefix: Custom key prefix. Defaults to the app's bundle identifier.
    public init(
        userDefaults: UserDefaults = .standard,
        keyPrefix: String? = nil
    ) {
        self.userDefaults = userDefaults
        let prefix = keyPrefix ?? Bundle.main.bundleIdentifier ?? "DrawThingsKit"
        self.storageKey = "\(prefix).serverProfiles"
    }

    /// Load all saved profiles.
    /// - Returns: Array of saved profiles, or empty array if none exist.
    public func loadProfiles() -> [ServerProfile] {
        guard let data = userDefaults.data(forKey: storageKey) else {
            return []
        }

        do {
            let profiles = try JSONDecoder().decode([ServerProfile].self, from: data)
            return profiles
        } catch {
            print("DrawThingsKit: Failed to decode profiles: \(error)")
            return []
        }
    }

    /// Save profiles to storage.
    /// - Parameter profiles: The profiles to save.
    public func saveProfiles(_ profiles: [ServerProfile]) {
        do {
            let data = try JSONEncoder().encode(profiles)
            userDefaults.set(data, forKey: storageKey)
        } catch {
            print("DrawThingsKit: Failed to encode profiles: \(error)")
        }
    }

    /// Clear all saved profiles.
    public func clearProfiles() {
        userDefaults.removeObject(forKey: storageKey)
    }
}
