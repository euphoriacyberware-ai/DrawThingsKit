//
//  QueueItemRow.swift
//  DrawThingsKit
//
//  Created by euphoriacyberware-ai.
//  Copyright © 2025 euphoriacyberware-ai
//
//  Licensed under the MIT License.
//  See LICENSE file in the project root for license information.
//

import SwiftUI

/// A row view for displaying a generation job in the queue list.
public struct QueueItemRow: View {
    let job: GenerationJob
    let onCancel: (() -> Void)?
    let onRetry: (() -> Void)?
    let onRemove: (() -> Void)?

    public init(
        job: GenerationJob,
        onCancel: (() -> Void)? = nil,
        onRetry: (() -> Void)? = nil,
        onRemove: (() -> Void)? = nil
    ) {
        self.job = job
        self.onCancel = onCancel
        self.onRetry = onRetry
        self.onRemove = onRemove
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            statusIcon
                .frame(width: 24, height: 24)

            // Job info
            VStack(alignment: .leading, spacing: 4) {
                Text(job.name)
                    .font(.body)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    statusText

                    if let duration = job.durationString {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(duration)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if job.resultImages.count > 1 {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text("\(job.resultImages.count) images")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Progress (for processing jobs)
            if job.isProcessing, let progress = job.progress {
                VStack(alignment: .trailing, spacing: 2) {
//                    Text("\(progress.progressPercentage)%")
//                        .font(.caption)
//                        .monospacedDigit()
//                        .foregroundColor(.secondary)

//                    ProgressView(value: progress.progressFraction)
//                        .frame(width: 60)
                }
            }

            // Thumbnail (for completed jobs)
            if job.isCompleted, let image = job.firstResultImage {
                #if os(macOS)
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 40)
                    .cornerRadius(4)
                    .clipped()
                #else
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 40)
                    .cornerRadius(4)
                    .clipped()
                #endif
            }

            // Action buttons
            actionButtons
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch job.status {
        case .pending:
            Image(systemName: "clock")
                .foregroundColor(.secondary)

        case .processing:
            ProgressView()
                .controlSize(.small)

        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)

        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.red)

        case .cancelled:
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.gray)
        }
    }

    @ViewBuilder
    private var statusText: some View {
        switch job.status {
        case .pending:
            Text("Pending")
                .font(.caption)
                .foregroundColor(.secondary)

        case .processing:
            if let stage = job.progress?.stage {
                Text(stage)
                    .font(.caption)
                    .foregroundColor(.blue)
            } else {
                Text("Processing")
                    .font(.caption)
                    .foregroundColor(.blue)
            }

        case .completed:
            Text("Completed")
                .font(.caption)
                .foregroundColor(.green)

        case .failed:
            Text(job.errorMessage ?? "Failed")
                .font(.caption)
                .foregroundColor(.red)
                .lineLimit(1)

        case .cancelled:
            Text("Cancelled")
                .font(.caption)
                .foregroundColor(.gray)
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 4) {
            if job.isProcessing {
                if let onCancel = onCancel {
                    Button(action: onCancel) {
                        Image(systemName: "stop.fill")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    .help("Cancel")
                }
            } else if job.isFailed && job.canRetry {
                if let onRetry = onRetry {
                    Button(action: onRetry) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    .help("Retry")
                }
            }

            if !job.isProcessing {
                if let onRemove = onRemove {
                    Button(action: onRemove) {
                        Image(systemName: "trash")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Remove")
                }
            }
        }
    }
}

/// A compact version of the queue item row for smaller displays.
public struct QueueItemCompactRow: View {
    let job: GenerationJob

    public init(job: GenerationJob) {
        self.job = job
    }

    public var body: some View {
        HStack(spacing: 8) {
            statusDot

            Text(job.name)
                .font(.caption)
                .lineLimit(1)

            Spacer()

            if job.isProcessing, let progress = job.progress {
                Text("\(progress.progressPercentage)%")
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundColor(.secondary)
            }
        }
    }

    private var statusDot: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 8, height: 8)
    }

    private var statusColor: Color {
        switch job.status {
        case .pending: return .gray
        case .processing: return .blue
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .gray
        }
    }
}

#Preview("Queue Item Row") {
    VStack(spacing: 8) {
        QueueItemRow(
            job: try! GenerationJob(
                prompt: "A beautiful sunset over mountains",
                configuration: DrawThingsConfiguration()
            )
        )

        Divider()

        QueueItemRow(
            job: {
                var job = try! GenerationJob(
                    prompt: "Processing job example",
                    configuration: DrawThingsConfiguration()
                )
                job.status = .processing
                job.progress = JobProgress(currentStep: 15, totalSteps: 30, stage: "Sampling")
                return job
            }()
        )

        Divider()

        QueueItemRow(
            job: {
                var job = try! GenerationJob(
                    prompt: "Completed job with results",
                    configuration: DrawThingsConfiguration()
                )
                job.status = .completed
                return job
            }()
        )

        Divider()

        QueueItemRow(
            job: {
                var job = try! GenerationJob(
                    prompt: "Failed job example",
                    configuration: DrawThingsConfiguration()
                )
                job.status = .failed
                job.errorMessage = "Out of memory"
                return job
            }()
        )
    }
    .padding()
    .frame(width: 400)
}

#Preview("Queue Item Compact Row") {
    List {
        QueueItemCompactRow(
            job: try! GenerationJob(
                prompt: "Pending job",
                configuration: DrawThingsConfiguration()
            )
        )

        QueueItemCompactRow(
            job: {
                var job = try! GenerationJob(
                    prompt: "Processing job example",
                    configuration: DrawThingsConfiguration()
                )
                job.status = .processing
                job.progress = JobProgress(currentStep: 15, totalSteps: 30, stage: "Sampling")
                return job
            }()
        )

        QueueItemCompactRow(
            job: {
                var job = try! GenerationJob(
                    prompt: "Completed job",
                    configuration: DrawThingsConfiguration()
                )
                job.status = .completed
                return job
            }()
        )

        QueueItemCompactRow(
            job: {
                var job = try! GenerationJob(
                    prompt: "Failed job",
                    configuration: DrawThingsConfiguration()
                )
                job.status = .failed
                job.errorMessage = "Out of memory"
                return job
            }()
        )

        QueueItemCompactRow(
            job: {
                var job = try! GenerationJob(
                    prompt: "Cancelled job",
                    configuration: DrawThingsConfiguration()
                )
                job.status = .cancelled
                return job
            }()
        )
    }
    .listStyle(.plain)
    .frame(width: 250, height: 200)
}
