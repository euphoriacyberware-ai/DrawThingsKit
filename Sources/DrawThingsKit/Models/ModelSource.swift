//
//  ModelSource.swift
//  DrawThingsKit
//
//  Defines the source of a model (local, official cloud, or community).
//

import Foundation
import SwiftUI

/// Indicates where a model is available from.
public enum ModelSource: String, Codable, Sendable, CaseIterable {
    /// Model is installed locally on the Draw Things server.
    case local

    /// Official model available through Draw Things cloud service.
    /// These are the built-in models from ModelZoo (available on Community and DrawThings+ plans).
    case official

    /// Community-contributed model available through Draw Things cloud service.
    /// These are user-submitted models from the community-models repository.
    case community

    /// Display name for the source.
    public var displayName: String {
        switch self {
        case .local: return "Local"
        case .official: return "Official"
        case .community: return "Community"
        }
    }

    /// SF Symbol name for the source icon.
    public var iconName: String {
        switch self {
        case .local: return "internaldrive"
        case .official: return "checkmark.seal.fill"
        case .community: return "person.2.fill"
        }
    }

    /// Icon color for the source.
    public var iconColor: Color {
        switch self {
        case .local: return .secondary
        case .official: return .blue
        case .community: return .green
        }
    }
}

// MARK: - Model Label View

/// A view that displays a model name with its source icon.
public struct ModelLabelView: View {
    let name: String
    let source: ModelSource
    let showSourceIcon: Bool

    public init(name: String, source: ModelSource, showSourceIcon: Bool = true) {
        self.name = name
        self.source = source
        self.showSourceIcon = showSourceIcon
    }

    public var body: some View {
        HStack(spacing: 6) {
            if showSourceIcon && source != .local {
                Image(systemName: source.iconName)
                    .foregroundColor(source.iconColor)
                    .font(.caption)
            }
            Text(name)
        }
    }
}
