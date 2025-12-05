//
//  JobQueue.swift
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

#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Job Events

/// Events emitted by the job queue for easy observation.
public enum JobEvent {
    /// A job was added to the queue
    case jobAdded(GenerationJob)
    /// A job started processing
    case jobStarted(GenerationJob)
    /// A job's progress was updated
    case jobProgress(GenerationJob, JobProgress)
    /// A job completed successfully with result images (as native PlatformImage)
    case jobCompleted(GenerationJob, images: [PlatformImage])
    /// A job failed with an error message
    case jobFailed(GenerationJob, error: String)
    /// A job was cancelled
    case jobCancelled(GenerationJob)
    /// A job was removed from the queue
    case jobRemoved(UUID)
}

/// Manages the queue of generation jobs.
///
/// Provides:
/// - Job enqueueing and removal
/// - Queue ordering (drag to reorder)
/// - Pause/resume functionality
/// - Current job and progress tracking
/// - Persistence through QueueStorage
/// - Event publisher for job lifecycle events
///
/// Example usage:
/// ```swift
/// @StateObject private var queue = JobQueue()
///
/// // Add a job
/// try queue.enqueue(job)
///
/// // Start processing
/// queue.resume()
///
/// // Listen for job events
/// queue.events
///     .sink { event in
///         switch event {
///         case .jobCompleted(let job, let results):
///             // Handle completed job
///         case .jobFailed(let job, let error):
///             // Handle failed job
///         default:
///             break
///         }
///     }
///     .store(in: &cancellables)
/// ```
@MainActor
public final class JobQueue: ObservableObject {
    // MARK: - Published Properties

    /// All jobs in the queue (pending, processing, completed, failed).
    @Published public private(set) var jobs: [GenerationJob] = []

    /// The currently processing job, if any.
    @Published public private(set) var currentJob: GenerationJob?

    /// Whether the queue is actively processing.
    @Published public private(set) var isProcessing: Bool = false

    /// Whether the queue is paused.
    /// Defaults to `false` (ready to process). The queue will automatically start
    /// processing when jobs are added and a connection is available.
    /// Call `pause()` during app initialization if you want the queue to start paused.
    @Published public private(set) var isPaused: Bool = false

    /// Preview image from the current job.
    @Published public private(set) var currentPreview: PlatformImage?

    /// Progress of the current job.
    @Published public private(set) var currentProgress: JobProgress?

    /// Error message if queue processing encountered an error.
    @Published public private(set) var lastError: String?

    // MARK: - Event Publisher

    /// Publisher for job lifecycle events.
    /// Subscribe to this to be notified when jobs complete, fail, etc.
    public let events = PassthroughSubject<JobEvent, Never>()

    // MARK: - Private Properties

    private let storage: QueueStorage
    private var processingTask: Task<Void, Never>?

    /// Optional ModelsManager for accurate model family detection in previews.
    /// If provided, uses the version field from the model catalog for better latent-to-RGB conversion.
    public weak var modelsManager: ModelsManager?

    // MARK: - Initialization

    /// Initialize with optional custom storage and models manager.
    /// - Parameters:
    ///   - storage: Storage for job persistence
    ///   - modelsManager: Optional ModelsManager for accurate model family detection in previews
    public init(storage: QueueStorage = QueueStorage(), modelsManager: ModelsManager? = nil) {
        self.storage = storage
        self.modelsManager = modelsManager
        loadJobs()
    }

    // MARK: - Computed Properties

    /// Jobs that are waiting to be processed.
    public var pendingJobs: [GenerationJob] {
        jobs.filter { $0.status == .pending }
    }

    /// Jobs that have completed successfully.
    public var completedJobs: [GenerationJob] {
        jobs.filter { $0.status == .completed }
    }

    /// Jobs that failed.
    public var failedJobs: [GenerationJob] {
        jobs.filter { $0.status == .failed }
    }

    /// Number of pending jobs.
    public var pendingCount: Int {
        pendingJobs.count
    }

    /// Number of jobs currently processing.
    public var processingCount: Int {
        jobs.filter { $0.status == .processing }.count
    }

    /// Number of jobs in the active queue (pending + processing).
    /// Useful for displaying a badge count in UI.
    public var activeQueueCount: Int {
        jobs.filter { $0.status == .pending || $0.status == .processing }.count
    }

    /// Whether there are jobs waiting to be processed.
    public var hasPendingJobs: Bool {
        !pendingJobs.isEmpty
    }

    /// Whether the queue is empty.
    public var isEmpty: Bool {
        jobs.isEmpty
    }

    // MARK: - Queue Operations

