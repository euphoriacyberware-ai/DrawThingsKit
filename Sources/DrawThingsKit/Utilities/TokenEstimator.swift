//
//  TokenEstimator.swift
//  DrawThingsKit
//
//  Created by euphoriacyberware-ai.
//  Copyright © 2025 euphoriacyberware-ai
//
//  Licensed under the MIT License.
//  See LICENSE file in the project root for license information.
//

import Foundation

/// Estimates token counts for Stable Diffusion prompts.
///
/// This provides an approximation of CLIP tokenizer behavior without requiring
/// the actual vocabulary files. The estimation is based on:
/// - Word splitting on whitespace and punctuation
/// - Longer words (>6 chars) typically split into multiple BPE tokens
/// - Special SD prompt syntax like (word:1.2) for emphasis
/// - Start and end tokens that CLIP adds
///
/// Token limits by model:
/// - SD 1.x/2.x: 77 tokens
/// - SDXL: 77 tokens per encoder
/// - Flux/SD3: 77 (CLIP) + 256 (T5)
///
/// Example usage:
/// ```swift
/// let count = TokenEstimator.estimateTokens("a beautiful sunset over mountains")
/// print("Estimated tokens: ~\(count)")
/// ```
public struct TokenEstimator {

    /// Common token limits for different model types
    public enum ModelTokenLimit {
        case sd15
        case sdxl
        case flux
        case t5

        public var limit: Int {
            switch self {
            case .sd15: return 77
            case .sdxl: return 77
            case .flux: return 256
            case .t5: return 256
            }
        }

        public var displayName: String {
            switch self {
            case .sd15: return "SD 1.5"
            case .sdxl: return "SDXL"
            case .flux: return "Flux"
            case .t5: return "T5"
            }
        }
    }

    /// Result of token estimation
    public struct EstimationResult {
        /// Estimated token count
        public let count: Int

        /// Whether the estimate exceeds the specified limit
        public let exceedsLimit: Bool

        /// The token limit used for comparison
        public let limit: Int

        /// Percentage of limit used (0-100+)
        public var percentageUsed: Int {
            guard limit > 0 else { return 0 }
            return Int((Double(count) / Double(limit)) * 100)
        }
    }

    // MARK: - Token Estimation

    /// Estimates the token count for a prompt string.
    ///
    /// This uses a regex-based approximation of BPE tokenization:
    /// - Splits text into words and punctuation
    /// - Accounts for longer words splitting into multiple tokens
    /// - Handles SD-specific syntax like emphasis weights
    /// - Includes CLIP's start/end tokens
    ///
    /// - Parameter text: The prompt text to estimate
    /// - Returns: Estimated token count (always includes +2 for start/end tokens)
    public static func estimateTokens(_ text: String) -> Int {
        guard !text.isEmpty else { return 2 } // Just start/end tokens

        var count = 0

        // Pattern to match words, numbers, and individual punctuation/special chars
        // This approximates how CLIP's tokenizer splits text
        let pattern = #"[\w]+|[^\s\w]"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            // Fallback: rough word count * 1.3
            return Int(Double(text.split(separator: " ").count) * 1.3) + 2
        }

        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, options: [], range: range)

        for match in matches {
            guard let swiftRange = Range(match.range, in: text) else { continue }
            let token = String(text[swiftRange])

            // Check if this is a weight syntax like ":1.2" - these are often stripped
            if token.hasPrefix(":") || (token.first?.isNumber == true && token.contains(".")) {
                // Weight values in (word:1.2) syntax - minimal token cost
                count += 1
                continue
            }

            // Estimate tokens based on word length
            // BPE typically splits longer/uncommon words into subwords
            let length = token.count

            if token.allSatisfy({ $0.isLetter }) {
                // Pure letter words
                if length <= 3 {
                    // Short words: usually 1 token
                    count += 1
                } else if length <= 6 {
                    // Medium words: usually 1 token for common words
                    count += 1
                } else if length <= 10 {
                    // Longer words: often 2 tokens
                    count += 2
                } else {
                    // Very long words: multiple tokens
                    count += 1 + (length - 6) / 4
                }
            } else if token.allSatisfy({ $0.isNumber }) {
                // Numbers: each digit can be a token, but often grouped
                count += max(1, (length + 1) / 2)
            } else {
                // Punctuation and special chars: usually 1 token each
                count += 1
            }
        }

        // Add start and end tokens (CLIP always adds these)
        return count + 2
    }

    /// Estimates tokens and compares against a limit.
    ///
    /// - Parameters:
    ///   - text: The prompt text to estimate
    ///   - limit: The token limit to compare against
    /// - Returns: An EstimationResult with count,limit info, and whether it exceeds
    public static func estimate(_ text: String, limit: Int = 77) -> EstimationResult {
        let count = estimateTokens(text)
        return EstimationResult(
            count: count,
            exceedsLimit: count > limit,
            limit: limit
        )
    }

    /// Estimates tokens for a specific model type.
    ///
    /// - Parameters:
    ///   - text: The prompt text to estimate
    ///   - modelLimit: The model's token limit
    /// - Returns: An EstimationResult for that model
    public static func estimate(_ text: String, for modelLimit: ModelTokenLimit) -> EstimationResult {
        estimate(text, limit: modelLimit.limit)
    }
}
