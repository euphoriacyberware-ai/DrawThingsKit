//
//  LoRASection.swift
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

/// A composable section for managing LoRA models.
///
/// Automatically switches between standard and Mixture of Experts (MOE) layouts:
/// - Standard: Compact card-style layout with weight sliders
/// - MOE: Draggable rows that can be positioned as Base/All/Refiner
///
/// The MOE mode can be:
/// - Auto-detected from the selected checkpoint (Wan 2.2 models)
/// - Explicitly set via the `mixtureOfExperts` parameter
///
/// Example usage:
/// ```swift
/// // Auto-detect MOE from selected model
/// LoRASection(
///     modelsManager: modelsManager,
///     selectedLoRAs: $selectedLoRAs
/// )
///
/// // Explicitly set MOE mode
/// LoRASection(
///     modelsManager: modelsManager,
///     selectedLoRAs: $selectedLoRAs,
///     mixtureOfExperts: true
/// )
/// ```
public struct LoRASection: View {
    @ObservedObject var modelsManager: ModelsManager
    @Binding var selectedLoRAs: [LoRAConfiguration]

    /// Explicit MOE mode override. If nil, auto-detects from selected checkpoint.
    private let explicitMOE: Bool?

    /// Whether Mixture of Experts mode is active.
    /// Auto-detects Wan 2.2 models if not explicitly set.
    private var isMixtureOfExperts: Bool {
        if let explicit = explicitMOE {
            return explicit
        }
        // Auto-detect from selected checkpoint
        guard let checkpoint = modelsManager.selectedCheckpoint else {
            return false
        }
        return isWan22Model(checkpoint)
    }

    public init(
        modelsManager: ModelsManager,
        selectedLoRAs: Binding<[LoRAConfiguration]>,
        mixtureOfExperts: Bool? = nil
    ) {
        self.modelsManager = modelsManager
        self._selectedLoRAs = selectedLoRAs
        self.explicitMOE = mixtureOfExperts
    }

    // MARK: - Wan 2.2 Detection

    /// Check if a checkpoint model is a Wan 2.2 model
    private func isWan22Model(_ model: CheckpointModel) -> Bool {
        if let version = model.version {
            if version.lowercased().contains("wan22") || version.lowercased().contains("wan_2.2") {
                return true
            }
        }
        if isWan22ModelName(model.file) {
            return true
        }
        if model.name.lowercased().contains("wan 2.2") || model.name.lowercased().contains("wan2.2") {
            return true
        }
        return false
    }

    /// Check if a model filename indicates Wan 2.2
    private func isWan22ModelName(_ name: String) -> Bool {
        let lower = name.lowercased()
        return lower.contains("wan_v2.2") || lower.contains("wan_2.2") || lower.contains("wan22")
    }

    private var enabledCount: Int {
        selectedLoRAs.filter(\.enabled).count
    }

    public var body: some View {
        if isMixtureOfExperts {
            moeLayout
        } else {
            standardLayout
        }
    }

    // MARK: - Standard Layout

