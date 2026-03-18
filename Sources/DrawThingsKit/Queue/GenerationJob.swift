//
//  GenerationJob.swift
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
import DrawThingsClient
import DrawThingsQueue

#if os(macOS)
import AppKit
#else
import UIKit
#endif


// MARK: - Job Status

/// The status of a generation job.
public enum JobStatus: String, Sendable {
    case pending
    case processing
    case completed
    case failed
    case cancelled
}

// MARK: - Job Progress

/// Progress information for a running job.
public struct JobProgress {
    public var currentStep: Int
    public var totalSteps: Int
    public var stage: String?
    public var previewImage: PlatformImage?

    public init(
        currentStep: Int = 0,
        totalSteps: Int = 0,
        stage: String? = nil,
        previewImage: PlatformImage? = nil
    ) {
        self.currentStep = currentStep
        self.totalSteps = totalSteps
        self.stage = stage
        self.previewImage = previewImage
    }

    public var progressFraction: Double {
        guard totalSteps > 0 else { return 0 }
        return Double(currentStep) / Double(totalSteps)
    }

    public var progressPercentage: Int {
        Int(progressFraction * 100)
    }

    /// Create from DrawThingsQueue's GenerationProgress.
    @MainActor
    init(from progress: GenerationProgress) {
        self.currentStep = progress.currentStep
        self.totalSteps = progress.totalSteps
        self.stage = progress.stage.description
        self.previewImage = progress.previewImage
    }
}

// MARK: - Generation Job (View Model)

/// A view-model representing a generation job in the queue.
///
/// This struct provides a unified view of a job's state by combining data from
/// DrawThingsQueue's `GenerationRequest`, `GenerationResult`, and `GenerationError` types.
public struct GenerationJob: Identifiable, Hashable, Equatable {
    public let id: UUID
    public var name: String
    public var prompt: String
    public var negativePrompt: String
    public var configuration: DrawThingsConfiguration
    public var status: JobStatus
    public var progress: JobProgress?
    public var errorMessage: String?
    public var resultImages: [PlatformImage]
    public var audioData: [Data]
    public var createdAt: Date
    public var startedAt: Date?
    public var completedAt: Date?
    public var retryCount: Int

    /// First result image, if any.
    public var firstResultImage: PlatformImage? {
        resultImages.first
    }

    /// Whether the job produced audio data.
    public var hasAudio: Bool { !audioData.isEmpty }

    /// First audio result as WAV data, if any.
    public var firstAudioData: Data? { audioData.first }

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

    // MARK: - Equatable / Hashable

    public static func == (lhs: GenerationJob, rhs: GenerationJob) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    // MARK: - Factory from DrawThingsQueue types

    /// Create a pending job from a GenerationRequest.
    static func fromRequest(_ request: GenerationRequest) -> GenerationJob {
        GenerationJob(
            id: request.id,
            name: request.name,
            prompt: request.prompt,
            negativePrompt: request.negativePrompt,
            configuration: request.configuration,
            status: .pending,
            progress: nil,
            errorMessage: nil,
            resultImages: [],
            audioData: [],
            createdAt: request.createdAt,
            startedAt: nil,
            completedAt: nil,
            retryCount: 0
        )
    }

    /// Create a completed job from a GenerationResult.
    static func fromResult(_ result: GenerationResult) -> GenerationJob {
        GenerationJob(
            id: result.id,
            name: result.request.name,
            prompt: result.request.prompt,
            negativePrompt: result.request.negativePrompt,
            configuration: result.request.configuration,
            status: .completed,
            progress: nil,
            errorMessage: nil,
            resultImages: result.images,
            audioData: result.audioData,
            createdAt: result.request.createdAt,
            startedAt: result.startedAt,
            completedAt: result.completedAt,
            retryCount: 0
        )
    }

    /// Create a failed job from a queue GenerationError.
    static func fromError(_ error: GenerationError) -> GenerationJob {
        GenerationJob(
            id: error.id,
            name: error.request.name,
            prompt: error.request.prompt,
            negativePrompt: error.request.negativePrompt,
            configuration: error.request.configuration,
            status: .failed,
            progress: nil,
            errorMessage: error.underlyingError.localizedDescription,
            resultImages: [],
            audioData: [],
            createdAt: error.request.createdAt,
            startedAt: nil,
            completedAt: error.occurredAt,
            retryCount: 0
        )
    }
}
