//
//  JobQueue.swift
//  DrawThingsKit
//
//  Observable queue state management for generation jobs.
//

import Foundation
import SwiftUI
import Combine

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Manages the queue of generation jobs.
///
/// Provides:
/// - Job enqueueing and removal
/// - Queue ordering (drag to reorder)
/// - Pause/resume functionality
/// - Current job and progress tracking
/// - Persistence through QueueStorage
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
    @Published public private(set) var isPaused: Bool = true

    /// Preview image from the current job.
    @Published public private(set) var currentPreview: PlatformImage?

    /// Progress of the current job.
    @Published public private(set) var currentProgress: JobProgress?

    /// Error message if queue processing encountered an error.
    @Published public private(set) var lastError: String?

    // MARK: - Private Properties

    private let storage: QueueStorage
    private var processingTask: Task<Void, Never>?

    // MARK: - Initialization

    /// Initialize with optional custom storage.
    public init(storage: QueueStorage = QueueStorage()) {
        self.storage = storage
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
    /// - Parameter job: The job to add.
    public func enqueue(_ job: GenerationJob) {
        var newJob = job
        newJob.status = .pending
        jobs.append(newJob)
        saveJobs()
    }

    /// Add multiple jobs to the queue.
    /// - Parameter newJobs: The jobs to add.
    public func enqueue(_ newJobs: [GenerationJob]) {
        for var job in newJobs {
            job.status = .pending
            jobs.append(job)
        }
        saveJobs()
    }

    /// Remove a job from the queue.
    /// - Parameter job: The job to remove.
    public func remove(_ job: GenerationJob) {
        // Can't remove the currently processing job
        guard currentJob?.id != job.id else { return }

        jobs.removeAll { $0.id == job.id }
        saveJobs()
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
    }

    /// Update progress for a job.
    func updateJobProgress(_ jobId: UUID, progress: JobProgress) {
        guard let index = jobs.firstIndex(where: { $0.id == jobId }) else { return }

        jobs[index].progress = progress
        currentProgress = progress

        // Update preview image if available (convert from DTTensor format)
        if let previewData = progress.previewImageData {
            if let image = try? PlatformImageHelpers.dtTensorToImage(previewData) {
                currentPreview = image
            }
        }
    }

    /// Mark a job as completed with results.
    func markJobCompleted(_ jobId: UUID, results: [Data]) {
        guard let index = jobs.firstIndex(where: { $0.id == jobId }) else { return }

        jobs[index].status = .completed
        jobs[index].completedAt = Date()
        jobs[index].resultImages = results
        jobs[index].errorMessage = nil

        if currentJob?.id == jobId {
            currentJob = nil
            isProcessing = false
            currentProgress = nil
            currentPreview = nil
        }

        saveJobs()
    }

    /// Mark a job as failed.
    func markJobFailed(_ jobId: UUID, error: String) {
        guard let index = jobs.firstIndex(where: { $0.id == jobId }) else { return }

        jobs[index].status = .failed
        jobs[index].completedAt = Date()
        jobs[index].errorMessage = error

        if currentJob?.id == jobId {
            currentJob = nil
            isProcessing = false
            currentProgress = nil
            currentPreview = nil
        }

        saveJobs()
    }

    /// Get the next pending job.
    func nextPendingJob() -> GenerationJob? {
        jobs.first { $0.status == .pending }
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