    private var standardLayout: some View {
        Section {
            VStack(spacing: 8) {
                addLoRAPicker

                // LoRA list
                if selectedLoRAs.isEmpty {
                    Text("No LoRAs added")
                        .foregroundColor(.secondary)
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                } else {
                    ForEach($selectedLoRAs) { $loraConfig in
                        LoRACardRow(config: $loraConfig) {
                            removeLoRA(loraConfig)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - MOE Layout

    private var moeLayout: some View {
        Section {
            VStack(spacing: 8) {
                addLoRAPicker

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

    // MARK: - Shared Components

    private var addLoRAPicker: some View {
        SearchableLoRAPicker(
            loras: modelsManager.compatibleLoRAs,
            selectedLoRAIds: Set(selectedLoRAs.map { $0.lora.id }),
            onSelect: { lora in addLoRA(lora) },
            disabled: modelsManager.selectedCheckpoint == nil,
            disabledReason: modelsManager.selectedCheckpoint == nil ? "Select a checkpoint first" : nil
        )
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

/// A compact card-style row for a single LoRA configuration.
/// Matches the visual style of `DraggableLoRARow` but without drag interaction.
struct LoRACardRow: View {
    @Binding var config: LoRAConfiguration
    let onDelete: () -> Void

    public var body: some View {
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
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.purple.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                )
        )
        .opacity(config.enabled ? 1.0 : 0.5)
        .frame(height: 70)
    }
}

/// A row view for a single LoRA configuration (legacy style).
public struct LoRARow: View {
    @Binding var config: LoRAConfiguration
    let showModeSelector: Bool
    let onDelete: () -> Void

    public init(
        config: Binding<LoRAConfiguration>,
        showModeSelector: Bool = false,
        onDelete: @escaping () -> Void
    ) {
        self._config = config
        self.showModeSelector = showModeSelector
        self.onDelete = onDelete
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row with toggle and name
            HStack {
                Toggle("", isOn: $config.enabled)
                    .labelsHidden()

                VStack(alignment: .leading, spacing: 2) {
                    ModelLabelView(name: config.lora.name, source: config.lora.source)
                        .font(.body)

                    if let prefix = config.lora.prefix, !prefix.isEmpty {
                        Text(prefix)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .help("Remove LoRA")
            }

            // Weight slider (no step parameter to avoid tick marks, snaps on release)
            HStack {
                Text("Weight:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Slider(value: $config.weight, in: -1.5...2.5) { editing in
                    if !editing {
                        // Snap to 0.05 increments when released
                        config.weight = (config.weight / 0.05).rounded() * 0.05
                    }
                }

                Text(String(format: "%.2f", config.weight))
                    .font(.caption)
                    .monospacedDigit()
                    .frame(width: 50, alignment: .trailing)
            }

            // Mode picker - only shown for Mixture of Experts workflows
            if showModeSelector {
                HStack {
                    Text("Mode:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Picker("", selection: $config.mode) {
                        Text("All").tag(LoRAMode.all)
                        Text("Base").tag(LoRAMode.base)
                        Text("Refiner").tag(LoRAMode.refiner)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
            }
        }
        .padding(.vertical, 4)
        .opacity(config.enabled ? 1.0 : 0.5)
    }
}

// MARK: - Draggable LoRA Row (MOE Mode)

/// A LoRA row that can be dragged horizontally to change its mode.
/// Used in Mixture of Experts layouts.
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

    /// The width of the row based on mode.
    private func widthForMode(_ mode: LoRAMode, containerWidth: CGFloat) -> CGFloat {
        switch mode {
        case .all:
            return containerWidth
        case .base, .refiner:
            return (containerWidth - 8) / 2
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let containerWidth = geometry.size.width
            let displayMode = previewMode ?? config.mode
            let itemWidth = widthForMode(displayMode, containerWidth: containerWidth)

            HStack(spacing: 0) {
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

                                let currentOffset = calculateOffset(mode: config.mode, containerWidth: containerWidth, itemWidth: widthForMode(config.mode, containerWidth: containerWidth))
                                let centerX = currentOffset + itemWidth / 2 + dragOffset
                                previewMode = modeForPosition(centerX, containerWidth: containerWidth)
                            }
                            .onEnded { _ in
                                isDragging = false

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

        if isDragging {
            return baseOffset + dragOffset
        }
        return baseOffset
    }

    @ViewBuilder
    private var rowContent: some View {
        VStack(alignment: .leading, spacing: 4) {
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

// MARK: - Previews

#Preview("Empty State") {
    let manager = ModelsManager()
    return Form {
        LoRASection(
            modelsManager: manager,
            selectedLoRAs: .constant([])
        )
    }
    .formStyle(.grouped)
    .frame(width: 400, height: 300)
}

#if DEBUG
#Preview("With LoRAs") {
    let manager = ModelsManager.preview(withCheckpoints: [
        .mock(name: "SDXL Base", file: "sdxl_base.safetensors", version: "sdxl")
    ])

    let mockLoRAs: [LoRAConfiguration] = [
        LoRAConfiguration(
            lora: .mock(name: "Detail Tweaker XL", file: "detail_tweaker_xl.safetensors", version: "sdxl"),
            weight: 0.8,
            enabled: true
        ),
        LoRAConfiguration(
            lora: .mock(name: "Film Grain", file: "film_grain_lora.safetensors", version: "sdxl"),
            weight: 0.5,
            enabled: true
        ),
        LoRAConfiguration(
            lora: .mock(name: "Cinematic Look", file: "cinematic_lora.safetensors", version: "sdxl"),
            weight: 1.0,
            enabled: false
        )
    ]

    return Form {
        LoRASection(
            modelsManager: manager,
            selectedLoRAs: .constant(mockLoRAs)
        )
    }
    .formStyle(.grouped)
    .frame(width: 400, height: 400)
}

#Preview("Single LoRA") {
    let manager = ModelsManager.preview(withCheckpoints: [
        .mock(name: "SD 1.5", file: "sd15.safetensors", version: "sd15")
    ])

    let mockLoRAs: [LoRAConfiguration] = [
        LoRAConfiguration(
            lora: .mock(name: "Aesthetic Style", file: "aesthetic.safetensors", version: "sd15"),
            weight: 1.2,
            enabled: true
        )
    ]

    return Form {
        LoRASection(
            modelsManager: manager,
            selectedLoRAs: .constant(mockLoRAs)
        )
    }
    .formStyle(.grouped)
    .frame(width: 400, height: 250)
}

#Preview("LoRA Card Row") {
    let mockLora = LoRAModel.mock(
        name: "Detail Enhancer XL",
        file: "detail_enhancer.safetensors",
        version: "sdxl"
    )

    struct PreviewWrapper: View {
        @State var config: LoRAConfiguration

        var body: some View {
            LoRACardRow(config: $config) {
                print("Delete tapped")
            }
            .padding()
        }
    }

    return VStack(spacing: 16) {
        PreviewWrapper(config: LoRAConfiguration(lora: mockLora, weight: 0.85, enabled: true))
        PreviewWrapper(config: LoRAConfiguration(lora: mockLora, weight: 0.5, enabled: false))
    }
    .frame(width: 350, height: 200)
}

#Preview("MOE Mode - Explicit") {
    let manager = ModelsManager.preview(withCheckpoints: [
        .mock(name: "SDXL Base", file: "sdxl_base.safetensors", version: "sdxl")
    ])

    let mockLoRAs: [LoRAConfiguration] = [
        LoRAConfiguration(
            lora: .mock(name: "Style LoRA", file: "style.safetensors", version: "sdxl"),
            weight: 1.0,
            mode: .base,
            enabled: true
        ),
        LoRAConfiguration(
            lora: .mock(name: "Detail Enhancer", file: "detail.safetensors", version: "sdxl"),
            weight: 0.8,
            mode: .all,
            enabled: true
        ),
        LoRAConfiguration(
            lora: .mock(name: "Refiner Boost", file: "refiner.safetensors", version: "sdxl"),
            weight: 0.6,
            mode: .refiner,
            enabled: true
        )
    ]

    return Form {
        LoRASection(
            modelsManager: manager,
            selectedLoRAs: .constant(mockLoRAs),
            mixtureOfExperts: true
        )
    }
    .formStyle(.grouped)
    .frame(width: 400, height: 450)
}

#Preview("MOE Mode - Auto-detected (Wan 2.2)") {
    let wan22Model = CheckpointModel.mock(
        name: "Wan 2.2 14B I2V",
        file: "wan_v2.2_fun_14b_control_i2v.safetensors",
        version: "wan22"
    )
    let manager = ModelsManager.preview(withCheckpoints: [wan22Model])
    manager.selectedCheckpoint = wan22Model

    let mockLoRAs: [LoRAConfiguration] = [
        LoRAConfiguration(
            lora: .mock(name: "Motion LoRA", file: "motion.safetensors", version: "wan22"),
            weight: 1.0,
            mode: .all,
            enabled: true
        )
    ]

    return Form {
        LoRASection(
            modelsManager: manager,
            selectedLoRAs: .constant(mockLoRAs)
        )
    }
    .formStyle(.grouped)
    .frame(width: 400, height: 350)
}
#endif
