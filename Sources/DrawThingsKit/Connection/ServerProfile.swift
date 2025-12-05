//
//  ServerProfile.swift
//  DrawThingsKit
//
//  Created by euphoriacyberware-ai.
//  Copyright © 2025 euphoriacyberware-ai
//
//  Licensed under the MIT License.
//  See LICENSE file in the project root for license information.
//

import Foundation

/// Represents a saved server connection profile.
public struct ServerProfile: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var host: String
    public var port: Int
    public var useTLS: Bool
    public var isDefault: Bool

    /// The full address string in "host:port" format.
    public var address: String {
        "\(host):\(port)"
    }

    public init(
        id: UUID = UUID(),
        name: String,
        host: String = "localhost",
        port: Int = 7859,
        useTLS: Bool = true,
        isDefault: Bool = false
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.useTLS = useTLS
        self.isDefault = isDefault
    }

    /// Creates a profile from an address string (e.g., "localhost:7859").
    public init(name: String, address: String, useTLS: Bool = true, isDefault: Bool = false) {
        self.id = UUID()
        self.name = name
        self.useTLS = useTLS
        self.isDefault = isDefault

        let components = address.split(separator: ":")
        if components.count == 2,
           let portNumber = Int(components[1]) {
            self.host = String(components[0])
            self.port = portNumber
        } else {
            self.host = address
            self.port = 7859
        }
    }
}

// MARK: - Default Profile

extension ServerProfile {
    /// A default localhost profile for convenience.
    public static var localhost: ServerProfile {
        ServerProfile(
            name: "Local Server",
            host: "localhost",
            port: 7859,
            useTLS: true,
            isDefault: true
        )
    }
}
