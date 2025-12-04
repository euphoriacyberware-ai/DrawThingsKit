//
//  QueueControlsView.swift
//  DrawThingsKit
//
//  Created by euphoriacyberware-ai.
//  Copyright © 2025 euphoriacyberware-ai
//
//  Licensed under the MIT License.
//  See LICENSE file in the project root for license information.
//

import SwiftUI

/// Controls for managing the queue.
public struct QueueControlsView: View {
    @ObservedObject var queue: JobQueue

    var showClearOptions: Bool

    public init(queue: JobQueue, showClearOptions: Bool = true) {
        self.queue = queue
        self.showClearOptions = showClearOptions
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Play/Pause button
            Button {
                if queue.isPaused {
                    queue.resume()
                } else {
                    queue.pause()
                }
            } label: {
                Image(systemName: queue.isPaused ? "play.fill" : "pause.fill")
                    .frame(width: 20)
            }
            .buttonStyle(.bordered)
            .disabled(!queue.hasPendingJobs && !queue.isProcessing)
            .help(queue.isPaused ? "Start processing" : "Pause processing")

            // Status text
            Text(statusText)
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            // Clear menu
            if showClearOptions {
                Menu {
                    Button("Clear Completed") {
                        queue.clearCompleted()
                    }
                    .disabled(queue.completedJobs.isEmpty)

                    Button("Clear Failed") {
                        queue.clearFailed()
                    }
                    .disabled(queue.failedJobs.isEmpty)

                    Divider()

                    Button("Clear All Finished") {
                        queue.clearFinished()
                    }
                    .disabled(queue.completedJobs.isEmpty && queue.failedJobs.isEmpty)

                    Divider()

                    Button("Clear All", role: .destructive) {
                        queue.clearAll()
                    }
                    .disabled(queue.isEmpty)
                } label: {
                    Image(systemName: "trash")
                }
                .menuStyle(.borderlessButton)
                .disabled(queue.isEmpty)
            }
        }
    }

    private var statusText: String {
        if queue.isProcessing {
            return "Processing..."
        } else if queue.isPaused {
            if queue.lastError != nil {
                return "Paused (Error)"
            }
            return "Paused"
        } else if queue.hasPendingJobs {
            return "\(queue.pendingCount) pending"
        } else {
            return "Idle"
        }
    }
}

/// A toolbar-style control strip for the queue.
public struct QueueToolbar: View {
    @ObservedObject var queue: JobQueue
    let onAddJob: (() -> Void)?

    public init(queue: JobQueue, onAddJob: (() -> Void)? = nil) {
        self.queue = queue
        self.onAddJob = onAddJob
    }

    public var body: some View {
        HStack(spacing: 8) {
            // Add button
            if let onAddJob = onAddJob {
                Button(action: onAddJob) {
                    Image(systemName: "plus")
                }
                .help("Add job")
            }

            Divider()
                .frame(height: 16)

            // Play/Pause
            Button {
                if queue.isPaused {
                    queue.resume()
                } else {
                    queue.pause()
                }
            } label: {
                Image(systemName: queue.isPaused ? "play.fill" : "pause.fill")
            }
            .disabled(!queue.hasPendingJobs && !queue.isProcessing)

            // Queue count badge
            if queue.pendingCount > 0 {
                Text("\(queue.pendingCount)")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.blue.opacity(0.2)))
            }

            // Processing indicator
            if queue.isProcessing {
                ProgressView()
                    .controlSize(.small)

                if let progress = queue.currentProgress {
                    Text("\(progress.progressPercentage)%")
                        .font(.caption2)
                        .monospacedDigit()
                }
            }
        }
    }
}

#Preview("Queue Controls") {
    let queue = JobQueue()
    return VStack {
        QueueControlsView(queue: queue)
            .padding()

        Divider()

        QueueToolbar(queue: queue) {
            print("Add job")
        }
        .padding()
    }
    .frame(width: 300)
}
