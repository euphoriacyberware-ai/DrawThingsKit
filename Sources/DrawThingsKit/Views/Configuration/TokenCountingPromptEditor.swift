//
//  TokenCountingPromptEditor.swift
//  DrawThingsKit
//
//  Created by euphoriacyberware-ai.
//  Copyright © 2025 euphoriacyberware-ai
//
//  Licensed under the MIT License.
//  See LICENSE file in the project root for license information.
//

import SwiftUI

/// A prompt text editor that displays an estimated token count.
///
/// Shows a token counter badge that updates as you type, with color coding:
/// - Green: Under 75% of limit
/// - Yellow: 75-100% of limit
/// - Red: Over limit
///
/// Example usage:
/// ```swift
/// TokenCountingPromptEditor(
///     text: $prompt,
///     label: "Positive Prompt",
///     tokenLimit: 77
/// )
/// ```
public struct TokenCountingPromptEditor: View {
    @Binding var text: String

    var label: String?
    var tokenLimit: Int
    var minHeight: CGFloat
    var showLabel: Bool

    public init(
        text: Binding<String>,
        label: String? = nil,
        tokenLimit: Int = 77,
        minHeight: CGFloat = 80,
        showLabel: Bool = true
    ) {
        self._text = text
        self.label = label
        self.tokenLimit = tokenLimit
        self.minHeight = minHeight
        self.showLabel = showLabel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header with label and token count
            HStack {
                if showLabel, let label = label {
                    Text(label)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Token badge in its own view to isolate updates
                TokenBadgeView(text: text, tokenLimit: tokenLimit)
            }

            // Text editor in its own view to prevent re-renders from token updates
            PromptTextEditor(text: $text, minHeight: minHeight)
        }
    }
}

/// Isolated token badge view - updates don't affect sibling views
private struct TokenBadgeView: View {
    let text: String
    let tokenLimit: Int

    private var estimatedTokens: Int {
        TokenEstimator.estimateTokens(text)
    }

    private var percentage: Double {
        Double(estimatedTokens) / Double(tokenLimit)
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: tokenIcon)
                .font(.caption2)

            Text("~\(estimatedTokens)/\(tokenLimit)")
                .font(.caption.monospacedDigit())
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(tokenBackgroundColor.opacity(0.2))
        .foregroundColor(tokenForegroundColor)
        .cornerRadius(4)
        .help("Estimated token count (approximate)")
    }

    private var tokenIcon: String {
        if percentage > 1.0 {
            return "exclamationmark.triangle.fill"
        } else if percentage > 0.9 {
            return "exclamationmark.circle.fill"
        } else {
            return "number"
        }
    }

    private var tokenBackgroundColor: Color {
        if percentage > 1.0 {
            return .red
        } else if percentage > 0.9 {
            return .orange
        } else if percentage > 0.75 {
            return .yellow
        } else {
            return .green
        }
    }

    private var tokenForegroundColor: Color {
        if percentage > 1.0 {
            return .red
        } else if percentage > 0.9 {
            return .orange
        } else if percentage > 0.75 {
            return .yellow
        } else {
            return .secondary
        }
    }
}

/// Isolated text editor view - uses Equatable conformance to minimize re-renders
private struct PromptTextEditor: View, Equatable {
    @Binding var text: String
    let minHeight: CGFloat

    static func == (lhs: PromptTextEditor, rhs: PromptTextEditor) -> Bool {
        // Only re-render if minHeight changes, not text
        // Text changes are handled internally by TextEditor
        lhs.minHeight == rhs.minHeight
    }

    var body: some View {
        #if os(macOS)
        TextEditor(text: $text)
            .frame(minHeight: minHeight)
            .font(.body)
            .scrollContentBackground(.hidden)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
        #else
        TextEditor(text: $text)
            .frame(minHeight: minHeight)
            .font(.body)
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
        #endif
    }
}

extension PromptTextEditor {
    // Use equatable rendering to prevent unnecessary re-renders
    func _equatable() -> EquatableView<Self> {
        return .init(content: self)
    }
}

// MARK: - Compact Token Counter

/// A standalone token counter that can be placed next to any text field.
public struct TokenCounterView: View {
    let text: String
    var tokenLimit: Int

    public init(text: String, tokenLimit: Int = 77) {
        self.text = text
        self.tokenLimit = tokenLimit
    }

    private var estimatedTokens: Int {
        TokenEstimator.estimateTokens(text)
    }

    private var percentage: Double {
        Double(estimatedTokens) / Double(tokenLimit)
    }

    public var body: some View {
        HStack(spacing: 4) {
            Text("~\(estimatedTokens)")
                .font(.caption.monospacedDigit())
                .foregroundColor(percentage > 1.0 ? .red : .secondary)

            Text("/\(tokenLimit)")
                .font(.caption2.monospacedDigit())
                .foregroundColor(.secondary.opacity(0.7))
        }
        .help("Estimated tokens: ~\(estimatedTokens) of \(tokenLimit) limit")
    }
}

// MARK: - Previews

#Preview("Token Counting Editor") {
    struct PreviewWrapper: View {
        @State private var prompt = "a beautiful sunset over mountains, golden hour lighting, dramatic clouds"

        var body: some View {
            Form {
                TokenCountingPromptEditor(
                    text: $prompt,
                    label: "Positive Prompt",
                    tokenLimit: 77
                )
            }
            .formStyle(.grouped)
            .frame(width: 400, height: 200)
        }
    }
    return PreviewWrapper()
}

#Preview("Near Limit") {
    struct PreviewWrapper: View {
        @State private var prompt = "a beautiful sunset over mountains, golden hour lighting, dramatic clouds, cinematic composition, professional photography, 8k resolution, highly detailed, masterpiece, award winning"

        var body: some View {
            Form {
                TokenCountingPromptEditor(
                    text: $prompt,
                    label: "Positive Prompt",
                    tokenLimit: 77
                )
            }
            .formStyle(.grouped)
            .frame(width: 400, height: 200)
        }
    }
    return PreviewWrapper()
}

#Preview("Over Limit") {
    struct PreviewWrapper: View {
        @State private var prompt = "a beautiful sunset over mountains, golden hour lighting, dramatic clouds, cinematic composition, professional photography, 8k resolution, highly detailed, masterpiece, award winning, photorealistic, stunning, breathtaking, vibrant colors, epic scene, landscape photography, nature, outdoors, wilderness, peaceful, serene, tranquil"

        var body: some View {
            Form {
                TokenCountingPromptEditor(
                    text: $prompt,
                    label: "Positive Prompt",
                    tokenLimit: 77
                )
            }
            .formStyle(.grouped)
            .frame(width: 400, height: 200)
        }
    }
    return PreviewWrapper()
}

#Preview("Standalone Counter") {
    VStack(spacing: 20) {
        TokenCounterView(text: "short prompt", tokenLimit: 77)
        TokenCounterView(text: "a much longer prompt with many words that approaches the token limit", tokenLimit: 77)
        TokenCounterView(text: "a very long prompt that definitely exceeds the token limit with lots of descriptive words, adjectives, and detailed scene descriptions that would require many tokens to encode properly in the CLIP tokenizer", tokenLimit: 77)
    }
    .padding()
}
