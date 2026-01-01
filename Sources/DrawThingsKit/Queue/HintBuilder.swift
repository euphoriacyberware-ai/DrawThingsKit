//
//  HintBuilder.swift
//  DrawThingsKit
//
//  Created by euphoriacyberware-ai.
//  Copyright © 2025 euphoriacyberware-ai
//
//  Licensed under the MIT License.
//  See LICENSE file in the project root for license information.
//

import Foundation

/// Known hint types supported by Draw Things.
public enum HintType: String, CaseIterable, Sendable {
    /// Moodboard/reference images for style transfer.
    /// Used with Qwen Image Edit - images become "image 2", "image 3", etc.
    case shuffle = "shuffle"

    /// Depth map for structural guidance.
    case depth = "depth"

    /// Pose skeleton for character positioning.
    case pose = "pose"

    /// Edge detection for structural guidance.
    case canny = "canny"

    /// Rough sketches for composition.
    case scribble = "scribble"

    /// Color palette reference.
    case color = "color"

    /// Line art for structural guidance.
    case lineart = "lineart"

    /// Soft edge detection.
    case softedge = "softedge"

    /// Segmentation map.
    case seg = "seg"

    /// Inpainting hint.
    case inpaint = "inpaint"

    /// Image-to-image prompt (ip2p).
    case ip2p = "ip2p"

    /// MLSD line detection.
    case mlsd = "mlsd"

    /// Tile-based generation.
    case tile = "tile"

    /// Blur hint.
    case blur = "blur"

    /// Low quality hint.
    case lowquality = "lowquality"

    /// Grayscale hint.
    case gray = "gray"

    /// Custom/generic hint type.
    case custom = "custom"
}

/// Builder for constructing hints for image generation.
///
/// Use this helper to properly construct hints that will work with Draw Things.
/// Multiple hints of the same type are automatically grouped together.
///
/// Example usage with Qwen Image Edit:
/// ```swift
/// let hints = HintBuilder()
///     .addMoodboardImage(dressImageData, weight: 1.0)   // becomes "image 2"
///     .addMoodboardImage(styleImageData, weight: 0.8)  // becomes "image 3"
///     .build()
///
/// let job = try GenerationJob(
///     prompt: "Person wearing the dress from image 2 in the style of image 3",
///     configuration: config,
///     canvasImageData: personImageData,  // This is "image 1"
///     hints: hints
/// )
/// ```
public final class HintBuilder: @unchecked Sendable {
    private var hints: [HintData] = []

    public init() {}

    // MARK: - Moodboard/Shuffle Hints

    /// Add a moodboard (shuffle) reference image.
    ///
    /// Moodboard images are used for style/content transfer with models like Qwen Image Edit.
    /// They become "image 2", "image 3", etc. in order of addition (canvas is "image 1").
    ///
    /// - Parameters:
    ///   - imageData: The image data (PNG or JPEG)
    ///   - weight: Influence strength (0.0-2.0, default 1.0)
    /// - Returns: Self for chaining
    @discardableResult
    public func addMoodboardImage(_ imageData: Data, weight: Float = 1.0) -> HintBuilder {
        hints.append(HintData(type: HintType.shuffle.rawValue, imageData: imageData, weight: weight))
        return self
    }

    /// Add multiple moodboard images with the same weight.
    ///
    /// - Parameters:
    ///   - images: Array of image data
    ///   - weight: Influence strength for all images (0.0-2.0, default 1.0)
    /// - Returns: Self for chaining
    @discardableResult
    public func addMoodboardImages(_ images: [Data], weight: Float = 1.0) -> HintBuilder {
        for imageData in images {
            hints.append(HintData(type: HintType.shuffle.rawValue, imageData: imageData, weight: weight))
        }
        return self
    }

    /// Add multiple moodboard images with individual weights.
    ///
    /// - Parameter imagesWithWeights: Array of (imageData, weight) tuples
    /// - Returns: Self for chaining
    @discardableResult
    public func addMoodboardImages(_ imagesWithWeights: [(data: Data, weight: Float)]) -> HintBuilder {
        for (imageData, weight) in imagesWithWeights {
            hints.append(HintData(type: HintType.shuffle.rawValue, imageData: imageData, weight: weight))
        }
        return self
    }

    // MARK: - ControlNet Hints

    /// Add a depth map hint for structural guidance.
    ///
    /// - Parameters:
    ///   - imageData: Depth map image data
    ///   - weight: Influence strength (0.0-2.0, default 1.0)
    /// - Returns: Self for chaining
    @discardableResult
    public func addDepthMap(_ imageData: Data, weight: Float = 1.0) -> HintBuilder {
        hints.append(HintData(type: HintType.depth.rawValue, imageData: imageData, weight: weight))
        return self
    }

