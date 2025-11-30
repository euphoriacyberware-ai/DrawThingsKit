//
//  GenerationJob.swift
//  DrawThingsKit
//
//  Model for a queued image generation job.
//

import Foundation
import SwiftUI
import DrawThingsClient

#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Job Status

/// The status of a generation job.
public enum JobStatus: String, Codable, Sendable {
    case pending
    case processing
    case completed
    case failed
    case cancelled
}

// MARK: - Job Progress

/// Progress information for a running job.
///
/// Note: This type uses `@unchecked Sendable` because `PlatformImage` is not Sendable,
/// but the image property is only accessed on the main thread for UI purposes.
public struct JobProgress: Codable, @unchecked Sendable {
    public var currentStep: Int
    public var totalSteps: Int
    public var stage: String?

    /// Raw DTTensor preview data (internal use only, not exposed to apps).
    internal var previewImageData: Data?

    /// Converted preview image ready for display.
    /// This is populated by JobQueue after converting from DTTensor format.
    /// Note: This property is transient and not persisted.
    public var previewImage: PlatformImage? {
        get { _previewImage }
        set { _previewImage = newValue }
    }

    // Non-Codable storage for the converted image
    private var _previewImage: PlatformImage?

    // Custom coding keys to exclude the transient image
    private enum CodingKeys: String, CodingKey {
        case currentStep, totalSteps, stage, previewImageData
    }

    public init(
        currentStep: Int = 0,
        totalSteps: Int = 0,
        stage: String? = nil,
        previewImage: PlatformImage? = nil
    ) {
        self.currentStep = currentStep
        self.totalSteps = totalSteps
        self.stage = stage
        self.previewImageData = nil
        self._previewImage = previewImage
    }

    /// Internal initializer that accepts raw DTTensor data
    internal init(
        currentStep: Int,
        totalSteps: Int,
        stage: String?,
        previewImageData: Data?
    ) {
        self.currentStep = currentStep
        self.totalSteps = totalSteps
        self.stage = stage
        self.previewImageData = previewImageData
        self._previewImage = nil
    }

    public var progressFraction: Double {
        guard totalSteps > 0 else { return 0 }
        return Double(currentStep) / Double(totalSteps)
    }

    public var progressPercentage: Int {
        Int(progressFraction * 100)
    }
}

// MARK: - Hint Data (for serialization)

/// Serializable hint data for moodboard/reference images.
public struct HintData: Codable, Sendable {
    public var type: String
    public var imageData: Data
    public var weight: Float

    public init(type: String, imageData: Data, weight: Float = 1.0) {
        self.type = type
        self.imageData = imageData
        self.weight = weight
    }
}

// MARK: - Generation Job

/// A queued image generation job.
///
/// Contains all the information needed to execute a generation request,
/// along with status tracking, progress updates, and results.
public struct GenerationJob: Identifiable, Codable {
    public let id: UUID
    public var name: String
    public var prompt: String
    public var negativePrompt: String

    // Configuration (serialized as JSON)
    public var configurationJSON: String

    // Input images (optional)
    public var canvasImageData: Data?
    public var maskImageData: Data?
    public var hints: [HintData]

    // Status and progress
    public var status: JobStatus
    public var progress: JobProgress?
    public var errorMessage: String?

    // Results (image data in PNG format, internal storage)
    internal var resultImageData: [Data]

    /// Result images as native platform images.
    /// These are converted on-demand from the stored PNG data.
    public var resultImages: [PlatformImage] {
        resultImageData.compactMap { PlatformImage.fromData($0) }
    }

    /// First result image, if any.
    public var firstResultImage: PlatformImage? {
        resultImageData.first.flatMap { PlatformImage.fromData($0) }
    }

    // Timestamps
    public var createdAt: Date
    public var startedAt: Date?
    public var completedAt: Date?

    // Retry tracking
    public var retryCount: Int

    public init(
        id: UUID = UUID(),
        name: String? = nil,
        prompt: String,
        negativePrompt: String = "",
        configuration: DrawThingsConfiguration,
        canvasImageData: Data? = nil,
        maskImageData: Data? = nil,
        hints: [HintData] = []
    ) throws {
        self.id = id
        self.name = name ?? Self.generateName(from: prompt)
        self.prompt = prompt
        self.negativePrompt = negativePrompt
        self.configurationJSON = try configuration.toJSON()
        self.canvasImageData = canvasImageData
        self.maskImageData = maskImageData
        self.hints = hints
        self.status = .pending
        self.progress = nil
        self.errorMessage = nil
        self.resultImageData = []
        self.createdAt = Date()
        self.startedAt = nil
        self.completedAt = nil
        self.retryCount = 0
    }

    /// Parse the configuration from stored JSON.
    public func configuration() throws -> DrawThingsConfiguration {
        try DrawThingsConfiguration.fromJSON(configurationJSON)
    }

    /// Generate a short name from the prompt.
    private static func generateName(from prompt: String) -> String {
        let words = prompt.split(separator: " ").prefix(4)
        let name = words.joined(separator: " ")
        if name.count > 30 {
            return String(name.prefix(27)) + "..."
        }
        return name.isEmpty ? "Untitled" : name
    }

    // MARK: - Status Helpers

    public var isPending: Bool { status == .pending }
    public var isProcessing: Bool { status == .processing }
    public var isCompleted: Bool { status == .completed }
    public var isFailed: Bool { status == .failed }
    public var isCancelled: Bool { status == .cancelled }

    public var isFinished: Bool {
        status == .completed || status == .failed || status == .cancelled
    }

    public var canRetry: Bool {
        status == .failed && retryCount < 3
    }

    /// Duration of the job (if completed).
    public var duration: TimeInterval? {
        guard let start = startedAt, let end = completedAt else { return nil }
        return end.timeIntervalSince(start)
    }

    /// Formatted duration string.
    public var durationString: String? {
        guard let duration = duration else { return nil }
        if duration < 60 {
            return String(format: "%.1fs", duration)
        } else {
            let minutes = Int(duration) / 60
            let seconds = Int(duration) % 60
            return "\(minutes)m \(seconds)s"
        }
    }
}

// MARK: - Equatable

extension GenerationJob: Equatable {
    public static func == (lhs: GenerationJob, rhs: GenerationJob) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Hashable

extension GenerationJob: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
