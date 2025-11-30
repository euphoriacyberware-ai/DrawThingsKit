//
//  ModelsManager.swift
//  DrawThingsKit
//
//  Manages model catalogs received from the Draw Things server.
//

import Foundation
import DrawThingsClient

// MARK: - Model Data Structures

/// Checkpoint (base) model information from the server.
public struct CheckpointModel: Identifiable, Codable, Hashable, Sendable {
    public var id: String { file }
    public let name: String
    public let file: String
    public let version: String?
    public let prefix: String?
    public let modifier: String?
    public let note: String?
    public let defaultScale: Int?
    public let autoencoder: String?
    public let textEncoder: String?
    public let clipEncoder: String?

    enum CodingKeys: String, CodingKey {
        case name, file, version, prefix, modifier, note, autoencoder
        case defaultScale = "default_scale"
        case textEncoder = "text_encoder"
        case clipEncoder = "clip_encoder"
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(file)
    }

    public static func == (lhs: CheckpointModel, rhs: CheckpointModel) -> Bool {
        lhs.file == rhs.file
    }
}

/// LoRA model information from the server.
public struct LoRAModel: Identifiable, Codable, Hashable, Sendable {
    public var id: String { file }
    public let name: String
    public let file: String
    public let version: String?
    public let prefix: String?
    public let isLoHa: Bool?
    public let isConsistencyModel: Bool?

    enum CodingKeys: String, CodingKey {
        case name, file, version, prefix
        case isLoHa = "is_lo_ha"
        case isConsistencyModel = "is_consistency_model"
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(file)
    }

    public static func == (lhs: LoRAModel, rhs: LoRAModel) -> Bool {
        lhs.file == rhs.file
    }
}

/// ControlNet model information from the server.
public struct ControlNetModel: Identifiable, Codable, Hashable, Sendable {
    public var id: String { file }
    public let name: String
    public let file: String
    public let version: String?
    public let prefix: String?

    enum CodingKeys: String, CodingKey {
        case name, file, version, prefix
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(file)
    }

    public static func == (lhs: ControlNetModel, rhs: ControlNetModel) -> Bool {
        lhs.file == rhs.file
    }
}

/// Textual Inversion (embedding) model information from the server.
public struct TextualInversionModel: Identifiable, Codable, Hashable, Sendable {
    public var id: String { file }
    public let name: String
    public let file: String
    public let keyword: String?
    public let version: String?
    public let length: Int?
    public let deprecated: Bool?

    enum CodingKeys: String, CodingKey {
        case name, file, keyword, version, length, deprecated
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(file)
    }

    public static func == (lhs: TextualInversionModel, rhs: TextualInversionModel) -> Bool {
        lhs.file == rhs.file
    }
}

/// Upscaler model information from the server.
public struct UpscalerModel: Identifiable, Codable, Hashable, Sendable {
    public var id: String { file }
    public let name: String
    public let file: String
    public let scaleFactor: Int?
    public let blocks: Int?

    enum CodingKeys: String, CodingKey {
        case name, file, blocks
        case scaleFactor = "scale_factor"
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(file)
    }

    public static func == (lhs: UpscalerModel, rhs: UpscalerModel) -> Bool {
        lhs.file == rhs.file
    }
}

// MARK: - Models Manager

/// Manages model catalogs received from the Draw Things server.
/// Provides filtering for model compatibility based on version matching.
@MainActor
public final class ModelsManager: ObservableObject {
    @Published public private(set) var checkpoints: [CheckpointModel] = []
    @Published public private(set) var loras: [LoRAModel] = []
    @Published public private(set) var controlNets: [ControlNetModel] = []
    @Published public private(set) var textualInversions: [TextualInversionModel] = []
    @Published public private(set) var upscalers: [UpscalerModel] = []

    @Published public var selectedCheckpoint: CheckpointModel?

    public init() {}

    // MARK: - Compatibility Filtering

    /// LoRAs compatible with the currently selected checkpoint.
    public var compatibleLoRAs: [LoRAModel] {
        guard let checkpoint = selectedCheckpoint,
              let checkpointVersion = checkpoint.version else {
            return loras
        }
        return loras.filter { $0.version == checkpointVersion }
    }

    /// ControlNets compatible with the currently selected checkpoint.
    public var compatibleControlNets: [ControlNetModel] {
        guard let checkpoint = selectedCheckpoint,
              let checkpointVersion = checkpoint.version else {
            return controlNets
        }
        return controlNets.filter { $0.version == checkpointVersion }
    }

