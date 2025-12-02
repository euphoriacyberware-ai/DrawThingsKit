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

    /// The source of this model (local, official, or community).
    public var source: ModelSource

    enum CodingKeys: String, CodingKey {
        case name, file, version, prefix, modifier, note, autoencoder, source
        case defaultScale = "default_scale"
        case textEncoder = "text_encoder"
        case clipEncoder = "clip_encoder"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        file = try container.decode(String.self, forKey: .file)
        version = try container.decodeIfPresent(String.self, forKey: .version)
        prefix = try container.decodeIfPresent(String.self, forKey: .prefix)
        modifier = try container.decodeIfPresent(String.self, forKey: .modifier)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        defaultScale = try container.decodeIfPresent(Int.self, forKey: .defaultScale)
        autoencoder = try container.decodeIfPresent(String.self, forKey: .autoencoder)
        textEncoder = try container.decodeIfPresent(String.self, forKey: .textEncoder)
        clipEncoder = try container.decodeIfPresent(String.self, forKey: .clipEncoder)
        source = try container.decodeIfPresent(ModelSource.self, forKey: .source) ?? .local
    }

    public init(
        name: String,
        file: String,
        version: String? = nil,
        prefix: String? = nil,
        modifier: String? = nil,
        note: String? = nil,
        defaultScale: Int? = nil,
        autoencoder: String? = nil,
        textEncoder: String? = nil,
        clipEncoder: String? = nil,
        source: ModelSource = .local
    ) {
        self.name = name
        self.file = file
        self.version = version
        self.prefix = prefix
        self.modifier = modifier
        self.note = note
        self.defaultScale = defaultScale
        self.autoencoder = autoencoder
        self.textEncoder = textEncoder
        self.clipEncoder = clipEncoder
        self.source = source
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

    /// The source of this model (local, official, or community).
    public var source: ModelSource

    enum CodingKeys: String, CodingKey {
        case name, file, version, prefix, source
        case isLoHa = "is_lo_ha"
        case isConsistencyModel = "is_consistency_model"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        file = try container.decode(String.self, forKey: .file)
        version = try container.decodeIfPresent(String.self, forKey: .version)
        prefix = try container.decodeIfPresent(String.self, forKey: .prefix)
        isLoHa = try container.decodeIfPresent(Bool.self, forKey: .isLoHa)
        isConsistencyModel = try container.decodeIfPresent(Bool.self, forKey: .isConsistencyModel)
        source = try container.decodeIfPresent(ModelSource.self, forKey: .source) ?? .local
    }

    public init(
        name: String,
        file: String,
        version: String? = nil,
        prefix: String? = nil,
        isLoHa: Bool? = nil,
        isConsistencyModel: Bool? = nil,
        source: ModelSource = .local
    ) {
        self.name = name
        self.file = file
        self.version = version
        self.prefix = prefix
        self.isLoHa = isLoHa
        self.isConsistencyModel = isConsistencyModel
        self.source = source
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

    /// The source of this model (local, official, or community).
    public var source: ModelSource

    enum CodingKeys: String, CodingKey {
        case name, file, version, prefix, source
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        file = try container.decode(String.self, forKey: .file)
        version = try container.decodeIfPresent(String.self, forKey: .version)
        prefix = try container.decodeIfPresent(String.self, forKey: .prefix)
        source = try container.decodeIfPresent(ModelSource.self, forKey: .source) ?? .local
    }

    public init(
        name: String,
        file: String,
        version: String? = nil,
        prefix: String? = nil,
        source: ModelSource = .local
    ) {
        self.name = name
        self.file = file
        self.version = version
        self.prefix = prefix
        self.source = source
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

    /// The source of this model (local, official, or community).
    public var source: ModelSource

    enum CodingKeys: String, CodingKey {
        case name, file, keyword, version, length, deprecated, source
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        file = try container.decode(String.self, forKey: .file)
        keyword = try container.decodeIfPresent(String.self, forKey: .keyword)
        version = try container.decodeIfPresent(String.self, forKey: .version)
        length = try container.decodeIfPresent(Int.self, forKey: .length)
        deprecated = try container.decodeIfPresent(Bool.self, forKey: .deprecated)
        source = try container.decodeIfPresent(ModelSource.self, forKey: .source) ?? .local
    }

    public init(
        name: String,
        file: String,
        keyword: String? = nil,
        version: String? = nil,
        length: Int? = nil,
        deprecated: Bool? = nil,
        source: ModelSource = .local
    ) {
        self.name = name
        self.file = file
        self.keyword = keyword
        self.version = version
        self.length = length
        self.deprecated = deprecated
        self.source = source
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

    /// The source of this model (local, official, or community).
    public var source: ModelSource

    enum CodingKeys: String, CodingKey {
        case name, file, blocks, source
        case scaleFactor = "scale_factor"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        file = try container.decode(String.self, forKey: .file)
        scaleFactor = try container.decodeIfPresent(Int.self, forKey: .scaleFactor)
        blocks = try container.decodeIfPresent(Int.self, forKey: .blocks)
        source = try container.decodeIfPresent(ModelSource.self, forKey: .source) ?? .local
    }

    public init(
        name: String,
        file: String,
        scaleFactor: Int? = nil,
        blocks: Int? = nil,
        source: ModelSource = .local
    ) {
        self.name = name
        self.file = file
        self.scaleFactor = scaleFactor
        self.blocks = blocks
        self.source = source
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
///
/// Operates in two modes:
/// - Cloud mode (default): Shows cloud models (official + community) for bridge mode users
/// - Local mode: Shows local models received from a connected gRPC server
///
/// Set `useLocalModels` to true to switch to local mode when connected to a server.
@MainActor
public final class ModelsManager: ObservableObject {
    // MARK: - Local Models (from server)

    @Published public private(set) var localCheckpoints: [CheckpointModel] = []
    @Published public private(set) var localLoRAs: [LoRAModel] = []
    @Published public private(set) var localControlNets: [ControlNetModel] = []
    @Published public private(set) var localTextualInversions: [TextualInversionModel] = []
    @Published public private(set) var localUpscalers: [UpscalerModel] = []

    // MARK: - Mode Settings

    /// Bridge Mode - when true, shows cloud models (official + community).
    /// When false, shows local models from the connected server.
    /// Matches Draw Things terminology where Bridge Mode = cloud generation.
    @Published public var bridgeMode: Bool = true

    // MARK: - Model Lists (Either cloud OR local)

    /// Available checkpoints - cloud when bridgeMode is on, local when off.
    public var checkpoints: [CheckpointModel] {
        bridgeMode ? CloudModels.allCheckpoints : localCheckpoints
    }

    /// Available LoRAs - cloud when bridgeMode is on, local when off.
    public var loras: [LoRAModel] {
        bridgeMode ? CloudModels.allLoRAs : localLoRAs
    }

    /// Available ControlNets - cloud when bridgeMode is on, local when off.
    public var controlNets: [ControlNetModel] {
        bridgeMode ? CloudModels.allControlNets : localControlNets
    }

    /// Available textual inversions - cloud when bridgeMode is on, local when off.
    public var textualInversions: [TextualInversionModel] {
        bridgeMode ? CloudModels.allTextualInversions : localTextualInversions
    }

    /// Available upscalers - cloud when bridgeMode is on, local when off.
    public var upscalers: [UpscalerModel] {
        bridgeMode ? CloudModels.allUpscalers : localUpscalers
    }

    /// Whether any local models have been received from a server.
    public var hasLocalModels: Bool {
        !localCheckpoints.isEmpty || !localLoRAs.isEmpty || !localControlNets.isEmpty
    }

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
                self.localCheckpoints = decoded
            }
        }

        if !metadata.loras.isEmpty {
            if let decoded = try? decoder.decode([LoRAModel].self, from: metadata.loras) {
                self.localLoRAs = decoded
            }
        }

        if !metadata.controlNets.isEmpty {
            if let decoded = try? decoder.decode([ControlNetModel].self, from: metadata.controlNets) {
                self.localControlNets = decoded
            }
        }

        if !metadata.textualInversions.isEmpty {
            if let decoded = try? decoder.decode([TextualInversionModel].self, from: metadata.textualInversions) {
                self.localTextualInversions = decoded
            }
        }

        if !metadata.upscalers.isEmpty {
            if let decoded = try? decoder.decode([UpscalerModel].self, from: metadata.upscalers) {
                self.localUpscalers = decoded
            }
        }
    }

    /// Clear local model data (when disconnecting from server or connecting to a different server).
    /// Cloud models remain available.
    public func clearLocalModels() {
        localCheckpoints = []
        localLoRAs = []
        localControlNets = []
        localTextualInversions = []
        localUpscalers = []
        selectedCheckpoint = nil
    }

    /// Check if any models are available (local or cloud).
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
        manager.setLocalCheckpoints(checkpoints)
        return manager
    }

    /// Internal method for setting checkpoints in previews/tests.
    internal func setLocalCheckpoints(_ checkpoints: [CheckpointModel]) {
        self.localCheckpoints = checkpoints
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
        version: String? = nil,
        source: ModelSource = .local
    ) -> CheckpointModel {
        CheckpointModel(
            name: name,
            file: file,
            version: version,
            source: source
        )
    }
}

extension LoRAModel {
    /// Create a mock LoRAModel for previews.
    public static func mock(
        name: String,
        file: String,
        version: String? = nil,
        source: ModelSource = .local
    ) -> LoRAModel {
        LoRAModel(
            name: name,
            file: file,
            version: version,
            source: source
        )
    }
}

extension ControlNetModel {
    /// Create a mock ControlNetModel for previews.
    public static func mock(
        name: String,
        file: String,
        version: String? = nil,
        source: ModelSource = .local
    ) -> ControlNetModel {
        ControlNetModel(
            name: name,
            file: file,
            version: version,
            source: source
        )
    }
}
#endif
