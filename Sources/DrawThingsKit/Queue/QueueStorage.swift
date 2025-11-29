//
//  QueueStorage.swift
//  DrawThingsKit
//
//  JSON file persistence for the job queue.
//

import Foundation

/// Handles persistence of the job queue to a JSON file.
///
/// Jobs are stored in the app's Application Support directory,
/// allowing them to persist across app restarts.
public final class QueueStorage: Sendable {
    private let fileURL: URL

    /// Initialize with optional custom file URL.
    /// - Parameter fileURL: Custom file URL. Defaults to Application Support/DrawThingsKit/queue.json
    public init(fileURL: URL? = nil) {
        if let url = fileURL {
            self.fileURL = url
        } else {
            self.fileURL = Self.defaultFileURL()
        }
    }

    /// Load jobs from storage.
    /// - Returns: Array of saved jobs, or empty array if none exist.
    public func loadJobs() -> [GenerationJob] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let jobs = try JSONDecoder().decode([GenerationJob].self, from: data)
            return jobs
        } catch {
            print("DrawThingsKit: Failed to load queue: \(error)")
            return []
        }
    }

    /// Save jobs to storage.
    /// - Parameter jobs: The jobs to save.
    public func saveJobs(_ jobs: [GenerationJob]) {
        do {
            // Ensure directory exists
            let directory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(jobs)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("DrawThingsKit: Failed to save queue: \(error)")
        }
    }

    /// Clear all saved jobs.
    public func clearJobs() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// Get the default file URL for queue storage.
    private static func defaultFileURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!

        // Use bundle identifier if available, otherwise use a default
        let bundleId = Bundle.main.bundleIdentifier ?? "DrawThingsKit"
        let directory = appSupport.appendingPathComponent(bundleId, isDirectory: true)

        return directory.appendingPathComponent("queue.json")
    }

    /// Get storage file location (for debugging).
    public var storageLocation: URL {
        fileURL
    }

    /// Check if storage file exists.
    public var exists: Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }

    /// Get size of storage file in bytes.
    public var fileSize: Int64? {
        guard exists else { return nil }
        let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
        return attributes?[.size] as? Int64
    }
}
