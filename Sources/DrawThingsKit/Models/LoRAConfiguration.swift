//
//  LoRAConfiguration.swift
//  DrawThingsKit
//
//  UI-friendly wrapper for LoRA configuration with observable properties.
//

import Foundation
import SwiftUI
import DrawThingsClient

/// A UI-friendly wrapper for LoRA configuration that supports SwiftUI bindings.
///
/// This type wraps a `LoRAModel` with additional properties for weight, mode,
/// and enabled state, making it suitable for use in configuration editors.
public struct LoRAConfiguration: Identifiable, Hashable {
    public let id: UUID
    public let lora: LoRAModel
    public var weight: Double
    public var mode: LoRAMode
    public var enabled: Bool

    public init(
        id: UUID = UUID(),
        lora: LoRAModel,
        weight: Double = 1.0,
        mode: LoRAMode = .all,
        enabled: Bool = true
    ) {
        self.id = id
        self.lora = lora
        self.weight = weight
        self.mode = mode
        self.enabled = enabled
    }

    /// Convert to the LoRAConfig type used by DrawThingsClient.
    public func toLoRAConfig() -> LoRAConfig {
        LoRAConfig(file: lora.file, weight: Float(weight), mode: mode)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: LoRAConfiguration, rhs: LoRAConfiguration) -> Bool {
        lhs.id == rhs.id
    }
}

/// A UI-friendly wrapper for ControlNet configuration.
public struct ControlNetConfiguration: Identifiable, Hashable {
    public let id: UUID
    public let controlNet: ControlNetModel
    public var weight: Double
    public var guidanceStart: Double
    public var guidanceEnd: Double
    public var controlMode: ControlMode
    public var enabled: Bool

    public init(
        id: UUID = UUID(),
        controlNet: ControlNetModel,
        weight: Double = 1.0,
        guidanceStart: Double = 0.0,
        guidanceEnd: Double = 1.0,
        controlMode: ControlMode = .balanced,
        enabled: Bool = true
    ) {
        self.id = id
        self.controlNet = controlNet
        self.weight = weight
        self.guidanceStart = guidanceStart
        self.guidanceEnd = guidanceEnd
        self.controlMode = controlMode
        self.enabled = enabled
    }

    /// Convert to the ControlConfig type used by DrawThingsClient.
    public func toControlConfig() -> ControlConfig {
        ControlConfig(
            file: controlNet.file,
            weight: Float(weight),
            guidanceStart: Float(guidanceStart),
            guidanceEnd: Float(guidanceEnd),
            controlMode: controlMode
        )
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: ControlNetConfiguration, rhs: ControlNetConfiguration) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Array Extensions

extension Array where Element == LoRAConfiguration {
    /// Convert all enabled LoRA configurations to LoRAConfig array.
    public func toLoRAConfigs() -> [LoRAConfig] {
        filter { $0.enabled }.map { $0.toLoRAConfig() }
    }
}

extension Array where Element == ControlNetConfiguration {
    /// Convert all enabled ControlNet configurations to ControlConfig array.
    public func toControlConfigs() -> [ControlConfig] {
        filter { $0.enabled }.map { $0.toControlConfig() }
    }
}
