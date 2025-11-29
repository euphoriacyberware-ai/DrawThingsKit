//
//  ServerProfileRow.swift
//  DrawThingsKit
//
//  A row view for displaying a server profile in a list.
//

import SwiftUI

/// A row view for displaying a server profile in a list.
///
/// Shows the profile name, address, and connection status.
/// Indicates the default profile with a star badge.
public struct ServerProfileRow: View {
    let profile: ServerProfile
    let isActive: Bool
    let isConnected: Bool

    public init(
        profile: ServerProfile,
        isActive: Bool = false,
        isConnected: Bool = false
    ) {
        self.profile = profile
        self.isActive = isActive
        self.isConnected = isConnected
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Connection status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(profile.name)
                        .font(.body)
                        .fontWeight(isActive ? .semibold : .regular)

                    if profile.isDefault {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                    }
                }

                HStack(spacing: 4) {
                    Text(profile.address)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if profile.useTLS {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()
        }
        .contentShape(Rectangle())
    }

    private var statusColor: Color {
        if isConnected {
            return .green
        } else if isActive {
            return .yellow
        } else {
            return .gray.opacity(0.5)
        }
    }
}

#Preview("Default Profile") {
    ServerProfileRow(
        profile: .localhost,
        isActive: false,
        isConnected: false
    )
    .padding()
}

#Preview("Connected Profile") {
    ServerProfileRow(
        profile: ServerProfile(name: "Remote Server", host: "192.168.1.100", port: 7859, useTLS: true),
        isActive: true,
        isConnected: true
    )
    .padding()
}
