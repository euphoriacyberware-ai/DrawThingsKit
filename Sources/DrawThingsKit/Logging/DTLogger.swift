//
//  DTLogger.swift
//  DrawThingsKit
//
//  Created by euphoriacyberware-ai.
//  Copyright © 2025 euphoriacyberware-ai
//
//  Licensed under the MIT License.
//  See LICENSE file in the project root for license information.
//

import Foundation
import os.log

/// Logging categories for different subsystems.
public enum DTLogCategory: String {
    case connection = "Connection"
    case queue = "Queue"
    case generation = "Generation"
    case grpc = "gRPC"
    case models = "Models"
    case configuration = "Configuration"
    case general = "General"
}

/// Log levels matching os.log levels.
public enum DTLogLevel: Int, Comparable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3
    case fault = 4

    public static func < (lhs: DTLogLevel, rhs: DTLogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        case .fault: return .fault
        }
    }

    var emoji: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .fault: return "💥"
        }
    }
}

/// Centralized logger for DrawThingsKit.
///
/// Uses Apple's unified logging system (os.log) for efficient, structured logging
/// that can be viewed in Console.app or via `log` command line tool.
///
/// Usage:
/// ```swift
/// DTLogger.debug("Starting connection", category: .connection)
/// DTLogger.info("Job enqueued: \(job.id)", category: .queue)
/// DTLogger.error("Failed to parse config: \(error)", category: .configuration)
///
/// // Log data payload (only in debug builds)
/// DTLogger.logData(requestData, label: "gRPC Request", category: .grpc)
/// ```
///
/// View logs in Terminal:
/// ```bash
/// log stream --predicate 'subsystem == "com.drawthings.kit"' --level debug
/// ```
public final class DTLogger {
    /// Shared instance
    public static let shared = DTLogger()

    /// The subsystem identifier for os.log
    private static let subsystem = "com.drawthings.kit"

    /// Minimum log level (messages below this level are ignored)
    public var minimumLevel: DTLogLevel = .debug

    /// Whether to include timestamps in console output
    public var includeTimestamps: Bool = true

    /// Whether logging is enabled
    public var isEnabled: Bool = true

    /// Whether to log to console (print) in addition to os.log
    /// Useful for Xcode console visibility
    public var logToConsole: Bool = {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }()

    /// Loggers for each category
    private var loggers: [DTLogCategory: Logger] = [:]

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    private init() {
        // Pre-create loggers for each category
        for category in [DTLogCategory.connection, .queue, .generation, .grpc, .models, .configuration, .general] {
            loggers[category] = Logger(subsystem: DTLogger.subsystem, category: category.rawValue)
        }
    }

    private func logger(for category: DTLogCategory) -> Logger {
        loggers[category] ?? Logger(subsystem: DTLogger.subsystem, category: category.rawValue)
    }

    // MARK: - Public Logging Methods

    /// Log a debug message (verbose, for development)
    public static func debug(
        _ message: @autoclosure () -> String,
        category: DTLogCategory = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        shared.log(level: .debug, message: message(), category: category, file: file, function: function, line: line)
    }

    /// Log an info message (general information)
    public static func info(
        _ message: @autoclosure () -> String,
        category: DTLogCategory = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        shared.log(level: .info, message: message(), category: category, file: file, function: function, line: line)
    }

    /// Log a warning message (potential issues)
    public static func warning(
        _ message: @autoclosure () -> String,
        category: DTLogCategory = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        shared.log(level: .warning, message: message(), category: category, file: file, function: function, line: line)
    }

    /// Log an error message (recoverable errors)
    public static func error(
        _ message: @autoclosure () -> String,
        category: DTLogCategory = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        shared.log(level: .error, message: message(), category: category, file: file, function: function, line: line)
    }

    /// Log a fault message (critical, unrecoverable errors)
    public static func fault(
        _ message: @autoclosure () -> String,
        category: DTLogCategory = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        shared.log(level: .fault, message: message(), category: category, file: file, function: function, line: line)
    }

    // MARK: - Data Logging

