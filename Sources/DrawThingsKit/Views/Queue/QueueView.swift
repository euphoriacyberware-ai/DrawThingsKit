//
//  QueueView.swift
//  DrawThingsKit
//
//  Created by euphoriacyberware-ai.
//  Copyright © 2025 euphoriacyberware-ai
//
//  Licensed under the MIT License.
//  See LICENSE file in the project root for license information.
//

import SwiftUI

/// The main queue management view.
///
/// Displays:
/// - Current job progress with preview
/// - List of queued jobs
/// - Queue controls (play/pause, clear)
///
/// Example usage:
/// ```swift
/// QueueView(queue: jobQueue)
/// ```
public struct QueueView: View {
    @ObservedObject var queue: JobQueue

    @State private var selectedJob: GenerationJob?

    public init(queue: JobQueue) {
        self.queue = queue
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Progress section
            QueueProgressView(queue: queue)
                .padding()

            Divider()

            // Queue list
            if queue.isEmpty {
                emptyState
            } else {
                queueList
            }

            Divider()

            // Controls
            QueueControlsView(queue: queue)
                .padding()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Jobs in Queue")
                .font(.headline)

            Text("Add generation jobs to get started")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var queueList: some View {
        List {
            // Processing job (if any)
            if let current = queue.currentJob {
                Section("Processing") {
                    QueueItemRow(
                        job: current,
                        onCancel: { queue.cancel(current) }
                    )
                }
            }

            // Pending jobs
            if !queue.pendingJobs.isEmpty {
                Section("Pending (\(queue.pendingJobs.count))") {
                    ForEach(queue.pendingJobs) { job in
                        QueueItemRow(
                            job: job,
                            onCancel: { queue.cancel(job) },
                            onRemove: { queue.remove(job) }
                        )
                    }
                    .onMove { source, destination in
                        // Need to calculate actual indices in the full jobs array
                        movePendingJobs(from: source, to: destination)
                    }
                }
            }

            // Completed jobs
            if !queue.completedJobs.isEmpty {
                Section("Completed (\(queue.completedJobs.count))") {
                    ForEach(queue.completedJobs) { job in
                        QueueItemRow(
                            job: job,
                            onRemove: { queue.remove(job) }
                        )
                        .onTapGesture {
                            selectedJob = job
                        }
                    }
                }
            }

            // Failed jobs
            if !queue.failedJobs.isEmpty {
                Section("Failed (\(queue.failedJobs.count))") {
                    ForEach(queue.failedJobs) { job in
                        QueueItemRow(
                            job: job,
                            onRetry: { queue.retry(job) },
                            onRemove: { queue.remove(job) }
                        )
                    }
                }
            }
        }
        .listStyle(.inset)
    }

    private func movePendingJobs(from source: IndexSet, to destination: Int) {
        // Get the pending job indices in the full jobs array
        let pendingIndices = queue.jobs.enumerated()
            .filter { $0.element.status == .pending }
            .map { $0.offset }

        // Map source indices to actual indices
        let sourceActual = source.compactMap { pendingIndices.indices.contains($0) ? pendingIndices[$0] : nil }

        // Map destination to actual index
        let destActual: Int
        if destination >= pendingIndices.count {
            destActual = (pendingIndices.last ?? 0) + 1
        } else {
            destActual = pendingIndices[destination]
        }

        // Move in the actual array
        queue.moveJobs(from: IndexSet(sourceActual), to: destActual)
    }
}

/// A compact queue list view (no progress section).
public struct QueueListView: View {
    @ObservedObject var queue: JobQueue

    public init(queue: JobQueue) {
        self.queue = queue
    }

    public var body: some View {
        List {
            ForEach(queue.jobs) { job in
                QueueItemCompactRow(job: job)
            }
        }
        .listStyle(.plain)
    }
}

/// A sidebar-style queue view.
public struct QueueSidebarView: View {
    @ObservedObject var queue: JobQueue

    public init(queue: JobQueue) {
        self.queue = queue
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header with controls
            HStack {
                Text("Queue")
                    .font(.headline)

                Spacer()

                QueueProgressBadge(queue: queue)

                Button {
                    if queue.isPaused {
                        queue.resume()
                    } else {
                        queue.pause()
                    }
                } label: {
                    Image(systemName: queue.isPaused ? "play.fill" : "pause.fill")
                }
                .buttonStyle(.plain)
                .disabled(!queue.hasPendingJobs && !queue.isProcessing)
            }
            .padding()

            Divider()

            // Job list
            if queue.isEmpty {
                VStack {
                    Spacer()
                    Text("No jobs")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                List {
                    ForEach(queue.jobs) { job in
                        QueueItemCompactRow(job: job)
                            .contextMenu {
                                jobContextMenu(for: job)
                            }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let job = queue.jobs[index]
                            if !job.isProcessing {
                                queue.remove(job)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func jobContextMenu(for job: GenerationJob) -> some View {
        if job.isProcessing {
            Button(role: .destructive) {
                queue.cancel(job)
            } label: {
                Label("Cancel", systemImage: "stop.fill")
            }
        } else {
            if job.isFailed && job.canRetry {
                Button {
                    queue.retry(job)
                } label: {
                    Label("Retry", systemImage: "arrow.clockwise")
                }
            }

            Button(role: .destructive) {
                queue.remove(job)
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }

        if !queue.jobs.filter({ $0.status == job.status && $0.id != job.id }).isEmpty {
            Divider()

            Button(role: .destructive) {
                clearJobsWithStatus(job.status)
            } label: {
                Label("Clear All \(statusName(job.status))", systemImage: "trash.fill")
            }
        }
    }

    private func statusName(_ status: JobStatus) -> String {
        switch status {
        case .pending: return "Pending"
        case .processing: return "Processing"
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        }
    }

    private func clearJobsWithStatus(_ status: JobStatus) {
        let jobsToRemove = queue.jobs.filter { $0.status == status && !$0.isProcessing }
        for job in jobsToRemove {
            queue.remove(job)
        }
    }
}

#Preview("Queue View") {
    let queue = JobQueue()
    return QueueView(queue: queue)
        .frame(width: 400, height: 600)
}

#Preview("Queue Sidebar") {
    let queue = JobQueue()
    return QueueSidebarView(queue: queue)
        .frame(width: 250, height: 400)
}
