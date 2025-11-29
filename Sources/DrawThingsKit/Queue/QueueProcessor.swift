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
        print("QueueProcessor[\(ObjectIdentifier(self))]: startProcessing called, isRunning=\(isRunning)")
        guard !isRunning else {
            print("QueueProcessor[\(ObjectIdentifier(self))]: Already running, skipping")
            return
        }

        isRunning = true
        print("QueueProcessor[\(ObjectIdentifier(self))]: Starting processing loop")

        processingTask = Task { [weak self] in
            await self?.processingLoop(queue: queue, connectionManager: connectionManager)
        }
    }

    /// Stop the processing loop.
    public func stopProcessing() {
        processingTask?.cancel()
        processingTask = nil
        isRunning = false
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

            print("QueueProcessor: Found pending job \(job.id), status=\(job.status)")
            print("QueueProcessor: processedJobIds count=\(processedJobIds.count), contains job=\(processedJobIds.contains(job.id))")
            print("QueueProcessor: Queue has \(queue.jobs.count) jobs, \(queue.pendingJobs.count) pending")

            // Skip if we already processed this job (prevents infinite loops)
            if processedJobIds.contains(job.id) {
                print("QueueProcessor: Skipping already-processed job \(job.id)")
                // Mark the job as failed to break the loop
                queue.markJobFailed(job.id, error: "Job was already processed")
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                continue
            }

            // Mark as processed before starting
            processedJobIds.insert(job.id)
            print("QueueProcessor: Starting to process job \(job.id)")

            // Process the job
            await processJob(job, queue: queue, service: service, connectionManager: connectionManager)
            print("QueueProcessor: Finished processing job \(job.id)")
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

                case .error(let error):
                    print("Generation error: \(error)")
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

        // Debug logging
        print("=== Sending to DrawThings ===")
        print("Prompt: \(prompt)")
        print("Negative: \(negativePrompt)")
        print("Model: \(configuration.model)")
        print("Size: \(configuration.width)x\(configuration.height)")
        print("Steps: \(configuration.steps)")
        print("Sampler: \(configuration.sampler) (raw: \(configuration.sampler.rawValue))")
        print("Guidance: \(configuration.guidanceScale)")
        print("Seed: \(configuration.seed ?? -1)")
        print("Shift: \(configuration.shift)")
        print("Upscaler: \(configuration.upscaler ?? "nil")")
        print("UpscalerScaleFactor: \(configuration.upscalerScaleFactor)")
        print("LoRAs: \(configuration.loras.count)")
        for (i, lora) in configuration.loras.enumerated() {
            print("  LoRA[\(i)]: \(lora.file), weight=\(lora.weight), mode=\(lora.mode)")
        }
        print("Controls: \(configuration.controls.count)")
        for (i, control) in configuration.controls.enumerated() {
            print("  Control[\(i)]: \(control.file), weight=\(control.weight), mode=\(control.controlMode)")
            print("    guidanceStart=\(control.guidanceStart), guidanceEnd=\(control.guidanceEnd)")
        }

        // Warning: Controls may require corresponding hint images
        if !configuration.controls.isEmpty && hints.isEmpty {
            print("⚠️ WARNING: Configuration has \(configuration.controls.count) control(s) but no hints were provided.")
            print("   Controls like PuLID/IP-Adapter require input images sent as hints.")
        }
        print("Config size: \(configData.count) bytes")
        print("Canvas: \(canvas != nil ? "yes" : "no")")
        print("Mask: \(mask != nil ? "yes" : "no")")
        print("Hints: \(hints.count)")
        print("==============================")

        // Convert canvas image to DTTensor format (same as hints)
        var canvasData: Data? = nil
        if let canvas = canvas {
            do {
                canvasData = try PlatformImageHelpers.imageToDTTensor(canvas, forceRGB: true)
                print("  Canvas image: \(canvas.pixelWidth)x\(canvas.pixelHeight) -> \(canvasData?.count ?? 0) bytes DTTensor")
            } catch {
                print("  Failed to convert canvas to DTTensor: \(error)")
            }
        }

        // Convert mask image to PNG data
        var maskData: Data? = nil
        if let mask = mask {
            maskData = mask.pngData()
        }

        // Convert hints to HintProto array using DTTensor format
        var hintProtos: [HintProto] = []
        for hint in hints {
            do {
                let tensorData = try PlatformImageHelpers.imageToDTTensor(hint.image, forceRGB: true)
                var hintProto = HintProto()
                hintProto.hintType = hint.type
                var tensor = TensorAndWeight()
                tensor.tensor = tensorData
                tensor.weight = hint.weight
                hintProto.tensors = [tensor]
                hintProtos.append(hintProto)
                print("  Hint converted to DTTensor: \(tensorData.count) bytes")
            } catch {
                print("  Failed to convert hint to DTTensor: \(error)")
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
        print("  Received \(results.count) result image(s)")
        for (index, imageData) in results.enumerated() {
            print("  Processing result \(index + 1): \(imageData.count) bytes")

            // Debug: Print DTTensor header
            if imageData.count >= 68 {
                imageData.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
                    let uint32Ptr = ptr.bindMemory(to: UInt32.self)
                    let compression = uint32Ptr[0]
                    let height = uint32Ptr[6]
                    let width = uint32Ptr[7]
                    let channels = uint32Ptr[8]
                    print("    DTTensor header: \(width)x\(height), \(channels) channels, compression=\(compression)")

                    let expectedSize = 68 + Int(width) * Int(height) * Int(channels) * 2
                    print("    Expected size: \(expectedSize) bytes, actual: \(imageData.count) bytes")
                }
            }

            do {
                // Convert DTTensor format to PlatformImage
                let image = try PlatformImageHelpers.dtTensorToImage(imageData)
                // Convert to PNG data
                if let pngData = image.pngData() {
                    print("    Converted to PNG: \(pngData.count) bytes")
                    onUpdate(.image(pngData))
                } else {
                    print("    Failed to convert result image to PNG")
                    onUpdate(.error("Failed to convert result image to PNG"))
                }
            } catch {
                print("    Failed to convert DTTensor result: \(error)")
                onUpdate(.error("Failed to convert result: \(error.localizedDescription)"))
            }
        }

        onUpdate(.completed)
    }
}

