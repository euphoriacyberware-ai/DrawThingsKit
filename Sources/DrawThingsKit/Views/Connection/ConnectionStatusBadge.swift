//
//  ConnectionStatusBadge.swift
//  DrawThingsKit
//
//  Created by euphoriacyberware-ai.
//  Copyright © 2025 euphoriacyberware-ai
//
//  Licensed under the MIT License.
//  See LICENSE file in the project root for license information.
//

import SwiftUI

/// A compact badge showing the current connection status.
///
/// Displays a colored dot and status text. Can be used in toolbars,
/// status bars, or anywhere a compact status indicator is needed.
///
/// When clicked:
/// - If disconnected: connects to the default profile
/// - If connecting: cancels the connection attempt
/// - If connected: disconnects
///
/// Example usage:
/// ```swift
/// ConnectionStatusBadge(connectionManager: connectionManager)
/// ```
public struct ConnectionStatusBadge: View {
    @ObservedObject var connectionManager: ConnectionManager

    public init(connectionManager: ConnectionManager) {
        self.connectionManager = connectionManager
    }

    public var body: some View {
        Button {
            handleTap()
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)

                Text(statusText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
        .help(helpText)
    }

    private func handleTap() {
        switch connectionManager.connectionState {
        case .disconnected, .error:
            Task {
                await connectionManager.connectToDefault()
            }
        case .connecting, .connected:
            connectionManager.disconnect()
        }
    }

    private var helpText: String {
        switch connectionManager.connectionState {
        case .disconnected:
            if connectionManager.defaultProfile != nil {
                return "Click to connect to default server"
            } else {
                return "No default profile configured"
            }
        case .connecting:
            return "Click to cancel connection"
        case .connected:
            return "Click to disconnect"
        case .error:
            return "Click to retry connection"
        }
    }

    private var statusColor: Color {
        switch connectionManager.connectionState {
        case .disconnected:
            return .gray
        case .connecting:
            return .yellow
        case .connected:
            return .green
        case .error:
            return .red
        }
    }

    private var statusText: String {
        switch connectionManager.connectionState {
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting..."
        case .connected:
            if let profile = connectionManager.activeProfile {
                return profile.name
            }
            return "Connected"
        case .error:
            return "Error"
        }
    }
}

/// An expanded connection status view with more details.
///
/// Shows the full connection status including server address,
/// model counts, and error messages when applicable.
public struct ConnectionStatusView: View {
    @ObservedObject var connectionManager: ConnectionManager
    var onReconnect: (() async -> Void)?

    public init(
        connectionManager: ConnectionManager,
        onReconnect: (() async -> Void)? = nil
    ) {
        self.connectionManager = connectionManager
        self.onReconnect = onReconnect
    }

    public var body: some View {
        HStack {
            ConnectionStatusBadge(connectionManager: connectionManager)

            if connectionManager.connectionState.isConnected {
                Text(connectionManager.modelsManager.summary)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if let error = connectionManager.connectionState.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .lineLimit(1)

                if let onReconnect = onReconnect {
                    Button("Retry") {
                        Task {
                            await onReconnect()
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }
}

#Preview("Badge - Disconnected") {
    let manager = ConnectionManager()
    return ConnectionStatusBadge(connectionManager: manager)
        .padding()
}

#Preview("Status View") {
    let manager = ConnectionManager()
    return ConnectionStatusView(connectionManager: manager)
        .padding()
}