    /// Add a job to the queue.
    ///
    /// If the job's seed is nil or negative (random), a random seed will be generated
    /// client-side so the seed value is known and can be displayed in results.
    ///
    /// - Parameter job: The job to add.
    public func enqueue(_ job: GenerationJob) {
        var newJob = job
        newJob.status = .pending

        // Generate random seed if needed
        newJob = assignRandomSeedIfNeeded(newJob)

        jobs.append(newJob)
        saveJobs()
        events.send(.jobAdded(newJob))
    }

    /// Add multiple jobs to the queue.
    ///
    /// If any job's seed is nil or negative (random), a random seed will be generated
    /// client-side so the seed value is known and can be displayed in results.
    ///
    /// - Parameter newJobs: The jobs to add.
    public func enqueue(_ newJobs: [GenerationJob]) {
        for var job in newJobs {
            job.status = .pending
            job = assignRandomSeedIfNeeded(job)
            jobs.append(job)
            events.send(.jobAdded(job))
        }
        saveJobs()
    }

    /// Assigns a random seed to a job if its current seed is nil or negative.
    ///
    /// Draw Things uses -1 (or nil) to indicate "server should generate random seed",
    /// but this means we don't know what seed was used. By generating the seed
    /// client-side, we can display it in the results and allow reproduction.
    ///
    /// - Parameter job: The job to check and potentially modify.
    /// - Returns: The job with a random seed assigned if needed.
    private func assignRandomSeedIfNeeded(_ job: GenerationJob) -> GenerationJob {
        guard var config = try? job.configuration() else {
            return job
        }

        // Check if seed needs to be randomized
        // nil or negative values indicate "random"
        if config.seed == nil || config.seed! < 0 {
            // Generate a random seed (UInt32 range to match Draw Things)
            let randomSeed = Int64(arc4random())
            config.seed = randomSeed

            // Update the job with the new configuration
            if let updatedJSON = try? config.toJSON() {
                var updatedJob = job
                updatedJob.configurationJSON = updatedJSON
                DTLogger.debug("Assigned random seed \(randomSeed) to job \(job.id)", category: .queue)
                return updatedJob
            }
        }

        return job
    }

    /// Remove a job from the queue.
    /// - Parameter job: The job to remove.
    public func remove(_ job: GenerationJob) {
        // Can't remove the currently processing job
        guard currentJob?.id != job.id else { return }

        let jobId = job.id
        jobs.removeAll { $0.id == jobId }
        saveJobs()
        events.send(.jobRemoved(jobId))
    }

    /// Cancel a job.
    /// - Parameter job: The job to cancel.
    public func cancel(_ job: GenerationJob) {
        guard let index = jobs.firstIndex(where: { $0.id == job.id }) else { return }

        if currentJob?.id == job.id {
            // Cancel the current processing task
            processingTask?.cancel()
            jobs[index].status = .cancelled
            jobs[index].completedAt = Date()
            currentJob = nil
            isProcessing = false
            currentProgress = nil
            currentPreview = nil
        } else if jobs[index].status == .pending {
            jobs[index].status = .cancelled
            jobs[index].completedAt = Date()
        }

        saveJobs()
        events.send(.jobCancelled(jobs[index]))
    }

    /// Move a job in the queue.
    /// - Parameters:
    ///   - source: Source indices.
    ///   - destination: Destination index.
    public func moveJobs(from source: IndexSet, to destination: Int) {
        jobs.move(fromOffsets: source, toOffset: destination)
        saveJobs()
    }

    /// Retry a failed job.
    /// - Parameter job: The job to retry.
    public func retry(_ job: GenerationJob) {
        guard let index = jobs.firstIndex(where: { $0.id == job.id }),
              jobs[index].canRetry else { return }

        jobs[index].status = .pending
        jobs[index].errorMessage = nil
        jobs[index].retryCount += 1
        jobs[index].startedAt = nil
        jobs[index].completedAt = nil
        saveJobs()
    }

    /// Clear all completed jobs.
    public func clearCompleted() {
        jobs.removeAll { $0.status == .completed }
        saveJobs()
    }

    /// Clear all failed jobs.
    public func clearFailed() {
        jobs.removeAll { $0.status == .failed || $0.status == .cancelled }
        saveJobs()
    }

    /// Clear all finished jobs (completed, failed, cancelled).
    public func clearFinished() {
        jobs.removeAll { $0.isFinished }
        saveJobs()
    }

    /// Clear all jobs and stop processing.
    public func clearAll() {
        pause()
        processingTask?.cancel()
        jobs.removeAll()
        currentJob = nil
        currentProgress = nil
        currentPreview = nil
        saveJobs()
    }

    // MARK: - Queue Control

    /// Pause the queue.
    public func pause() {
        isPaused = true
    }