    /// Add a pose skeleton hint for character positioning.
    ///
    /// - Parameters:
    ///   - imageData: Pose skeleton image data
    ///   - weight: Influence strength (0.0-2.0, default 1.0)
    /// - Returns: Self for chaining
    @discardableResult
    public func addPose(_ imageData: Data, weight: Float = 1.0) -> HintBuilder {
        hints.append(HintData(type: HintType.pose.rawValue, imageData: imageData, weight: weight))
        return self
    }

    /// Add a canny edge detection hint.
    ///
    /// - Parameters:
    ///   - imageData: Edge detection image data
    ///   - weight: Influence strength (0.0-2.0, default 1.0)
    /// - Returns: Self for chaining
    @discardableResult
    public func addCannyEdges(_ imageData: Data, weight: Float = 1.0) -> HintBuilder {
        hints.append(HintData(type: HintType.canny.rawValue, imageData: imageData, weight: weight))
        return self
    }

    /// Add a scribble/sketch hint.
    ///
    /// - Parameters:
    ///   - imageData: Scribble image data
    ///   - weight: Influence strength (0.0-2.0, default 1.0)
    /// - Returns: Self for chaining
    @discardableResult
    public func addScribble(_ imageData: Data, weight: Float = 1.0) -> HintBuilder {
        hints.append(HintData(type: HintType.scribble.rawValue, imageData: imageData, weight: weight))
        return self
    }

    /// Add a color palette hint.
    ///
    /// - Parameters:
    ///   - imageData: Color reference image data
    ///   - weight: Influence strength (0.0-2.0, default 1.0)
    /// - Returns: Self for chaining
    @discardableResult
    public func addColorReference(_ imageData: Data, weight: Float = 1.0) -> HintBuilder {
        hints.append(HintData(type: HintType.color.rawValue, imageData: imageData, weight: weight))
        return self
    }

    /// Add a line art hint.
    ///
    /// - Parameters:
    ///   - imageData: Line art image data
    ///   - weight: Influence strength (0.0-2.0, default 1.0)
    /// - Returns: Self for chaining
    @discardableResult
    public func addLineArt(_ imageData: Data, weight: Float = 1.0) -> HintBuilder {
        hints.append(HintData(type: HintType.lineart.rawValue, imageData: imageData, weight: weight))
        return self
    }

    // MARK: - Generic Hint

    /// Add a hint with a custom type.
    ///
    /// - Parameters:
    ///   - type: The hint type (use HintType enum or custom string)
    ///   - imageData: The image data
    ///   - weight: Influence strength (0.0-2.0, default 1.0)
    /// - Returns: Self for chaining
    @discardableResult
    public func addHint(type: HintType, imageData: Data, weight: Float = 1.0) -> HintBuilder {
        hints.append(HintData(type: type.rawValue, imageData: imageData, weight: weight))
        return self
    }

    /// Add a hint with a custom type string.
    ///
    /// - Parameters:
    ///   - type: The hint type string
    ///   - imageData: The image data
    ///   - weight: Influence strength (0.0-2.0, default 1.0)
    /// - Returns: Self for chaining
    @discardableResult
    public func addHint(type: String, imageData: Data, weight: Float = 1.0) -> HintBuilder {
        hints.append(HintData(type: type, imageData: imageData, weight: weight))
        return self
    }

    // MARK: - Build

    /// Build the final array of hints.
    ///
    /// - Returns: Array of HintData ready to pass to GenerationJob
    public func build() -> [HintData] {
        return hints
    }

    /// Clear all hints and start fresh.
    @discardableResult
    public func clear() -> HintBuilder {
        hints.removeAll()
        return self
    }

    /// The current number of hints.
    public var count: Int {
        hints.count
    }

    /// Whether there are any hints.
    public var isEmpty: Bool {
        hints.isEmpty
    }
}

// MARK: - Convenience Extensions

extension GenerationJob {
    /// Create a generation job with hints using the builder pattern.
    ///
    /// Example:
    /// ```swift
    /// let job = try GenerationJob(
    ///     prompt: "A portrait in the style of image 2",
    ///     configuration: config,
    ///     canvasImageData: sourceImage
    /// ) { builder in
    ///     builder.addMoodboardImage(styleReference, weight: 1.0)
    /// }
    /// ```
    public init(
        id: UUID = UUID(),
        name: String? = nil,
        prompt: String,
        negativePrompt: String = "",
        configuration: DrawThingsConfiguration,
        canvasImageData: Data? = nil,
        maskImageData: Data? = nil,
        buildHints: (HintBuilder) -> Void
    ) throws {
        let builder = HintBuilder()
        buildHints(builder)
        try self.init(
            id: id,
            name: name,
            prompt: prompt,
            negativePrompt: negativePrompt,
            configuration: configuration,
            canvasImageData: canvasImageData,
            maskImageData: maskImageData,
            hints: builder.build()
        )
    }
}
