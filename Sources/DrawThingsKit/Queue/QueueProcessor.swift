//
//  QueueProcessor.swift
//  DrawThingsKit
//
//  Processes jobs from the queue using the Draw Things service.
//

import Foundation
import SwiftUI
import DrawThingsClient
import os.log

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

    public init() {
        DTLogger.debug("QueueProcessor initialized", category: .queue)
    }

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
        guard !isRunning else {
            DTLogger.debug("startProcessing called but already running", category: .queue)
            return
        }

        DTLogger.info("Starting queue processor", category: .queue)
        isRunning = true

        processingTask = Task { [weak self] in
            await self?.processingLoop(queue: queue, connectionManager: connectionManager)
        }
    }

    /// Stop the processing loop.
    public func stopProcessing() {
        DTLogger.info("Stopping queue processor", category: .queue)
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
        DTLogger.debug("Processing loop started", category: .queue)

        while !Task.isCancelled {
            // Check if paused
            if queue.isPaused {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                continue
            }

            // Check for connection - just wait if not connected, don't pause
            // (pauseForReconnection is only called when we lose connection during a job)
            guard connectionManager.connectionState.isConnected,
                  let service = connectionManager.activeService else {
                // Not connected - wait and check again without pausing
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

            DTLogger.info("Starting job \(job.id.uuidString.prefix(8))...", category: .queue)

            // Mark as processed before starting
            processedJobIds.insert(job.id)

            // Process the job
            await processJob(job, queue: queue, service: service, connectionManager: connectionManager)
        }

        DTLogger.debug("Processing loop ended", category: .queue)
        isRunning = false
    }

    // MARK: - Job Processing

    private func processJob(
        _ job: GenerationJob,
        queue: JobQueue,
        service: DrawThingsService,
        connectionManager: ConnectionManager
    ) async {
        let jobIdShort = String(job.id.uuidString.prefix(8))
        let endOperation = DTLogger.startOperation("Job \(jobIdShort)", category: .generation)

        // Mark job as started
        queue.markJobStarted(job.id)

        do {
            // Parse configuration
            let config = try job.configuration()

            // Log the configuration being sent
            DTLogger.debug("Job \(jobIdShort) prompt: \"\(job.prompt.prefix(100))\"", category: .generation)
            if !job.negativePrompt.isEmpty {
                DTLogger.debug("Job \(jobIdShort) negative: \"\(job.negativePrompt.prefix(100))\"", category: .generation)
            }
            DTLogger.debug("Job \(jobIdShort) model: \(config.model)", category: .generation)
            DTLogger.debug("Job \(jobIdShort) size: \(config.width)x\(config.height), steps: \(config.steps), cfg: \(config.guidanceScale)", category: .generation)

            // Log the full configuration JSON in debug builds
            if let configJSON = try? config.toJSON() {
                DTLogger.logConfiguration(configJSON, label: "Job \(jobIdShort) Configuration", category: .configuration)
            }

            // Prepare canvas image if present
            var canvasImage: PlatformImage? = nil
            if let canvasData = job.canvasImageData {
                canvasImage = PlatformImage.fromData(canvasData)
                DTLogger.debug("Job \(jobIdShort) has canvas image: \(canvasData.count) bytes", category: .generation)
            }

            // Prepare mask image if present
            var maskImage: PlatformImage? = nil
            if let maskData = job.maskImageData {
                maskImage = PlatformImage.fromData(maskData)
                DTLogger.debug("Job \(jobIdShort) has mask image: \(maskData.count) bytes", category: .generation)
            }

            // Prepare hints
            var hints: [(type: String, image: PlatformImage, weight: Float)] = []
            for hint in job.hints {
                if let image = PlatformImage.fromData(hint.imageData) {
                    hints.append((type: hint.type, image: image, weight: hint.weight))
                    DTLogger.debug("Job \(jobIdShort) has hint: \(hint.type) (weight: \(hint.weight))", category: .generation)
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
                DTLogger.error("Job \(jobIdShort) failed: No images returned from generation", category: .generation)
                queue.markJobFailed(job.id, error: "No images returned from generation")
            } else {
                // Mark job as completed with results
                let totalBytes = resultImages.reduce(0) { $0 + $1.count }
                DTLogger.info("Job \(jobIdShort) completed with \(resultImages.count) image(s), \(ByteCountFormatter.string(fromByteCount: Int64(totalBytes), countStyle: .binary))", category: .generation)
                queue.markJobCompleted(job.id, results: resultImages)
            }

            endOperation()

        } catch {
            // Determine if this is a connectivity error
            let errorMessage = error.localizedDescription

            if isConnectivityError(error) {
                // Connectivity error - pause queue for reconnection
                DTLogger.warning("Job \(jobIdShort) connectivity error: \(errorMessage)", category: .generation)
                queue.pauseForReconnection(error: "Connection lost: \(errorMessage)")

                // Remove from processed set so it can be retried after reconnection
                processedJobIds.remove(job.id)

                // Reset job to pending using the queue's method
                queue.resetJobToPending(job.id)
            } else {
                // Other error - mark job as failed
                DTLogger.error("Job \(jobIdShort) failed: \(errorMessage)", category: .generation)
                queue.markJobFailed(job.id, error: errorMessage)
            }

            endOperation()
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
        DTLogger.debug("Preparing gRPC request...", category: .grpc)

        // Serialize configuration to FlatBuffer data
        let configData = try configuration.toFlatBufferData()
        DTLogger.logData(configData, label: "Configuration FlatBuffer", category: .grpc)

        // Convert canvas image to DTTensor format (same as hints)
        var canvasData: Data? = nil
        if let canvas = canvas {
            canvasData = try? PlatformImageHelpers.imageToDTTensor(canvas, forceRGB: true)
            if let data = canvasData {
                DTLogger.debug("Canvas DTTensor: \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .binary))", category: .grpc)
            }
        }

        // Convert mask image to PNG data
        var maskData: Data? = nil
        if let mask = mask {
            maskData = mask.pngData()
            if let data = maskData {
                DTLogger.debug("Mask PNG: \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .binary))", category: .grpc)
            }
        }

        // Convert hints to HintProto array using DTTensor format
        // Group hints by type (like ComfyUI does) - one HintProto per type with multiple tensors
        var hintsByType: [String: [TensorAndWeight]] = [:]
        for hint in hints {
            if let tensorData = try? PlatformImageHelpers.imageToDTTensor(hint.image, forceRGB: true) {
                var tensor = TensorAndWeight()
                tensor.tensor = tensorData
                tensor.weight = hint.weight
                hintsByType[hint.type, default: []].append(tensor)
                DTLogger.debug("Hint '\(hint.type)' DTTensor: \(ByteCountFormatter.string(fromByteCount: Int64(tensorData.count), countStyle: .binary)) (weight: \(hint.weight))", category: .grpc)
            }
        }

        // Build HintProto array - one per hint type
        var hintProtos: [HintProto] = []
        for (hintType, tensors) in hintsByType {
            var hintProto = HintProto()
            hintProto.hintType = hintType
            hintProto.tensors = tensors
            hintProtos.append(hintProto)
            DTLogger.debug("HintProto '\(hintType)' with \(tensors.count) tensor(s)", category: .grpc)
        }

        // Get total steps from configuration for progress tracking
        let totalSteps = Int(configuration.steps)

        DTLogger.info("Sending gRPC generateImage request (prompt: \(prompt.count) chars, config: \(configData.count) bytes)", category: .grpc)

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

        DTLogger.info("gRPC request returned \(results.count) result(s)", category: .grpc)

        // Convert DTTensor results to PNG data
        for (index, imageData) in results.enumerated() {
            DTLogger.debug("Processing result \(index + 1): DTTensor \(ByteCountFormatter.string(fromByteCount: Int64(imageData.count), countStyle: .binary))", category: .grpc)
            do {
                // Convert DTTensor format to PlatformImage
                let image = try PlatformImageHelpers.dtTensorToImage(imageData)
                // Convert to PNG data
                if let pngData = image.pngData() {
                    DTLogger.debug("Result \(index + 1) converted to PNG: \(ByteCountFormatter.string(fromByteCount: Int64(pngData.count), countStyle: .binary))", category: .grpc)
                    onUpdate(.image(pngData))
                } else {
                    DTLogger.error("Result \(index + 1): Failed to convert to PNG", category: .grpc)
                    onUpdate(.error("Failed to convert result image to PNG"))
                }
            } catch {
                DTLogger.error("Result \(index + 1) conversion failed: \(error.localizedDescription)", category: .grpc)
                onUpdate(.error("Failed to convert result: \(error.localizedDescription)"))
            }
        }

        DTLogger.debug("gRPC request completed", category: .grpc)
        onUpdate(.completed)
    }
}

