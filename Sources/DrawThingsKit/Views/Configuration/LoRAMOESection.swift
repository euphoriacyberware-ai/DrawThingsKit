//
//  LoRAMOESection.swift
//  DrawThingsKit
//
//  Created by euphoriacyberware-ai.
//  Copyright © 2025 euphoriacyberware-ai
//
//  Licensed under the MIT License.
//  See LICENSE file in the project root for license information.
//

import SwiftUI
import DrawThingsClient

/// A LoRA section designed for Mixture of Experts workflows.
///
/// Displays LoRAs in a two-column layout where position indicates the mode:
/// - Left column: Base only
/// - Full width (center): All (both base and refiner)
/// - Right column: Refiner only
///
/// Users can drag LoRA rows horizontally to change their mode.
///
/// Example usage:
/// ```swift
/// LoRAMOESection(
///     modelsManager: modelsManager,
///     selectedLoRAs: $selectedLoRAs
/// )
/// ```
public struct LoRAMOESection: View {
    @ObservedObject var modelsManager: ModelsManager
    @Binding var selectedLoRAs: [LoRAConfiguration]

    public init(
        modelsManager: ModelsManager,
        selectedLoRAs: Binding<[LoRAConfiguration]>
    ) {
        self.modelsManager = modelsManager
        self._selectedLoRAs = selectedLoRAs
    }

    private var enabledCount: Int {
        selectedLoRAs.filter(\.enabled).count
    }

    public var body: some View {
        Section {
            VStack(spacing: 8) {
                // Add LoRA menu
                Menu {
                    if modelsManager.compatibleLoRAs.isEmpty {
                        Text("No compatible LoRAs")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(modelsManager.compatibleLoRAs) { lora in
                            Button {
                                addLoRA(lora)
                            } label: {
                                ModelLabelView(name: lora.name, source: lora.source)
                            }
                            .disabled(selectedLoRAs.contains(where: { $0.lora.id == lora.id }))
                        }
                    }
                } label: {
                    Label("Add LoRA", systemImage: "plus.circle")
                        .frame(maxWidth: .infinity)
                }
                .disabled(modelsManager.selectedCheckpoint == nil)
                .help(modelsManager.selectedCheckpoint == nil ? "Select a checkpoint first" : "Add a LoRA model")

                // Column headers
                HStack {
                    Text("BASE")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("ALL")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    Text("REFINER")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.horizontal, 4)

                Divider()

                // LoRA list with drag-to-change-mode
                if selectedLoRAs.isEmpty {
                    Text("No LoRAs added")
                        .foregroundColor(.secondary)
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                } else {
                    ForEach($selectedLoRAs) { $loraConfig in
                        DraggableLoRARow(config: $loraConfig) {
                            removeLoRA(loraConfig)
                        }
                    }
                }

                // Legend
                HStack(spacing: 16) {
                    legendItem(color: .blue, text: "Base")
                    legendItem(color: .purple, text: "All")
                    legendItem(color: .orange, text: "Refiner")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.top, 4)
            }
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private func legendItem(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color.opacity(0.3))
                .stroke(color, lineWidth: 1)
                .frame(width: 8, height: 8)
            Text(text)
        }
    }

    private func addLoRA(_ lora: LoRAModel) {
        guard !selectedLoRAs.contains(where: { $0.lora.id == lora.id }) else {
            return
        }
        selectedLoRAs.append(LoRAConfiguration(lora: lora))
    }

    private func removeLoRA(_ config: LoRAConfiguration) {
        selectedLoRAs.removeAll { $0.id == config.id }
    }
}

/// A LoRA row that can be dragged horizontally to change its mode.
struct DraggableLoRARow: View {
    @Binding var config: LoRAConfiguration
    let onDelete: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false
    @State private var previewMode: LoRAMode?

    /// The color associated with each mode.
    private func modeColor(_ mode: LoRAMode) -> Color {
        switch mode {
        case .base: return .blue
        case .all: return .purple
        case .refiner: return .orange
        }
    }

    /// Zone thresholds for mode detection.
    /// Values below `baseThreshold` → Base mode
    /// Values above `refinerThreshold` → Refiner mode
    /// Values in between → All mode
    private let baseThreshold: CGFloat = 0.25
    private let refinerThreshold: CGFloat = 0.75

    /// Calculate the mode based on horizontal position within the container.
    private func modeForPosition(_ position: CGFloat, containerWidth: CGFloat) -> LoRAMode {
        let relativePosition = position / containerWidth
        if relativePosition < baseThreshold {
            return .base
        } else if relativePosition > refinerThreshold {
            return .refiner
        } else {
            return .all
        }
    }

