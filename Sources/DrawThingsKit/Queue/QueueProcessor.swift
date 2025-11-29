//
//  QueueProcessor.swift
//  DrawThingsKit
//
//  Processes jobs from the queue using the Draw Things service.
//

import Foundation
import SwiftUI
import DrawThingsClient

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Processes generation jobs from the queue.
///
/// Handles:
/// - Sequential job execution
/// - Progress updates and preview images
/// - Connectivity error detection and auto-pause
/// - Coordination with ConnectionManager
///
/// Example usage:
/// ```swift
/// let processor = QueueProcessor()
///
/// // Start processing loop
/// await processor.startProcessing(
///     queue: jobQueue,
///     connectionManager: connectionManager
/// )
/// ```
@MainActor
public final class QueueProcessor: ObservableObject {
    /// Whether the processor is currently running.
    @Published public private(set) var isRunning: Bool = false

    private var processingTask: Task<Void, Never>?

    /// Tracks job IDs that have been processed to prevent re-processing
    private var processedJobIds: Set<UUID> = []

    public init() {}

    /// Clear the processed job IDs tracking (call when you want to allow reprocessing)
    public func clearProcessedJobIds() {
        processedJobIds.removeAll()
    }

    /// Start the processing loop.
    ///
    /// The processor will continuously check for pending jobs and process them
    /// until stopped or paused. On connectivity errors, the queue will be paused
    /// and the job will remain at the head for retry.
    ///
    /// - Parameters:
    ///   - queue: The job queue to process.
    ///   - connectionManager: The connection manager for server communication.
    public func startProcessing(
        queue: JobQueue,
        connectionManager: ConnectionManager
    ) {
        guard !isRunning else { return }

        isRunning = true

        processingTask = Task { [weak self] in
            await self?.processingLoop(queue: queue, connectionManager: connectionManager)
        }
    }

    /// Stop the processing loop.
    public func stopProcessing() {
        processingTask?.cancel()
        processingTask = nil
        isRunning = false
        processedJobIds.removeAll()
    }

    // MARK: - Processing Loop

    private func processingLoop(
        queue: JobQueue,
        connectionManager: ConnectionManager
    ) async {
        while !Task.isCancelled {
            // Check if paused
            if queue.isPaused {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                continue
            }

            // Check for connection
            guard connectionManager.connectionState.isConnected,
                  let service = connectionManager.activeService else {
                queue.pauseForReconnection(error: "Not connected to server")
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                continue
            }

            // Get next job
            guard let job = queue.nextPendingJob() else {
                // No pending jobs, wait and check again
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                continue
            }

            // Skip if we already processed this job (prevents reprocessing)
            if processedJobIds.contains(job.id) {
                // Job was already processed - just skip it, don't mark as failed
                // (it may be waiting for cleanup or the status update hasn't propagated yet)
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                continue
            }

            // Mark as processed before starting
            processedJobIds.insert(job.id)

            // Process the job
            await processJob(job, queue: queue, service: service, connectionManager: connectionManager)
        }

        isRunning = false
    }

    // MARK: - Job Processing

    private func processJob(
        _ job: GenerationJob,
        queue: JobQueue,
        service: DrawThingsService,
        connectionManager: ConnectionManager
    ) async {
        // Mark job as started
        queue.markJobStarted(job.id)

        do {
            // Parse configuration
            let config = try job.configuration()

            // Prepare canvas image if present
            var canvasImage: PlatformImage? = nil
            if let canvasData = job.canvasImageData {
                canvasImage = PlatformImage.fromData(canvasData)
            }

            // Prepare mask image if present
            var maskImage: PlatformImage? = nil
            if let maskData = job.maskImageData {
                maskImage = PlatformImage.fromData(maskData)
            }

            // Prepare hints
            var hints: [(type: String, image: PlatformImage, weight: Float)] = []
            for hint in job.hints {
                if let image = PlatformImage.fromData(hint.imageData) {
                    hints.append((type: hint.type, image: image, weight: hint.weight))
                }
            }

            // Execute generation
            // Use an actor-isolated array to safely collect results across async boundaries
            let resultCollector = ResultCollector()

            try await service.generateImageWithUpdates(
                prompt: job.prompt,
                negativePrompt: job.negativePrompt,
                configuration: config,
                canvas: canvasImage,
                mask: maskImage,
                hints: hints
            ) { [weak queue] update in
                guard let queue = queue else { return }

                switch update {
                case .progress(let current, let total, let stage):
                    Task { @MainActor in
                        let progress = JobProgress(
                            currentStep: current,
                            totalSteps: total,
                            stage: stage
                        )
                        queue.updateJobProgress(job.id, progress: progress)
                    }

                case .preview(let imageData):
                    Task { @MainActor in
                        var progress = queue.currentProgress ?? JobProgress()
                        progress.previewImageData = imageData
                        queue.updateJobProgress(job.id, progress: progress)
                    }

                case .image(let imageData):
                    // Synchronously add to collector - this runs on the same context as the callback
                    resultCollector.addResult(imageData)

                case .completed:
                    break

                case .error:
                    break
                }
            }

            // Get collected results
            let resultImages = resultCollector.getResults()

            // Check if we got any results
            if resultImages.isEmpty {
                // No images returned - treat as a failure
                queue.markJobFailed(job.id, error: "No images returned from generation")
            } else {
                // Mark job as completed with results
                queue.markJobCompleted(job.id, results: resultImages)
            }

        } catch {
            // Determine if this is a connectivity error
            let errorMessage = error.localizedDescription

            if isConnectivityError(error) {
                // Connectivity error - pause queue for reconnection
                queue.pauseForReconnection(error: "Connection lost: \(errorMessage)")

                // Remove from processed set so it can be retried after reconnection
                processedJobIds.remove(job.id)

                // Reset job to pending using the queue's method
                queue.resetJobToPending(job.id)
            } else {
                // Other error - mark job as failed
                queue.markJobFailed(job.id, error: errorMessage)
            }
        }
    }