    /// Resume the queue.
    public func resume() {
        isPaused = false
        lastError = nil
    }

    /// Pause due to connectivity issues (will auto-resume on reconnect).
    public func pauseForReconnection(error: String) {
        isPaused = true
        lastError = error
    }

    // MARK: - Job Processing (called by QueueProcessor)

    /// Mark a job as started.
    func markJobStarted(_ jobId: UUID) {
        guard let index = jobs.firstIndex(where: { $0.id == jobId }) else { return }

        jobs[index].status = .processing
        jobs[index].startedAt = Date()
        jobs[index].progress = JobProgress()
        currentJob = jobs[index]
        isProcessing = true
        currentProgress = jobs[index].progress
        saveJobs()
        events.send(.jobStarted(jobs[index]))
    }

    /// Update progress for a job.
    func updateJobProgress(_ jobId: UUID, progress: JobProgress) {
        guard let index = jobs.firstIndex(where: { $0.id == jobId }) else { return }

        var updatedProgress = progress

        // Update preview image if available (convert from DTTensor format)
        if let previewData = progress.previewImageData {
            // Detect model family from configuration for correct latent-to-RGB conversion
            var modelFamily: LatentModelFamily? = nil
            if let config = try? jobs[index].configuration() {
                // Try to use ModelsManager for accurate version-based detection
                if let manager = modelsManager {
                    let version = manager.version(forFile: config.model)
                    modelFamily = manager.latentModelFamily(forFile: config.model)
                    DTLogger.debug("Preview conversion: model='\(config.model)', version='\(version ?? "nil")', family=\(modelFamily ?? .unknown)", category: .generation)
                } else {
                    // Fall back to filename-based detection
                    modelFamily = LatentModelFamily.detect(from: config.model)
                    DTLogger.debug("Preview conversion (no ModelsManager): model='\(config.model)', family=\(modelFamily ?? .unknown)", category: .generation)
                }
            } else {
                DTLogger.debug("Preview conversion: failed to get configuration from job", category: .generation)
            }

            if let image = try? PlatformImageHelpers.dtTensorToImage(previewData, modelFamily: modelFamily) {
                currentPreview = image
                updatedProgress.previewImage = image
            }
        }

        jobs[index].progress = updatedProgress
        currentProgress = updatedProgress

        events.send(.jobProgress(jobs[index], updatedProgress))
    }

    /// Mark a job as completed with results.
    /// - Parameters:
    ///   - jobId: The job ID
    ///   - results: Result images as PNG data
    func markJobCompleted(_ jobId: UUID, results: [Data]) {
        guard let index = jobs.firstIndex(where: { $0.id == jobId }) else { return }

        jobs[index].status = .completed
        jobs[index].completedAt = Date()
        jobs[index].resultImageData = results
        jobs[index].errorMessage = nil

        let completedJob = jobs[index]

        if currentJob?.id == jobId {
            currentJob = nil
            isProcessing = false
            currentProgress = nil
            currentPreview = nil
        }

        saveJobs()

        // Convert PNG data to PlatformImages for the event
        let images = results.compactMap { PlatformImage.fromData($0) }
        events.send(.jobCompleted(completedJob, images: images))
    }

    /// Mark a job as failed.
    func markJobFailed(_ jobId: UUID, error: String) {
        guard let index = jobs.firstIndex(where: { $0.id == jobId }) else { return }

        jobs[index].status = .failed
        jobs[index].completedAt = Date()
        jobs[index].errorMessage = error

        let failedJob = jobs[index]

        if currentJob?.id == jobId {
            currentJob = nil
            isProcessing = false
            currentProgress = nil
            currentPreview = nil
        }

        saveJobs()
        events.send(.jobFailed(failedJob, error: error))
    }

    /// Get the next pending job.
    func nextPendingJob() -> GenerationJob? {
        jobs.first { $0.status == .pending }
    }

    /// Reset a job to pending status (for retry after connectivity errors).
    func resetJobToPending(_ jobId: UUID) {
        guard let index = jobs.firstIndex(where: { $0.id == jobId }) else { return }

        jobs[index].status = .pending
        jobs[index].startedAt = nil
        jobs[index].progress = nil

        if currentJob?.id == jobId {
            currentJob = nil
            isProcessing = false
            currentProgress = nil
            currentPreview = nil
        }

        saveJobs()
    }

    // MARK: - Persistence

    private func loadJobs() {
        jobs = storage.loadJobs()

        // Reset any jobs that were processing when the app quit
        for index in jobs.indices {
            if jobs[index].status == .processing {
                jobs[index].status = .pending
                jobs[index].startedAt = nil
                jobs[index].progress = nil
            }
        }
    }

    private func saveJobs() {
        storage.saveJobs(jobs)
    }
}
