//
//  QueueProgressView.swift
//  DrawThingsKit
//
//  View for displaying current job progress with preview.
//

import SwiftUI

/// A view showing the progress of the current job with preview image.
public struct QueueProgressView: View {
    @ObservedObject var queue: JobQueue

    public init(queue: JobQueue) {
        self.queue = queue
    }

    public var body: some View {
        VStack(spacing: 12) {
            if let job = queue.currentJob {
                // Preview image
                previewSection

                // Job info
                VStack(spacing: 8) {
                    Text(job.name)
                        .font(.headline)
                        .lineLimit(1)

                    if let progress = queue.currentProgress {
                        // Progress bar
                        ProgressView(value: progress.progressFraction)

                        // Progress details
                        HStack {
                            if let stage = progress.stage {
                                Text(stage)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Text("\(progress.currentStep)/\(progress.totalSteps)")
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundColor(.secondary)

                            Text("(\(progress.progressPercentage)%)")
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundColor(.secondary)
                        }
                    } else {
                        // Indeterminate progress
                        ProgressView()
                            .controlSize(.small)

                        Text("Starting...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else if queue.isPaused {
                pausedView
            } else {
                idleView
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    @ViewBuilder
    private var previewSection: some View {
        if let preview = queue.currentPreview {
            Image(nsImage: preview)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 200)
                .cornerRadius(4)
        } else {
            // Placeholder
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.secondary.opacity(0.1))
                .frame(height: 150)
                .overlay(
                    VStack(spacing: 8) {
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("Preview will appear here")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                )
        }
    }

    private var pausedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "pause.circle")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text("Queue Paused")
                .font(.headline)

            if let error = queue.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            } else {
                Text("Press play to start processing")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    private var idleView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text(queue.hasPendingJobs ? "Ready" : "Queue Empty")
                .font(.headline)

            Text(queue.hasPendingJobs ?
                 "\(queue.pendingCount) job\(queue.pendingCount == 1 ? "" : "s") waiting" :
                 "Add jobs to get started")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}

/// A compact progress indicator for use in toolbars or status bars.
public struct QueueProgressBadge: View {
    @ObservedObject var queue: JobQueue

    public init(queue: JobQueue) {
        self.queue = queue
    }

    public var body: some View {
        HStack(spacing: 6) {
            if queue.isProcessing {
                ProgressView()
                    .controlSize(.small)

                if let progress = queue.currentProgress {
                    Text("\(progress.progressPercentage)%")
                        .font(.caption)
                        .monospacedDigit()
                }
            } else if queue.isPaused && queue.hasPendingJobs {
                Image(systemName: "pause.fill")
                    .font(.caption)
                    .foregroundColor(.yellow)
            }

            if queue.pendingCount > 0 {
                Text("\(queue.pendingCount)")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.blue.opacity(0.2)))
            }
        }
    }
}

#Preview("Progress View - Processing") {
    let queue = JobQueue()
    return QueueProgressView(queue: queue)
        .frame(width: 300)
        .padding()
}

#Preview("Progress Badge") {
    let queue = JobQueue()
    return QueueProgressBadge(queue: queue)
        .padding()
}