    /// Calculate the target X offset for a given mode.
    private func offsetForMode(_ mode: LoRAMode, containerWidth: CGFloat, itemWidth: CGFloat) -> CGFloat {
        switch mode {
        case .base:
            return 0
        case .all:
            return 0 // Full width, no offset needed
        case .refiner:
            return containerWidth - itemWidth
        }
    }

    /// The width of the row based on mode.
    private func widthForMode(_ mode: LoRAMode, containerWidth: CGFloat) -> CGFloat {
        switch mode {
        case .all:
            return containerWidth
        case .base, .refiner:
            return (containerWidth - 8) / 2 // Half width with small gap
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let containerWidth = geometry.size.width
            let displayMode = previewMode ?? config.mode
            let itemWidth = widthForMode(displayMode, containerWidth: containerWidth)

            HStack(spacing: 0) {
                // The actual row content
                rowContent
                    .frame(width: itemWidth)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(modeColor(displayMode).opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(modeColor(displayMode).opacity(isDragging ? 0.8 : 0.3), lineWidth: isDragging ? 2 : 1)
                            )
                    )
                    .offset(x: calculateOffset(mode: displayMode, containerWidth: containerWidth, itemWidth: itemWidth))
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: displayMode)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                isDragging = true
                                dragOffset = value.translation.width

                                // Calculate preview mode based on drag position
                                let currentOffset = calculateOffset(mode: config.mode, containerWidth: containerWidth, itemWidth: widthForMode(config.mode, containerWidth: containerWidth))
                                let centerX = currentOffset + itemWidth / 2 + dragOffset
                                previewMode = modeForPosition(centerX, containerWidth: containerWidth)
                            }
                            .onEnded { value in
                                isDragging = false

                                // Apply the preview mode
                                if let newMode = previewMode {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        config.mode = newMode
                                    }
                                }

                                dragOffset = 0
                                previewMode = nil
                            }
                    )

                Spacer(minLength: 0)
            }
        }
        .frame(height: 70)
    }

    private func calculateOffset(mode: LoRAMode, containerWidth: CGFloat, itemWidth: CGFloat) -> CGFloat {
        var baseOffset: CGFloat
        switch mode {
        case .base:
            baseOffset = 0
        case .all:
            baseOffset = 0
        case .refiner:
            baseOffset = containerWidth - itemWidth
        }

        // Add drag offset if dragging
        if isDragging {
            return baseOffset + dragOffset
        }
        return baseOffset
    }

    @ViewBuilder
    private var rowContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header with toggle, name, and delete
            HStack {
                Toggle("", isOn: $config.enabled)
                    .labelsHidden()
                    .scaleEffect(0.8)

                Text(config.lora.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Spacer()

                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Weight slider (snaps to 0.05 increments when released)
            HStack(spacing: 4) {
                Text(String(format: "%.2f", config.weight))
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundColor(.secondary)
                    .frame(width: 32)

                Slider(value: $config.weight, in: -1.5...2.5) { editing in
                    if !editing {
                        config.weight = (config.weight / 0.05).rounded() * 0.05
                    }
                }
                .controlSize(.mini)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .opacity(config.enabled ? 1.0 : 0.5)
    }
}

#Preview("MOE Section") {
    struct PreviewWrapper: View {
        @State private var loras: [LoRAConfiguration] = [
            LoRAConfiguration(
                lora: LoRAModel(name: "Style LoRA", file: "style.safetensors"),
                mode: .base
            ),
            LoRAConfiguration(
                lora: LoRAModel(name: "Detail Enhancer", file: "detail.safetensors"),
                mode: .all
            ),
            LoRAConfiguration(
                lora: LoRAModel(name: "Refiner Boost", file: "refiner.safetensors"),
                mode: .refiner
            ),
        ]

        var body: some View {
            Form {
                LoRAMOESection(
                    modelsManager: ModelsManager(),
                    selectedLoRAs: $loras
                )
            }
            .formStyle(.grouped)
            .frame(width: 350, height: 400)
        }
    }

    return PreviewWrapper()
}

#Preview("Empty") {
    Form {
        LoRAMOESection(
            modelsManager: ModelsManager(),
            selectedLoRAs: .constant([])
        )
    }
    .formStyle(.grouped)
    .frame(width: 350, height: 300)
}
