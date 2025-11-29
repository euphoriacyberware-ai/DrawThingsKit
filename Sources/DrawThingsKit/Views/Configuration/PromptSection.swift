//
//  PromptSection.swift
//  DrawThingsKit
//
//  Composable prompt editor section for configuration UI.
//

import SwiftUI

/// A composable section for editing prompts in a generation configuration.
///
/// Provides editors for:
/// - Positive prompt
/// - Negative prompt (with toggle)
/// - Separate CLIP-L, OpenCLIP-G, and T5 prompts (optional, advanced)
///
/// Example usage:
/// ```swift
/// PromptSection(
///     prompt: $prompt,
///     negativePrompt: $negativePrompt,
///     zeroNegativePrompt: $zeroNegativePrompt
/// )
/// ```
public struct PromptSection: View {
    @Binding var prompt: String
    @Binding var negativePrompt: String
    @Binding var zeroNegativePrompt: Bool

    // Optional separate encoder prompts
    @Binding var separateClipL: Bool
    @Binding var clipLText: String
    @Binding var separateOpenClipG: Bool
    @Binding var openClipGText: String
    @Binding var separateT5: Bool
    @Binding var t5Text: String

    var showAdvanced: Bool

    public init(
        prompt: Binding<String>,
        negativePrompt: Binding<String>,
        zeroNegativePrompt: Binding<Bool>,
        separateClipL: Binding<Bool> = .constant(false),
        clipLText: Binding<String> = .constant(""),
        separateOpenClipG: Binding<Bool> = .constant(false),
        openClipGText: Binding<String> = .constant(""),
        separateT5: Binding<Bool> = .constant(false),
        t5Text: Binding<String> = .constant(""),
        showAdvanced: Bool = false
    ) {
        self._prompt = prompt
        self._negativePrompt = negativePrompt
        self._zeroNegativePrompt = zeroNegativePrompt
        self._separateClipL = separateClipL
        self._clipLText = clipLText
        self._separateOpenClipG = separateOpenClipG
        self._openClipGText = openClipGText
        self._separateT5 = separateT5
        self._t5Text = t5Text
        self.showAdvanced = showAdvanced
    }

    public var body: some View {
        Section {
            // Positive Prompt
            VStack(alignment: .leading, spacing: 8) {
                Text("Positive Prompt")
                    .font(.caption)
                    .foregroundColor(.secondary)
                promptEditor(text: $prompt, minHeight: 80)
            }

            // Negative Prompt Toggle and Editor
            Toggle("Negative Prompt", isOn: Binding(
                get: { !zeroNegativePrompt },
                set: { zeroNegativePrompt = !$0 }
            ))
            .toggleStyle(.switch)

            if !zeroNegativePrompt {
                promptEditor(text: $negativePrompt, minHeight: 60)
            }

            // Advanced: Separate encoder prompts
            if showAdvanced {
                Divider()

                Toggle("Separate CLIP-L Prompt", isOn: $separateClipL)
                    .toggleStyle(.switch)

                if separateClipL {
                    promptEditor(text: $clipLText, minHeight: 60)
                }

                Toggle("Separate OpenCLIP-G Prompt", isOn: $separateOpenClipG)
                    .toggleStyle(.switch)

                if separateOpenClipG {
                    promptEditor(text: $openClipGText, minHeight: 60)
                }

                Toggle("Separate T5 Prompt", isOn: $separateT5)
                    .toggleStyle(.switch)

                if separateT5 {
                    promptEditor(text: $t5Text, minHeight: 60)
                }
            }
        }
    }

    @ViewBuilder
    private func promptEditor(text: Binding<String>, minHeight: CGFloat) -> some View {
        #if os(macOS)
        TextEditor(text: text)
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
        TextEditor(text: text)
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

#Preview {
    Form {
        PromptSection(
            prompt: .constant("a beautiful sunset over mountains"),
            negativePrompt: .constant("blurry, low quality"),
            zeroNegativePrompt: .constant(false),
            showAdvanced: true
        )
    }
    .formStyle(.grouped)
    .frame(width: 400, height: 500)
}