    /// Log binary data with a label (only in DEBUG builds)
    /// Useful for logging gRPC request/response payloads
    public static func logData(
        _ data: Data?,
        label: String,
        category: DTLogCategory = .grpc,
        maxBytes: Int = 1024
    ) {
        #if DEBUG
        guard shared.isEnabled, shared.minimumLevel <= .debug else { return }

        guard let data = data else {
            debug("\(label): <nil>", category: category)
            return
        }

        let sizeStr = ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .binary)
        var message = "\(label): \(sizeStr)"

        if data.count <= maxBytes {
            // Show hex dump for small data
            let hexString = data.prefix(maxBytes).map { String(format: "%02x", $0) }.joined(separator: " ")
            message += "\n  Hex: \(hexString)"

            // Try to show as UTF-8 string if valid
            if let string = String(data: data, encoding: .utf8), string.count < 500 {
                let escaped = string.replacingOccurrences(of: "\n", with: "\\n")
                message += "\n  UTF8: \(escaped)"
            }
        } else {
            message += " (truncated, showing first \(maxBytes) bytes)"
            let hexString = data.prefix(maxBytes).map { String(format: "%02x", $0) }.joined(separator: " ")
            message += "\n  Hex: \(hexString)..."
        }

        debug(message, category: category)
        #endif
    }

    /// Log a dictionary/JSON structure
    public static func logJSON(
        _ dict: [String: Any],
        label: String,
        category: DTLogCategory = .general
    ) {
        #if DEBUG
        guard shared.isEnabled, shared.minimumLevel <= .debug else { return }

        if let jsonData = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            debug("\(label):\n\(jsonString)", category: category)
        } else {
            debug("\(label): \(dict)", category: category)
        }
        #endif
    }

    // MARK: - Configuration Logging

    /// Log a DrawThingsConfiguration (useful for debugging generation requests)
    public static func logConfiguration(
        _ json: String,
        label: String = "Configuration",
        category: DTLogCategory = .configuration
    ) {
        #if DEBUG
        guard shared.isEnabled, shared.minimumLevel <= .debug else { return }

        // Pretty print the JSON
        if let data = json.data(using: .utf8),
           let jsonObject = try? JSONSerialization.jsonObject(with: data),
           let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted),
           let prettyString = String(data: prettyData, encoding: .utf8) {
            debug("\(label):\n\(prettyString)", category: category)
        } else {
            debug("\(label): \(json)", category: category)
        }
        #endif
    }

    // MARK: - Scoped Logging

    /// Create a scoped logger for a specific operation
    /// Returns a completion handler to log the end of the operation
    public static func startOperation(
        _ name: String,
        category: DTLogCategory = .general
    ) -> () -> Void {
        let startTime = CFAbsoluteTimeGetCurrent()
        info("▶ \(name) started", category: category)

        return {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            let durationStr = String(format: "%.2fms", duration * 1000)
            info("◀ \(name) completed in \(durationStr)", category: category)
        }
    }

    // MARK: - Private Implementation

    private func log(
        level: DTLogLevel,
        message: String,
        category: DTLogCategory,
        file: String,
        function: String,
        line: Int
    ) {
        guard isEnabled, level >= minimumLevel else { return }

        let logger = logger(for: category)

        // Log to os.log
        logger.log(level: level.osLogType, "\(message, privacy: .public)")

        // Also log to console if enabled (for Xcode visibility)
        if logToConsole {
            let fileName = (file as NSString).lastPathComponent
            let timestamp = includeTimestamps ? "[\(dateFormatter.string(from: Date()))] " : ""
            let prefix = "\(timestamp)\(level.emoji) [\(category.rawValue)]"

            #if DEBUG
            // Include file/line in debug
            print("\(prefix) \(message) (\(fileName):\(line))")
            #else
            print("\(prefix) \(message)")
            #endif
        }
    }
}

// MARK: - Convenience Extensions

extension DTLogger {
    /// Log entry into a function (debug level)
    public static func enter(
        _ function: String = #function,
        category: DTLogCategory = .general
    ) {
        debug("→ \(function)", category: category)
    }

    /// Log exit from a function (debug level)
    public static func exit(
        _ function: String = #function,
        category: DTLogCategory = .general
    ) {
        debug("← \(function)", category: category)
    }
}
