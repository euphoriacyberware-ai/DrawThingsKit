//
//  ConfigurationManager.swift
//  DrawThingsKit
//
//  Created by euphoriacyberware-ai.
//  Copyright © 2025 euphoriacyberware-ai
//
//  Licensed under the MIT License.
//  See LICENSE file in the project root for license information.
//

import Foundation
import SwiftUI
import Combine
import DrawThingsClient
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Manages the single active configuration used for generation.
///
/// Provides:
/// - Active configuration state
/// - Copy/paste to system clipboard
/// - Prompt and model selection state
///
/// Example usage:
/// ```swift
/// @StateObject private var configurationManager = ConfigurationManager()
///
/// var body: some View {
///     ConfigurationActionsView()
///         .environmentObject(configurationManager)
/// }
/// ```
@MainActor
public final class ConfigurationManager: ObservableObject {
    /// The active configuration for generation
    @Published public var activeConfiguration: DrawThingsConfiguration = DrawThingsConfiguration()

    /// The active prompt (stored separately as it's not part of DrawThingsConfiguration)
    @Published public var prompt: String = ""

    /// The active negative prompt
    @Published public var negativePrompt: String = ""

    /// Selected checkpoint model (syncs with activeConfiguration.model)
    @Published public var selectedCheckpoint: CheckpointModel? = nil

    /// Selected refiner model (syncs with activeConfiguration.refinerModel)
    @Published public var selectedRefiner: CheckpointModel? = nil

    /// Selected LoRA configurations
    @Published public var selectedLoRAs: [LoRAConfiguration] = []

    /// Selected ControlNet configurations
    @Published public var selectedControls: [ControlNetConfiguration] = []

    /// Mixture of Experts mode - enables Wan 2.2 style workflows where any model can be used as refiner
    @Published public var mixtureOfExperts: Bool = false

    public init() {}

    /// Sync model selections to configuration (call before using activeConfiguration)
    public func syncModelsToConfiguration() {
        // Only override model if a checkpoint is selected from the picker
        if let checkpoint = selectedCheckpoint {
            activeConfiguration.model = checkpoint.file
        }
        // Only override refiner if a refiner is selected from the picker
        if let refiner = selectedRefiner {
            activeConfiguration.refinerModel = refiner.file
        }
        // If selectedRefiner is nil but was explicitly cleared (not just unset),
        // we leave activeConfiguration.refinerModel as-is to preserve text field values

        // Sync LoRAs - convert UI configurations to DrawThingsClient format
        activeConfiguration.loras = selectedLoRAs.toLoRAConfigs()

        // Sync ControlNets - convert UI configurations to DrawThingsClient format
        activeConfiguration.controls = selectedControls.toControlConfigs()
    }

    /// Update selected models from a ModelsManager after loading a preset
    /// Call this after loading a configuration to resolve model filenames to CheckpointModel objects
    public func resolveModels(from modelsManager: ModelsManager) {
        // Resolve checkpoint
        selectedCheckpoint = modelsManager.checkpoints.first { $0.file == activeConfiguration.model }

        // Resolve refiner
        if let refinerFile = activeConfiguration.refinerModel {
            selectedRefiner = modelsManager.checkpoints.first { $0.file == refinerFile }
        } else {
            selectedRefiner = nil
        }

        // Resolve LoRAs from configuration
        selectedLoRAs = activeConfiguration.loras.compactMap { loraConfig in
            guard let loraModel = modelsManager.loras.first(where: { $0.file == loraConfig.file }) else {
                return nil
            }
            return LoRAConfiguration(
                lora: loraModel,
                weight: Double(loraConfig.weight),
                mode: loraConfig.mode,
                enabled: true
            )
        }

        // Resolve ControlNets from configuration
        selectedControls = activeConfiguration.controls.compactMap { controlConfig in
            guard let controlModel = modelsManager.controlNets.first(where: { $0.file == controlConfig.file }) else {
                return nil
            }
            return ControlNetConfiguration(
                controlNet: controlModel,
                weight: Double(controlConfig.weight),
                guidanceStart: Double(controlConfig.guidanceStart),
                guidanceEnd: Double(controlConfig.guidanceEnd),
                controlMode: controlConfig.controlMode,
                enabled: true
            )
        }
    }

    // MARK: - Clipboard Operations

    /// Copy the current configuration to the system clipboard as JSON
    public func copyToClipboard() {
        syncModelsToConfiguration()
        do {
            let json = try activeConfiguration.toJSON()
            #if os(macOS)
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(json, forType: .string)
            #else
            UIPasteboard.general.string = json
            #endif
        } catch {
            print("Failed to copy configuration: \(error)")
        }
    }

    /// Paste configuration from the system clipboard
    /// Returns true if successful, false if clipboard doesn't contain valid config
    /// Only updates fields present in the JSON; other fields retain their current values.
    @discardableResult
    public func pasteFromClipboard() -> Bool {
        #if os(macOS)
        guard let json = NSPasteboard.general.string(forType: .string) else {
            return false
        }
        #else
        guard let json = UIPasteboard.general.string else {
            return false
        }
        #endif

        do {
            try activeConfiguration.mergeJSON(json)
            return true
        } catch {
            print("Failed to paste configuration: \(error)")
            return false
        }
    }

    /// Load a configuration from JSON string
    /// Only updates fields present in the JSON; other fields retain their current values.
    public func loadFromJSON(_ json: String) -> Bool {
        do {
            try activeConfiguration.mergeJSON(json)
            return true
        } catch {
            print("Failed to load configuration: \(error)")
            return false
        }
    }

    /// Export the current configuration as JSON string
    public func exportToJSON() -> String? {
        syncModelsToConfiguration()
        return try? activeConfiguration.toJSON()
    }

    /// Reset to default configuration
    public func resetToDefaults() {
        activeConfiguration = DrawThingsConfiguration()
        prompt = ""
        negativePrompt = ""
        selectedCheckpoint = nil
        selectedRefiner = nil
        selectedLoRAs = []
        selectedControls = []
    }
}