    /// Check if an error is a connectivity error that should trigger reconnection.
    private func isConnectivityError(_ error: Error) -> Bool {
        let description = error.localizedDescription.lowercased()
        return description.contains("connection") ||
               description.contains("network") ||
               description.contains("unavailable") ||
               description.contains("timeout") ||
               description.contains("refused") ||
               description.contains("reset")
    }
}

// MARK: - Result Collector

/// Thread-safe collector for generation results.
/// Uses a lock to safely collect results from callbacks that may run on different threads.
private final class ResultCollector: @unchecked Sendable {
    private var results: [Data] = []
    private let lock = NSLock()

    func addResult(_ data: Data) {
        lock.lock()
        defer { lock.unlock() }
        results.append(data)
    }

    func getResults() -> [Data] {
        lock.lock()
        defer { lock.unlock() }
        return results
    }
}

// MARK: - Generation Update Enum

/// Updates from the generation process.
public enum GenerationUpdate {
    case progress(current: Int, total: Int, stage: String?)
    case preview(Data)
    case image(Data)
    case completed
    case error(String)
}

// MARK: - Generation Errors

public enum GenerationError: LocalizedError {
    case notConnected
    case configurationError(String)
    case serverError(String)
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected to server"
        case .configurationError(let message):
            return "Configuration error: \(message)"
        case .serverError(let message):
            return "Server error: \(message)"
        case .cancelled:
            return "Generation was cancelled"
        }
    }
}

// MARK: - DrawThingsService Extension

import DrawThingsClient

extension DrawThingsService {
    /// Generate images with progress callback.
    ///
    /// This is a convenience wrapper that handles the streaming response
    /// and calls back with progress updates.
    func generateImageWithUpdates(
        prompt: String,
        negativePrompt: String,
        configuration: DrawThingsConfiguration,
        canvas: PlatformImage?,
        mask: PlatformImage?,
        hints: [(type: String, image: PlatformImage, weight: Float)],
        onUpdate: @escaping (GenerationUpdate) -> Void
    ) async throws {
        // Serialize configuration to FlatBuffer data
        let configData = try configuration.toFlatBufferData()

        // Convert canvas image to DTTensor format (same as hints)
        var canvasData: Data? = nil
        if let canvas = canvas {
            canvasData = try? PlatformImageHelpers.imageToDTTensor(canvas, forceRGB: true)
        }

        // Convert mask image to PNG data
        var maskData: Data? = nil
        if let mask = mask {
            maskData = mask.pngData()
        }

        // Convert hints to HintProto array using DTTensor format
        var hintProtos: [HintProto] = []
        for hint in hints {
            if let tensorData = try? PlatformImageHelpers.imageToDTTensor(hint.image, forceRGB: true) {
                var hintProto = HintProto()
                hintProto.hintType = hint.type
                var tensor = TensorAndWeight()
                tensor.tensor = tensorData
                tensor.weight = hint.weight
                hintProto.tensors = [tensor]
                hintProtos.append(hintProto)
            }
        }

        // Get total steps from configuration for progress tracking
        let totalSteps = Int(configuration.steps)

        // Call the actual service method
        let results = try await generateImage(
            prompt: prompt,
            negativePrompt: negativePrompt,
            configuration: configData,
            image: canvasData,
            mask: maskData,
            hints: hintProtos,
            progressHandler: { signpost in
                if let signpost = signpost {
                    // Extract progress info from the signpost
                    var currentStep = 0
                    var stage: String? = nil

                    switch signpost.signpost {
                    case .textEncoded:
                        stage = "Text Encoding"
                    case .imageEncoded:
                        stage = "Image Encoding"
                    case .sampling(let sampling):
                        currentStep = Int(sampling.step)
                        stage = "Sampling"
                    case .imageDecoded:
                        stage = "Image Decoding"
                    case .secondPassImageEncoded:
                        stage = "Second Pass Encoding"
                    case .secondPassSampling(let sampling):
                        currentStep = Int(sampling.step)
                        stage = "Second Pass Sampling"
                    case .secondPassImageDecoded:
                        stage = "Second Pass Decoding"
                    case .faceRestored:
                        stage = "Face Restoration"
                    case .imageUpscaled:
                        stage = "Upscaling"
                    default:
                        break
                    }

                    onUpdate(.progress(
                        current: currentStep,
                        total: totalSteps,
                        stage: stage
                    ))
                }
            },
            previewHandler: { previewData in
                onUpdate(.preview(previewData))
            }
        )

        // Convert DTTensor results to PNG data
        for imageData in results {
            do {
                // Convert DTTensor format to PlatformImage
                let image = try PlatformImageHelpers.dtTensorToImage(imageData)
                // Convert to PNG data
                if let pngData = image.pngData() {
                    onUpdate(.image(pngData))
                } else {
                    onUpdate(.error("Failed to convert result image to PNG"))
                }
            } catch {
                onUpdate(.error("Failed to convert result: \(error.localizedDescription)"))
            }
        }

        onUpdate(.completed)
    }
}

