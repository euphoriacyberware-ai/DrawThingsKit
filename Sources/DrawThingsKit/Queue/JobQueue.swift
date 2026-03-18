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
import DrawThingsClient
import DrawThingsQueue

#if os(macOS)
import AppKit
#else
import UIKit
#endif

// The DrawThingsQueue module has a class also named DrawThingsQueue,
// so we can't use module-qualified names like "DrawThingsQueue.JobEvent".
// The Queue's JobEvent is imported unqualified; our local JobEvent is defined below.
// We reference the Queue's JobEvent through the queue.events publisher type.

// MARK: - Job Events

/// Events emitted by the job queue for easy observation.
public enum JobEvent {
    case jobAdded(GenerationJob)
    case jobStarted(GenerationJob)
    case jobProgress(GenerationJob, JobProgress)
    case jobCompleted(GenerationJob, images: [PlatformImage], audioData: [Data])
    case jobFailed(GenerationJob, error: String)
    case jobCancelled(GenerationJob)
    case jobRemoved(UUID)
}

/// Manages the queue of generation jobs.
///
/// This class wraps `DrawThingsQueue` and presents a view-model layer using
/// `GenerationJob` structs for SwiftUI views. It translates between
/// DrawThingsQueue's event-driven model and a unified job list.
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
    @Published public private(set) var isPaused: Bool = false

    /// Preview image from the current job.
    @Published public private(set) var currentPreview: PlatformImage?

    /// Progress of the current job.
    @Published public private(set) var currentProgress: JobProgress?

    /// Error message if queue processing encountered an error.
    @Published public private(set) var lastError: String?

    // MARK: - Event Publisher

    public let events = PassthroughSubject<JobEvent, Never>()

    // MARK: - Internal Queue

    /// The underlying DrawThingsQueue instance.
    public let queue: DrawThingsQueue

    private var cancellables = Set<AnyCancellable>()

    /// Tracks cancelled IDs for view-model purposes.
    private var cancelledRequests: [UUID: GenerationRequest] = [:]

    // MARK: - Initialization

    /// Initialize with an existing DrawThingsQueue.
    public init(queue: DrawThingsQueue) {
        self.queue = queue
        subscribeToQueue()
    }

    // MARK: - Computed Properties

    public var pendingJobs: [GenerationJob] {
        jobs.filter { $0.status == .pending }
    }

    public var completedJobs: [GenerationJob] {
        jobs.filter { $0.status == .completed }
    }

    public var failedJobs: [GenerationJob] {
        jobs.filter { $0.status == .failed }
    }

    public var pendingCount: Int { pendingJobs.count }
    public var processingCount: Int { jobs.filter { $0.status == .processing }.count }
    public var activeQueueCount: Int { jobs.filter { $0.isPending || $0.isProcessing }.count }
    public var hasPendingJobs: Bool { !pendingJobs.isEmpty }
    public var isEmpty: Bool { jobs.isEmpty }

    // MARK: - Queue Operations

    /// Enqueue a GenerationRequest directly.
    public func enqueue(_ request: GenerationRequest) {
        queue.enqueue(request)
    }

    /// Enqueue multiple requests.
    public func enqueue(_ requests: [GenerationRequest]) {
        queue.enqueue(requests)
    }

    /// Remove a job.
    public func remove(_ job: GenerationJob) {
        guard currentJob?.id != job.id else { return }
        queue.remove(job.id)
        jobs.removeAll { $0.id == job.id }
    }

    /// Cancel a job.
    public func cancel(_ job: GenerationJob) {
        // Store the request info for cancelled event before it's removed
        if let request = findRequest(for: job.id) {
            cancelledRequests[job.id] = request
        }
        queue.cancel(id: job.id)
    }

    /// Move jobs in the pending list.
    public func moveJobs(from source: IndexSet, to destination: Int) {
        queue.moveRequests(from: source, to: destination)
    }

    /// Retry a failed job.
    public func retry(_ job: GenerationJob) {
        queue.retry(job.id)
    }

    /// Clear all completed jobs.
    public func clearCompleted() {
        queue.clearCompleted()
        jobs.removeAll { $0.status == .completed }
    }

    /// Clear all failed jobs.
    public func clearFailed() {
        queue.clearErrors()
        jobs.removeAll { $0.status == .failed || $0.status == .cancelled }
    }

    /// Clear all finished jobs.
    public func clearFinished() {
        queue.clearCompleted()
        queue.clearErrors()
        jobs.removeAll { $0.isFinished }
    }

    /// Clear all jobs.
    public func clearAll() {
        queue.clearAll()
        jobs.removeAll()
        currentJob = nil
        currentProgress = nil
        currentPreview = nil
    }

    // MARK: - Queue Control

    public func pause() {
        queue.pause()
    }

    public func resume() {
        queue.resume()
    }

    // MARK: - Private

    private func findRequest(for id: UUID) -> GenerationRequest? {
        if let current = queue.currentRequest, current.id == id {
            return current
        }
        return queue.pendingRequests.first { $0.id == id }
    }

    private func subscribeToQueue() {
        // Sync published state from the underlying queue
        queue.$isPaused.assign(to: &$isPaused)
        queue.$isProcessing.assign(to: &$isProcessing)
        queue.$lastError.assign(to: &$lastError)

        // Sync preview from progress
        queue.$currentProgress
            .sink { [weak self] progress in
                self?.currentPreview = progress?.previewImage
                if let progress {
                    self?.currentProgress = JobProgress(from: progress)
                } else {
                    self?.currentProgress = nil
                }
            }
            .store(in: &cancellables)

        // Subscribe to queue events and translate to Kit's JobEvent
        queue.events
            .sink { [weak self] event in
                guard let self else { return }
                switch event {
                case .requestAdded(let request):
                    self.onRequestAdded(request)
                case .requestStarted(let request):
                    self.onRequestStarted(request)
                case .requestProgress(let request, let progress):
                    self.onRequestProgress(request, progress)
                case .requestCompleted(let result):
                    self.onRequestCompleted(result)
                case .requestFailed(let error):
                    self.onRequestFailed(error)
                case .requestCancelled(let id):
                    self.onRequestCancelled(id)
                case .requestRemoved(let id):
                    self.onRequestRemoved(id)
                }
            }
            .store(in: &cancellables)
    }

    private func onRequestAdded(_ request: GenerationRequest) {
        let job = GenerationJob.fromRequest(request)
        jobs.append(job)
        events.send(.jobAdded(job))
    }

    private func onRequestStarted(_ request: GenerationRequest) {
        var job = GenerationJob.fromRequest(request)
        job.status = JobStatus.processing
        job.startedAt = Date()
        upsertJob(job)
        currentJob = job
        events.send(.jobStarted(job))
    }

    private func onRequestProgress(_ request: GenerationRequest, _ progress: GenerationProgress) {
        let jobProgress = JobProgress(from: progress)
        if let index = jobs.firstIndex(where: { $0.id == request.id }) {
            jobs[index].progress = jobProgress
            let job = jobs[index]
            events.send(.jobProgress(job, jobProgress))
        }
    }

    private func onRequestCompleted(_ result: GenerationResult) {
        let job = GenerationJob.fromResult(result)
        upsertJob(job)
        currentJob = nil
        events.send(.jobCompleted(job, images: result.images, audioData: result.audioData))
    }

    private func onRequestFailed(_ error: GenerationError) {
        let job = GenerationJob.fromError(error)
        upsertJob(job)
        currentJob = nil
        events.send(.jobFailed(job, error: error.underlyingError.localizedDescription))
    }

    private func onRequestCancelled(_ id: UUID) {
        if let index = jobs.firstIndex(where: { $0.id == id }) {
            jobs[index].status = JobStatus.cancelled
            jobs[index].completedAt = Date()
            let job = jobs[index]
            if currentJob?.id == id {
                currentJob = nil
            }
            events.send(.jobCancelled(job))
        } else if let request = cancelledRequests.removeValue(forKey: id) {
            var job = GenerationJob.fromRequest(request)
            job.status = JobStatus.cancelled
            job.completedAt = Date()
            jobs.append(job)
            events.send(.jobCancelled(job))
        }
    }

    private func onRequestRemoved(_ id: UUID) {
        jobs.removeAll { $0.id == id }
        events.send(.jobRemoved(id))
    }

    private func upsertJob(_ job: GenerationJob) {
        if let index = jobs.firstIndex(where: { $0.id == job.id }) {
            jobs[index] = job
        } else {
            jobs.append(job)
        }
    }
}