    /// Textual inversions compatible with the currently selected checkpoint.
    public var compatibleTextualInversions: [TextualInversionModel] {
        guard let checkpoint = selectedCheckpoint,
              let checkpointVersion = checkpoint.version else {
            return textualInversions
        }
        return textualInversions.filter { $0.version == checkpointVersion }
    }

    /// Checkpoint models that are refiners (version contains "refiner").
    public var refinerModels: [CheckpointModel] {
        checkpoints.filter { $0.version?.contains("refiner") == true }
    }

    /// Checkpoint models that are not refiners.
    public var baseModels: [CheckpointModel] {
        checkpoints.filter { $0.version?.contains("refiner") != true }
    }

    // MARK: - Update from Server

    /// Update model catalogs from server metadata.
    /// - Parameter metadata: The MetadataOverride from the server echo response.
    public func updateFromMetadata(_ metadata: MetadataOverride) {
        let decoder = JSONDecoder()

        if !metadata.models.isEmpty {
            if let decoded = try? decoder.decode([CheckpointModel].self, from: metadata.models) {
                self.checkpoints = decoded
            }
        }

        if !metadata.loras.isEmpty {
            if let decoded = try? decoder.decode([LoRAModel].self, from: metadata.loras) {
                self.loras = decoded
            }
        }

        if !metadata.controlNets.isEmpty {
            if let decoded = try? decoder.decode([ControlNetModel].self, from: metadata.controlNets) {
                self.controlNets = decoded
            }
        }

        if !metadata.textualInversions.isEmpty {
            if let decoded = try? decoder.decode([TextualInversionModel].self, from: metadata.textualInversions) {
                self.textualInversions = decoded
            }
        }

        if !metadata.upscalers.isEmpty {
            if let decoded = try? decoder.decode([UpscalerModel].self, from: metadata.upscalers) {
                self.upscalers = decoded
            }
        }
    }

    /// Clear all model data.
    public func clear() {
        checkpoints = []
        loras = []
        controlNets = []
        textualInversions = []
        upscalers = []
        selectedCheckpoint = nil
    }

    /// Check if any models are loaded.
    public var isEmpty: Bool {
        checkpoints.isEmpty && loras.isEmpty && controlNets.isEmpty
    }

    /// Find a checkpoint model by its filename.
    /// - Parameter filename: The model filename (e.g., "qwen_image_1.0_q8p.ckpt")
    /// - Returns: The matching CheckpointModel, or nil if not found
    public func checkpoint(forFile filename: String) -> CheckpointModel? {
        checkpoints.first { $0.file == filename }
    }

    /// Get the model version string for a given filename.
    /// - Parameter filename: The model filename
    /// - Returns: The version string (e.g., "qwenImage", "flux1"), or nil if not found
    public func version(forFile filename: String) -> String? {
        checkpoint(forFile: filename)?.version
    }

    /// Detect the latent model family for a given filename.
    /// Uses the version field from the model catalog for accurate detection.
    /// - Parameter filename: The model filename
    /// - Returns: The detected LatentModelFamily
    public func latentModelFamily(forFile filename: String) -> LatentModelFamily {
        if let version = version(forFile: filename) {
            return LatentModelFamily.detect(from: version)
        }
        // Fall back to filename-based detection
        return LatentModelFamily.detect(from: filename)
    }

    /// Summary of loaded models for display.
    public var summary: String {
        var parts: [String] = []
        if !checkpoints.isEmpty {
            parts.append("\(checkpoints.count) models")
        }
        if !loras.isEmpty {
            parts.append("\(loras.count) LoRAs")
        }
        if !controlNets.isEmpty {
            parts.append("\(controlNets.count) ControlNets")
        }
        return parts.isEmpty ? "No models" : parts.joined(separator: ", ")
    }

    // MARK: - Preview Helpers

    #if DEBUG
    /// Create a ModelsManager with mock checkpoint data for SwiftUI previews.
    public static func preview(withCheckpoints checkpoints: [CheckpointModel]) -> ModelsManager {
        let manager = ModelsManager()
        manager.checkpoints = checkpoints
        return manager
    }
    #endif
}

// MARK: - Preview Helpers

#if DEBUG
extension CheckpointModel {
    /// Create a mock CheckpointModel for previews.
    public static func mock(
        name: String,
        file: String,
        version: String? = nil
    ) -> CheckpointModel {
        // Use JSONDecoder to create instance since all properties are let
        let json: [String: Any?] = [
            "name": name,
            "file": file,
            "version": version
        ]
        let data = try! JSONSerialization.data(withJSONObject: json.compactMapValues { $0 })
        return try! JSONDecoder().decode(CheckpointModel.self, from: data)
    }
}
#endif
