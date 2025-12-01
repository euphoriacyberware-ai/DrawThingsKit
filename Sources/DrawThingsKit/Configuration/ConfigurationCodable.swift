//
//  ConfigurationCodable.swift
//  DrawThingsKit
//
//  JSON serialization extension for DrawThingsConfiguration.
//

import Foundation
import DrawThingsClient

// MARK: - JSON Codable Support

/// A Codable wrapper for DrawThingsConfiguration that enables JSON serialization.
/// This is separate from the FlatBuffer serialization used for gRPC communication.
public struct ConfigurationJSON: Codable {
    // Core parameters
    public var width: Int32
    public var height: Int32
    public var steps: Int32
    public var model: String
    public var sampler: Int  // Index into SamplerType enum
    public var guidanceScale: Float
    public var seed: Int64?
    public var clipSkip: Int32
    public var shift: Float

    // Batch parameters
    public var batchCount: Int32
    public var batchSize: Int32
    public var strength: Float

    // Guidance parameters
    public var imageGuidanceScale: Float
    public var clipWeight: Float
    public var guidanceEmbed: Float
    public var speedUpWithGuidanceEmbed: Bool
    public var cfgZeroStar: Bool
    public var cfgZeroInitSteps: Int32

    // Mask/Inpaint parameters
    public var maskBlur: Float
    public var maskBlurOutset: Int32
    public var preserveOriginalAfterInpaint: Bool
    public var enableInpainting: Bool

    // Quality parameters
    public var sharpness: Float
    public var stochasticSamplingGamma: Float
    public var aestheticScore: Float
    public var negativeAestheticScore: Float

    // Image prior parameters
    public var negativePromptForImagePrior: Bool
    public var imagePriorSteps: Int32

    // Crop/Size parameters
    public var cropTop: Int32
    public var cropLeft: Int32
    public var originalImageHeight: Int32
    public var originalImageWidth: Int32
    public var targetImageHeight: Int32
    public var targetImageWidth: Int32
    public var negativeOriginalImageHeight: Int32
    public var negativeOriginalImageWidth: Int32

    // Upscaler parameters
    public var upscalerScaleFactor: Int32

    // Text encoder parameters
    public var resolutionDependentShift: Bool
    public var t5TextEncoder: Bool
    public var separateClipL: Bool
    public var separateOpenClipG: Bool
    public var separateT5: Bool

    // Tiled parameters
    public var tiledDiffusion: Bool
    public var diffusionTileWidth: Int32
    public var diffusionTileHeight: Int32
    public var diffusionTileOverlap: Int32
    public var tiledDecoding: Bool
    public var decodingTileWidth: Int32
    public var decodingTileHeight: Int32
    public var decodingTileOverlap: Int32

    // HiRes Fix parameters
    public var hiresFix: Bool
    public var hiresFixWidth: Int32
    public var hiresFixHeight: Int32
    public var hiresFixStrength: Float

    // Stage 2 parameters
    public var stage2Steps: Int32
    public var stage2Guidance: Float
    public var stage2Shift: Float

    // TEA Cache parameters
    public var teaCache: Bool
    public var teaCacheStart: Int32
    public var teaCacheEnd: Int32
    public var teaCacheThreshold: Float
    public var teaCacheMaxSkipSteps: Int32

    // Causal inference parameters
    public var causalInference: Int32
    public var causalInferencePad: Int32

    // Video parameters
    public var fps: Int32
    public var motionScale: Int32
    public var guidingFrameNoise: Float
    public var startFrameGuidance: Float
    public var numFrames: Int32

    // Refiner parameters
    public var refinerModel: String?
    public var refinerStart: Float
    public var zeroNegativePrompt: Bool

    // Upscaler and face restoration
    public var upscaler: String?
    public var faceRestoration: String?

    // Configuration name
    public var name: String?

    // Separate text encoder prompts
    public var clipLText: String?
    public var openClipGText: String?
    public var t5Text: String?

    // Seed mode
    public var seedMode: Int32

    // LoRAs
    public var loras: [LoRAJSON]

    // Controls
    public var controls: [ControlJSON]

    public struct LoRAJSON: Codable {
        public var file: String
        public var weight: Float
        public var mode: Int  // 0=all, 1=base, 2=refiner

        public init(file: String, weight: Float, mode: Int = 0) {
            self.file = file
            self.weight = weight
            self.mode = mode
        }

        enum CodingKeys: String, CodingKey {
            case file, weight, mode
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            file = try container.decode(String.self, forKey: .file)
            weight = try container.decodeIfPresent(Float.self, forKey: .weight) ?? 1.0

            // Support both int and string for mode (Draw Things exports as string)
            // Try int first, fall back to string parsing
            if let modeInt = try? container.decode(Int.self, forKey: .mode) {
                mode = modeInt
            } else if let modeString = try? container.decode(String.self, forKey: .mode) {
                switch modeString.lowercased() {
                case "all": mode = 0
                case "base": mode = 1
                case "refiner": mode = 2
                default: mode = 0
                }
            } else {
                mode = 0
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(file, forKey: .file)
            try container.encode(weight, forKey: .weight)
            // Encode mode as string to match Draw Things format
            let modeString: String
            switch mode {
            case 0: modeString = "all"
            case 1: modeString = "base"
            case 2: modeString = "refiner"
            default: modeString = "all"
            }
            try container.encode(modeString, forKey: .mode)
        }
    }

    public struct ControlJSON: Codable {
        public var file: String
        public var weight: Float
        public var guidanceStart: Float
        public var guidanceEnd: Float
        public var controlMode: Int  // 0=balanced, 1=prompt, 2=control
        public var inputOverride: String
        public var noPrompt: Bool
        public var globalAveragePooling: Bool
        public var downSamplingRate: Float
        public var targetBlocks: [String]

        public init(
            file: String,
            weight: Float = 1.0,
            guidanceStart: Float = 0.0,
            guidanceEnd: Float = 1.0,
            controlMode: Int = 0,
            inputOverride: String = "",
            noPrompt: Bool = false,
            globalAveragePooling: Bool = false,
            downSamplingRate: Float = 1.0,
            targetBlocks: [String] = []
        ) {
            self.file = file
            self.weight = weight
            self.guidanceStart = guidanceStart
            self.guidanceEnd = guidanceEnd
            self.controlMode = controlMode
            self.inputOverride = inputOverride
            self.noPrompt = noPrompt
            self.globalAveragePooling = globalAveragePooling
            self.downSamplingRate = downSamplingRate
            self.targetBlocks = targetBlocks
        }

        enum CodingKeys: String, CodingKey {
            case file, weight, guidanceStart, guidanceEnd
            case controlMode, controlImportance  // Support both names
            case inputOverride, noPrompt, globalAveragePooling, downSamplingRate, targetBlocks
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            file = try container.decode(String.self, forKey: .file)
            weight = try container.decodeIfPresent(Float.self, forKey: .weight) ?? 1.0
            guidanceStart = try container.decodeIfPresent(Float.self, forKey: .guidanceStart) ?? 0.0
            guidanceEnd = try container.decodeIfPresent(Float.self, forKey: .guidanceEnd) ?? 1.0

            // Support both controlMode (int) and controlImportance (string)
            if let mode = try container.decodeIfPresent(Int.self, forKey: .controlMode) {
                controlMode = mode
            } else if let importance = try container.decodeIfPresent(String.self, forKey: .controlImportance) {
                // Map string to int
                switch importance.lowercased() {
                case "balanced": controlMode = 0
                case "prompt": controlMode = 1
                case "control": controlMode = 2
                default: controlMode = 0
                }
            } else {
                controlMode = 0
            }

            inputOverride = try container.decodeIfPresent(String.self, forKey: .inputOverride) ?? ""
            noPrompt = try container.decodeIfPresent(Bool.self, forKey: .noPrompt) ?? false
            globalAveragePooling = try container.decodeIfPresent(Bool.self, forKey: .globalAveragePooling) ?? false
            downSamplingRate = try container.decodeIfPresent(Float.self, forKey: .downSamplingRate) ?? 1.0
            targetBlocks = try container.decodeIfPresent([String].self, forKey: .targetBlocks) ?? []
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(file, forKey: .file)
            try container.encode(weight, forKey: .weight)
            try container.encode(guidanceStart, forKey: .guidanceStart)
            try container.encode(guidanceEnd, forKey: .guidanceEnd)
            try container.encode(controlMode, forKey: .controlMode)
            try container.encode(inputOverride, forKey: .inputOverride)
            try container.encode(noPrompt, forKey: .noPrompt)
            try container.encode(globalAveragePooling, forKey: .globalAveragePooling)
            try container.encode(downSamplingRate, forKey: .downSamplingRate)
            try container.encode(targetBlocks, forKey: .targetBlocks)
        }
    }

    // MARK: - Memberwise Initializer

    public init(
        width: Int32, height: Int32, steps: Int32, model: String, sampler: Int,
        guidanceScale: Float, seed: Int64?, clipSkip: Int32, shift: Float,
        batchCount: Int32, batchSize: Int32, strength: Float,
        imageGuidanceScale: Float, clipWeight: Float, guidanceEmbed: Float,
        speedUpWithGuidanceEmbed: Bool, cfgZeroStar: Bool, cfgZeroInitSteps: Int32,
        maskBlur: Float, maskBlurOutset: Int32, preserveOriginalAfterInpaint: Bool, enableInpainting: Bool,
        sharpness: Float, stochasticSamplingGamma: Float, aestheticScore: Float, negativeAestheticScore: Float,
        negativePromptForImagePrior: Bool, imagePriorSteps: Int32,
        cropTop: Int32, cropLeft: Int32, originalImageHeight: Int32, originalImageWidth: Int32,
        targetImageHeight: Int32, targetImageWidth: Int32, negativeOriginalImageHeight: Int32, negativeOriginalImageWidth: Int32,
        upscalerScaleFactor: Int32,
        resolutionDependentShift: Bool, t5TextEncoder: Bool, separateClipL: Bool, separateOpenClipG: Bool, separateT5: Bool,
        tiledDiffusion: Bool, diffusionTileWidth: Int32, diffusionTileHeight: Int32, diffusionTileOverlap: Int32,
        tiledDecoding: Bool, decodingTileWidth: Int32, decodingTileHeight: Int32, decodingTileOverlap: Int32,
        hiresFix: Bool, hiresFixWidth: Int32, hiresFixHeight: Int32, hiresFixStrength: Float,
        stage2Steps: Int32, stage2Guidance: Float, stage2Shift: Float,
        teaCache: Bool, teaCacheStart: Int32, teaCacheEnd: Int32, teaCacheThreshold: Float, teaCacheMaxSkipSteps: Int32,
        causalInference: Int32, causalInferencePad: Int32,
        fps: Int32, motionScale: Int32, guidingFrameNoise: Float, startFrameGuidance: Float, numFrames: Int32,
        refinerModel: String?, refinerStart: Float, zeroNegativePrompt: Bool,
        upscaler: String?, faceRestoration: String?, name: String?,
        clipLText: String?, openClipGText: String?, t5Text: String?,
        seedMode: Int32, loras: [LoRAJSON], controls: [ControlJSON]
    ) {
        self.width = width; self.height = height; self.steps = steps; self.model = model; self.sampler = sampler
        self.guidanceScale = guidanceScale; self.seed = seed; self.clipSkip = clipSkip; self.shift = shift
        self.batchCount = batchCount; self.batchSize = batchSize; self.strength = strength
        self.imageGuidanceScale = imageGuidanceScale; self.clipWeight = clipWeight; self.guidanceEmbed = guidanceEmbed
        self.speedUpWithGuidanceEmbed = speedUpWithGuidanceEmbed; self.cfgZeroStar = cfgZeroStar; self.cfgZeroInitSteps = cfgZeroInitSteps
        self.maskBlur = maskBlur; self.maskBlurOutset = maskBlurOutset
        self.preserveOriginalAfterInpaint = preserveOriginalAfterInpaint; self.enableInpainting = enableInpainting
        self.sharpness = sharpness; self.stochasticSamplingGamma = stochasticSamplingGamma
        self.aestheticScore = aestheticScore; self.negativeAestheticScore = negativeAestheticScore
        self.negativePromptForImagePrior = negativePromptForImagePrior; self.imagePriorSteps = imagePriorSteps
        self.cropTop = cropTop; self.cropLeft = cropLeft
        self.originalImageHeight = originalImageHeight; self.originalImageWidth = originalImageWidth
        self.targetImageHeight = targetImageHeight; self.targetImageWidth = targetImageWidth
        self.negativeOriginalImageHeight = negativeOriginalImageHeight; self.negativeOriginalImageWidth = negativeOriginalImageWidth
        self.upscalerScaleFactor = upscalerScaleFactor
        self.resolutionDependentShift = resolutionDependentShift; self.t5TextEncoder = t5TextEncoder
        self.separateClipL = separateClipL; self.separateOpenClipG = separateOpenClipG; self.separateT5 = separateT5
        self.tiledDiffusion = tiledDiffusion; self.diffusionTileWidth = diffusionTileWidth
        self.diffusionTileHeight = diffusionTileHeight; self.diffusionTileOverlap = diffusionTileOverlap
        self.tiledDecoding = tiledDecoding; self.decodingTileWidth = decodingTileWidth
        self.decodingTileHeight = decodingTileHeight; self.decodingTileOverlap = decodingTileOverlap
        self.hiresFix = hiresFix; self.hiresFixWidth = hiresFixWidth
        self.hiresFixHeight = hiresFixHeight; self.hiresFixStrength = hiresFixStrength
        self.stage2Steps = stage2Steps; self.stage2Guidance = stage2Guidance; self.stage2Shift = stage2Shift
        self.teaCache = teaCache; self.teaCacheStart = teaCacheStart; self.teaCacheEnd = teaCacheEnd
        self.teaCacheThreshold = teaCacheThreshold; self.teaCacheMaxSkipSteps = teaCacheMaxSkipSteps
        self.causalInference = causalInference; self.causalInferencePad = causalInferencePad
        self.fps = fps; self.motionScale = motionScale; self.guidingFrameNoise = guidingFrameNoise
        self.startFrameGuidance = startFrameGuidance; self.numFrames = numFrames
        self.refinerModel = refinerModel; self.refinerStart = refinerStart; self.zeroNegativePrompt = zeroNegativePrompt
        self.upscaler = upscaler; self.faceRestoration = faceRestoration; self.name = name
        self.clipLText = clipLText; self.openClipGText = openClipGText; self.t5Text = t5Text
        self.seedMode = seedMode; self.loras = loras; self.controls = controls
    }

    // MARK: - Custom Decoding with Defaults

    enum CodingKeys: String, CodingKey {
        case width, height, steps, model, sampler, guidanceScale, seed, clipSkip, shift
        case batchCount, batchSize, strength
        case imageGuidanceScale, clipWeight, guidanceEmbed, speedUpWithGuidanceEmbed, cfgZeroStar, cfgZeroInitSteps
        case maskBlur, maskBlurOutset, preserveOriginalAfterInpaint, enableInpainting
        case sharpness, stochasticSamplingGamma, aestheticScore, negativeAestheticScore
        case negativePromptForImagePrior, imagePriorSteps
        case cropTop, cropLeft, originalImageHeight, originalImageWidth
        case targetImageHeight, targetImageWidth, negativeOriginalImageHeight, negativeOriginalImageWidth
        case upscalerScaleFactor
        case resolutionDependentShift, t5TextEncoder, separateClipL, separateOpenClipG, separateT5
        case tiledDiffusion, diffusionTileWidth, diffusionTileHeight, diffusionTileOverlap
        case tiledDecoding, decodingTileWidth, decodingTileHeight, decodingTileOverlap
        case hiresFix, hiresFixWidth, hiresFixHeight, hiresFixStrength
        case stage2Steps, stage2Guidance, stage2Shift
        case teaCache, teaCacheStart, teaCacheEnd, teaCacheThreshold, teaCacheMaxSkipSteps
        case causalInference, causalInferencePad
        case fps, motionScale, guidingFrameNoise, startFrameGuidance, numFrames
        case refinerModel, refinerStart, zeroNegativePrompt
        case upscaler, faceRestoration, name
        case clipLText, openClipGText, t5Text
        case seedMode, loras, controls
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Use defaults from DrawThingsConfiguration for missing values
        let defaults = DrawThingsConfiguration()

        width = try container.decodeIfPresent(Int32.self, forKey: .width) ?? defaults.width
        height = try container.decodeIfPresent(Int32.self, forKey: .height) ?? defaults.height
        steps = try container.decodeIfPresent(Int32.self, forKey: .steps) ?? defaults.steps
        model = try container.decodeIfPresent(String.self, forKey: .model) ?? defaults.model
        sampler = try container.decodeIfPresent(Int.self, forKey: .sampler) ?? Int(defaults.sampler.rawValue)
        guidanceScale = try container.decodeIfPresent(Float.self, forKey: .guidanceScale) ?? defaults.guidanceScale
        seed = try container.decodeIfPresent(Int64.self, forKey: .seed) ?? defaults.seed
        clipSkip = try container.decodeIfPresent(Int32.self, forKey: .clipSkip) ?? defaults.clipSkip
        shift = try container.decodeIfPresent(Float.self, forKey: .shift) ?? defaults.shift

        batchCount = try container.decodeIfPresent(Int32.self, forKey: .batchCount) ?? defaults.batchCount
        batchSize = try container.decodeIfPresent(Int32.self, forKey: .batchSize) ?? defaults.batchSize
        strength = try container.decodeIfPresent(Float.self, forKey: .strength) ?? defaults.strength

        imageGuidanceScale = try container.decodeIfPresent(Float.self, forKey: .imageGuidanceScale) ?? defaults.imageGuidanceScale
        clipWeight = try container.decodeIfPresent(Float.self, forKey: .clipWeight) ?? defaults.clipWeight
        guidanceEmbed = try container.decodeIfPresent(Float.self, forKey: .guidanceEmbed) ?? defaults.guidanceEmbed
        speedUpWithGuidanceEmbed = try container.decodeIfPresent(Bool.self, forKey: .speedUpWithGuidanceEmbed) ?? defaults.speedUpWithGuidanceEmbed
        cfgZeroStar = try container.decodeIfPresent(Bool.self, forKey: .cfgZeroStar) ?? defaults.cfgZeroStar
        cfgZeroInitSteps = try container.decodeIfPresent(Int32.self, forKey: .cfgZeroInitSteps) ?? defaults.cfgZeroInitSteps

        maskBlur = try container.decodeIfPresent(Float.self, forKey: .maskBlur) ?? defaults.maskBlur
        maskBlurOutset = try container.decodeIfPresent(Int32.self, forKey: .maskBlurOutset) ?? defaults.maskBlurOutset
        preserveOriginalAfterInpaint = try container.decodeIfPresent(Bool.self, forKey: .preserveOriginalAfterInpaint) ?? defaults.preserveOriginalAfterInpaint
        enableInpainting = try container.decodeIfPresent(Bool.self, forKey: .enableInpainting) ?? defaults.enableInpainting

        sharpness = try container.decodeIfPresent(Float.self, forKey: .sharpness) ?? defaults.sharpness
        stochasticSamplingGamma = try container.decodeIfPresent(Float.self, forKey: .stochasticSamplingGamma) ?? defaults.stochasticSamplingGamma
        aestheticScore = try container.decodeIfPresent(Float.self, forKey: .aestheticScore) ?? defaults.aestheticScore
        negativeAestheticScore = try container.decodeIfPresent(Float.self, forKey: .negativeAestheticScore) ?? defaults.negativeAestheticScore

        negativePromptForImagePrior = try container.decodeIfPresent(Bool.self, forKey: .negativePromptForImagePrior) ?? defaults.negativePromptForImagePrior
        imagePriorSteps = try container.decodeIfPresent(Int32.self, forKey: .imagePriorSteps) ?? defaults.imagePriorSteps

        cropTop = try container.decodeIfPresent(Int32.self, forKey: .cropTop) ?? defaults.cropTop
        cropLeft = try container.decodeIfPresent(Int32.self, forKey: .cropLeft) ?? defaults.cropLeft
        originalImageHeight = try container.decodeIfPresent(Int32.self, forKey: .originalImageHeight) ?? defaults.originalImageHeight
        originalImageWidth = try container.decodeIfPresent(Int32.self, forKey: .originalImageWidth) ?? defaults.originalImageWidth
        targetImageHeight = try container.decodeIfPresent(Int32.self, forKey: .targetImageHeight) ?? defaults.targetImageHeight
        targetImageWidth = try container.decodeIfPresent(Int32.self, forKey: .targetImageWidth) ?? defaults.targetImageWidth
        negativeOriginalImageHeight = try container.decodeIfPresent(Int32.self, forKey: .negativeOriginalImageHeight) ?? defaults.negativeOriginalImageHeight
        negativeOriginalImageWidth = try container.decodeIfPresent(Int32.self, forKey: .negativeOriginalImageWidth) ?? defaults.negativeOriginalImageWidth

        upscalerScaleFactor = try container.decodeIfPresent(Int32.self, forKey: .upscalerScaleFactor) ?? defaults.upscalerScaleFactor

        resolutionDependentShift = try container.decodeIfPresent(Bool.self, forKey: .resolutionDependentShift) ?? defaults.resolutionDependentShift
        t5TextEncoder = try container.decodeIfPresent(Bool.self, forKey: .t5TextEncoder) ?? defaults.t5TextEncoder
        separateClipL = try container.decodeIfPresent(Bool.self, forKey: .separateClipL) ?? defaults.separateClipL
        separateOpenClipG = try container.decodeIfPresent(Bool.self, forKey: .separateOpenClipG) ?? defaults.separateOpenClipG
        separateT5 = try container.decodeIfPresent(Bool.self, forKey: .separateT5) ?? defaults.separateT5

        tiledDiffusion = try container.decodeIfPresent(Bool.self, forKey: .tiledDiffusion) ?? defaults.tiledDiffusion
        diffusionTileWidth = try container.decodeIfPresent(Int32.self, forKey: .diffusionTileWidth) ?? defaults.diffusionTileWidth
        diffusionTileHeight = try container.decodeIfPresent(Int32.self, forKey: .diffusionTileHeight) ?? defaults.diffusionTileHeight
        diffusionTileOverlap = try container.decodeIfPresent(Int32.self, forKey: .diffusionTileOverlap) ?? defaults.diffusionTileOverlap
        tiledDecoding = try container.decodeIfPresent(Bool.self, forKey: .tiledDecoding) ?? defaults.tiledDecoding
        decodingTileWidth = try container.decodeIfPresent(Int32.self, forKey: .decodingTileWidth) ?? defaults.decodingTileWidth
        decodingTileHeight = try container.decodeIfPresent(Int32.self, forKey: .decodingTileHeight) ?? defaults.decodingTileHeight
        decodingTileOverlap = try container.decodeIfPresent(Int32.self, forKey: .decodingTileOverlap) ?? defaults.decodingTileOverlap

        hiresFix = try container.decodeIfPresent(Bool.self, forKey: .hiresFix) ?? defaults.hiresFix
        hiresFixWidth = try container.decodeIfPresent(Int32.self, forKey: .hiresFixWidth) ?? defaults.hiresFixWidth
        hiresFixHeight = try container.decodeIfPresent(Int32.self, forKey: .hiresFixHeight) ?? defaults.hiresFixHeight
        hiresFixStrength = try container.decodeIfPresent(Float.self, forKey: .hiresFixStrength) ?? defaults.hiresFixStrength

        stage2Steps = try container.decodeIfPresent(Int32.self, forKey: .stage2Steps) ?? defaults.stage2Steps
        stage2Guidance = try container.decodeIfPresent(Float.self, forKey: .stage2Guidance) ?? defaults.stage2Guidance
        stage2Shift = try container.decodeIfPresent(Float.self, forKey: .stage2Shift) ?? defaults.stage2Shift

        teaCache = try container.decodeIfPresent(Bool.self, forKey: .teaCache) ?? defaults.teaCache
        teaCacheStart = try container.decodeIfPresent(Int32.self, forKey: .teaCacheStart) ?? defaults.teaCacheStart
        teaCacheEnd = try container.decodeIfPresent(Int32.self, forKey: .teaCacheEnd) ?? defaults.teaCacheEnd
        teaCacheThreshold = try container.decodeIfPresent(Float.self, forKey: .teaCacheThreshold) ?? defaults.teaCacheThreshold
        teaCacheMaxSkipSteps = try container.decodeIfPresent(Int32.self, forKey: .teaCacheMaxSkipSteps) ?? defaults.teaCacheMaxSkipSteps

        causalInference = try container.decodeIfPresent(Int32.self, forKey: .causalInference) ?? defaults.causalInference
        causalInferencePad = try container.decodeIfPresent(Int32.self, forKey: .causalInferencePad) ?? defaults.causalInferencePad

        fps = try container.decodeIfPresent(Int32.self, forKey: .fps) ?? defaults.fps
        motionScale = try container.decodeIfPresent(Int32.self, forKey: .motionScale) ?? defaults.motionScale
        guidingFrameNoise = try container.decodeIfPresent(Float.self, forKey: .guidingFrameNoise) ?? defaults.guidingFrameNoise
        startFrameGuidance = try container.decodeIfPresent(Float.self, forKey: .startFrameGuidance) ?? defaults.startFrameGuidance
        numFrames = try container.decodeIfPresent(Int32.self, forKey: .numFrames) ?? defaults.numFrames

        refinerStart = try container.decodeIfPresent(Float.self, forKey: .refinerStart) ?? defaults.refinerStart
        zeroNegativePrompt = try container.decodeIfPresent(Bool.self, forKey: .zeroNegativePrompt) ?? defaults.zeroNegativePrompt

        // Treat empty strings as nil for optional model/file fields
        if let refinerModelValue = try container.decodeIfPresent(String.self, forKey: .refinerModel), !refinerModelValue.isEmpty {
            refinerModel = refinerModelValue
        } else {
            refinerModel = defaults.refinerModel
        }
        if let upscalerValue = try container.decodeIfPresent(String.self, forKey: .upscaler), !upscalerValue.isEmpty {
            upscaler = upscalerValue
        } else {
            upscaler = defaults.upscaler
        }
        if let faceRestorationValue = try container.decodeIfPresent(String.self, forKey: .faceRestoration), !faceRestorationValue.isEmpty {
            faceRestoration = faceRestorationValue
        } else {
            faceRestoration = defaults.faceRestoration
        }
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? defaults.name

        clipLText = try container.decodeIfPresent(String.self, forKey: .clipLText) ?? defaults.clipLText
        openClipGText = try container.decodeIfPresent(String.self, forKey: .openClipGText) ?? defaults.openClipGText
        t5Text = try container.decodeIfPresent(String.self, forKey: .t5Text) ?? defaults.t5Text

        seedMode = try container.decodeIfPresent(Int32.self, forKey: .seedMode) ?? defaults.seedMode

        // Arrays default to empty
        if let lorasArray = try container.decodeIfPresent([LoRAJSON].self, forKey: .loras) {
            loras = lorasArray
        } else {
            loras = defaults.loras.map { LoRAJSON(file: $0.file, weight: $0.weight, mode: Int($0.mode.rawValue)) }
        }

        if let controlsArray = try container.decodeIfPresent([ControlJSON].self, forKey: .controls) {
            controls = controlsArray
        } else {
            controls = defaults.controls.map { ControlJSON(file: $0.file, weight: $0.weight, guidanceStart: $0.guidanceStart, guidanceEnd: $0.guidanceEnd, controlMode: Int($0.controlMode.rawValue)) }
        }
    }
}

// MARK: - DrawThingsConfiguration Extension

extension DrawThingsConfiguration {
    /// Convert configuration to a JSON string.
    /// - Parameter includeSeed: Whether to include the seed value. Defaults to true.
    /// - Returns: JSON string representation of the configuration.
    public func toJSON(includeSeed: Bool = true) throws -> String {
        let json = ConfigurationJSON(
            width: width,
            height: height,
            steps: steps,
            model: model,
            sampler: Int(sampler.rawValue),
            guidanceScale: guidanceScale,
            seed: includeSeed ? seed : nil,
            clipSkip: clipSkip,
            shift: shift,
            batchCount: batchCount,
            batchSize: batchSize,
            strength: strength,
            imageGuidanceScale: imageGuidanceScale,
            clipWeight: clipWeight,
            guidanceEmbed: guidanceEmbed,
            speedUpWithGuidanceEmbed: speedUpWithGuidanceEmbed,
            cfgZeroStar: cfgZeroStar,
            cfgZeroInitSteps: cfgZeroInitSteps,
            maskBlur: maskBlur,
            maskBlurOutset: maskBlurOutset,
            preserveOriginalAfterInpaint: preserveOriginalAfterInpaint,
            enableInpainting: enableInpainting,
            sharpness: sharpness,
            stochasticSamplingGamma: stochasticSamplingGamma,
            aestheticScore: aestheticScore,
            negativeAestheticScore: negativeAestheticScore,
            negativePromptForImagePrior: negativePromptForImagePrior,
            imagePriorSteps: imagePriorSteps,
            cropTop: cropTop,
            cropLeft: cropLeft,
            originalImageHeight: originalImageHeight,
            originalImageWidth: originalImageWidth,
            targetImageHeight: targetImageHeight,
            targetImageWidth: targetImageWidth,
            negativeOriginalImageHeight: negativeOriginalImageHeight,
            negativeOriginalImageWidth: negativeOriginalImageWidth,
            upscalerScaleFactor: upscalerScaleFactor,
            resolutionDependentShift: resolutionDependentShift,
            t5TextEncoder: t5TextEncoder,
            separateClipL: separateClipL,
            separateOpenClipG: separateOpenClipG,
            separateT5: separateT5,
            tiledDiffusion: tiledDiffusion,
            diffusionTileWidth: diffusionTileWidth,
            diffusionTileHeight: diffusionTileHeight,
            diffusionTileOverlap: diffusionTileOverlap,
            tiledDecoding: tiledDecoding,
            decodingTileWidth: decodingTileWidth,
            decodingTileHeight: decodingTileHeight,
            decodingTileOverlap: decodingTileOverlap,
            hiresFix: hiresFix,
            hiresFixWidth: hiresFixWidth,
            hiresFixHeight: hiresFixHeight,
            hiresFixStrength: hiresFixStrength,
            stage2Steps: stage2Steps,
            stage2Guidance: stage2Guidance,
            stage2Shift: stage2Shift,
            teaCache: teaCache,
            teaCacheStart: teaCacheStart,
            teaCacheEnd: teaCacheEnd,
            teaCacheThreshold: teaCacheThreshold,
            teaCacheMaxSkipSteps: teaCacheMaxSkipSteps,
            causalInference: causalInference,
            causalInferencePad: causalInferencePad,
            fps: fps,
            motionScale: motionScale,
            guidingFrameNoise: guidingFrameNoise,
            startFrameGuidance: startFrameGuidance,
            numFrames: numFrames,
            refinerModel: refinerModel,
            refinerStart: refinerStart,
            zeroNegativePrompt: zeroNegativePrompt,
            upscaler: upscaler,
            faceRestoration: faceRestoration,
            name: name,
            clipLText: clipLText,
            openClipGText: openClipGText,
            t5Text: t5Text,
            seedMode: seedMode,
            loras: loras.map { ConfigurationJSON.LoRAJSON(file: $0.file, weight: $0.weight, mode: Int($0.mode.rawValue)) },
            controls: controls.map { ConfigurationJSON.ControlJSON(file: $0.file, weight: $0.weight, guidanceStart: $0.guidanceStart, guidanceEnd: $0.guidanceEnd, controlMode: Int($0.controlMode.rawValue)) }
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(json)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw ConfigurationCodableError.encodingFailed
        }
        return jsonString
    }

    /// Create a configuration from a JSON string.
    /// - Parameter json: The JSON string to parse.
    /// - Returns: A DrawThingsConfiguration instance.
    public static func fromJSON(_ json: String) throws -> DrawThingsConfiguration {
        guard let data = json.data(using: .utf8) else {
            throw ConfigurationCodableError.invalidJSON
        }

        let decoder = JSONDecoder()
        let configJSON = try decoder.decode(ConfigurationJSON.self, from: data)

        return DrawThingsConfiguration(
            width: configJSON.width,
            height: configJSON.height,
            steps: configJSON.steps,
            model: configJSON.model,
            sampler: SamplerType(rawValue: Int8(configJSON.sampler)) ?? .dpmpp2mkarras,
            guidanceScale: configJSON.guidanceScale,
            seed: configJSON.seed,
            clipSkip: configJSON.clipSkip,
            loras: configJSON.loras.map { LoRAConfig(file: $0.file, weight: $0.weight, mode: LoRAMode(rawValue: Int8($0.mode)) ?? .all) },
            controls: configJSON.controls.map { ControlConfig(file: $0.file, weight: $0.weight, guidanceStart: $0.guidanceStart, guidanceEnd: $0.guidanceEnd, controlMode: ControlMode(rawValue: Int8($0.controlMode)) ?? .balanced) },
            shift: configJSON.shift,
            batchCount: configJSON.batchCount,
            batchSize: configJSON.batchSize,
            strength: configJSON.strength,
            imageGuidanceScale: configJSON.imageGuidanceScale,
            clipWeight: configJSON.clipWeight,
            guidanceEmbed: configJSON.guidanceEmbed,
            speedUpWithGuidanceEmbed: configJSON.speedUpWithGuidanceEmbed,
            cfgZeroStar: configJSON.cfgZeroStar,
            cfgZeroInitSteps: configJSON.cfgZeroInitSteps,
            maskBlur: configJSON.maskBlur,
            maskBlurOutset: configJSON.maskBlurOutset,
            preserveOriginalAfterInpaint: configJSON.preserveOriginalAfterInpaint,
            enableInpainting: configJSON.enableInpainting,
            sharpness: configJSON.sharpness,
            stochasticSamplingGamma: configJSON.stochasticSamplingGamma,
            aestheticScore: configJSON.aestheticScore,
            negativeAestheticScore: configJSON.negativeAestheticScore,
            negativePromptForImagePrior: configJSON.negativePromptForImagePrior,
            imagePriorSteps: configJSON.imagePriorSteps,
            cropTop: configJSON.cropTop,
            cropLeft: configJSON.cropLeft,
            originalImageHeight: configJSON.originalImageHeight,
            originalImageWidth: configJSON.originalImageWidth,
            targetImageHeight: configJSON.targetImageHeight,
            targetImageWidth: configJSON.targetImageWidth,
            negativeOriginalImageHeight: configJSON.negativeOriginalImageHeight,
            negativeOriginalImageWidth: configJSON.negativeOriginalImageWidth,
            upscalerScaleFactor: configJSON.upscalerScaleFactor,
            resolutionDependentShift: configJSON.resolutionDependentShift,
            t5TextEncoder: configJSON.t5TextEncoder,
            separateClipL: configJSON.separateClipL,
            separateOpenClipG: configJSON.separateOpenClipG,
            separateT5: configJSON.separateT5,
            tiledDiffusion: configJSON.tiledDiffusion,
            diffusionTileWidth: configJSON.diffusionTileWidth,
            diffusionTileHeight: configJSON.diffusionTileHeight,
            diffusionTileOverlap: configJSON.diffusionTileOverlap,
            tiledDecoding: configJSON.tiledDecoding,
            decodingTileWidth: configJSON.decodingTileWidth,
            decodingTileHeight: configJSON.decodingTileHeight,
            decodingTileOverlap: configJSON.decodingTileOverlap,
            hiresFix: configJSON.hiresFix,
            hiresFixWidth: configJSON.hiresFixWidth,
            hiresFixHeight: configJSON.hiresFixHeight,
            hiresFixStrength: configJSON.hiresFixStrength,
            stage2Steps: configJSON.stage2Steps,
            stage2Guidance: configJSON.stage2Guidance,
            stage2Shift: configJSON.stage2Shift,
            teaCache: configJSON.teaCache,
            teaCacheStart: configJSON.teaCacheStart,
            teaCacheEnd: configJSON.teaCacheEnd,
            teaCacheThreshold: configJSON.teaCacheThreshold,
            teaCacheMaxSkipSteps: configJSON.teaCacheMaxSkipSteps,
            causalInferenceEnabled: configJSON.causalInference > 0,
            causalInference: configJSON.causalInference,
            causalInferencePad: configJSON.causalInferencePad,
            fps: configJSON.fps,
            motionScale: configJSON.motionScale,
            guidingFrameNoise: configJSON.guidingFrameNoise,
            startFrameGuidance: configJSON.startFrameGuidance,
            numFrames: configJSON.numFrames,
            refinerModel: configJSON.refinerModel,
            refinerStart: configJSON.refinerStart,
            zeroNegativePrompt: configJSON.zeroNegativePrompt,
            upscaler: configJSON.upscaler,
            faceRestoration: configJSON.faceRestoration,
            name: configJSON.name,
            clipLText: configJSON.clipLText,
            openClipGText: configJSON.openClipGText,
            t5Text: configJSON.t5Text,
            seedMode: configJSON.seedMode
        )
    }
}

// MARK: - JSON Validation

extension DrawThingsConfiguration {
    /// Result of validating a JSON configuration string.
    public struct ValidationResult {
        /// Whether the JSON is valid and can be parsed.
        public let isValid: Bool
        /// Error message if validation failed, nil if successful.
        public let error: String?
        /// The parsed configuration if successful, nil if failed.
        public let configuration: DrawThingsConfiguration?

        /// Create a successful validation result.
        public static func success(_ config: DrawThingsConfiguration) -> ValidationResult {
            ValidationResult(isValid: true, error: nil, configuration: config)
        }

        /// Create a failed validation result.
        public static func failure(_ error: String) -> ValidationResult {
            ValidationResult(isValid: false, error: error, configuration: nil)
        }
    }

    /// Validate a JSON string as a Draw Things configuration.
    ///
    /// This method checks:
    /// 1. Whether the string is valid JSON syntax
    /// 2. Whether the JSON can be parsed as a DrawThingsConfiguration
    ///
    /// Empty strings or "{}" are considered valid (will use defaults).
    ///
    /// - Parameter json: The JSON string to validate.
    /// - Returns: A ValidationResult indicating success or failure with details.
    public static func validateJSON(_ json: String) -> ValidationResult {
        let trimmed = json.trimmingCharacters(in: .whitespacesAndNewlines)

        // Empty or default JSON is valid
        if trimmed.isEmpty || trimmed == "{}" {
            return .success(DrawThingsConfiguration())
        }

        // Check if it's valid JSON syntax
        guard let data = trimmed.data(using: .utf8) else {
            return .failure("Invalid text encoding")
        }

        do {
            _ = try JSONSerialization.jsonObject(with: data)
        } catch {
            return .failure("Invalid JSON syntax")
        }

        // Try to parse as DrawThingsConfiguration
        do {
            let config = try fromJSON(trimmed)
            return .success(config)
        } catch let error as DecodingError {
            // Provide user-friendly error messages for decoding errors
            switch error {
            case .keyNotFound(let key, _):
                return .failure("Missing required key: \(key.stringValue)")
            case .typeMismatch(let type, let context):
                return .failure("Type mismatch for '\(context.codingPath.map { $0.stringValue }.joined(separator: "."))': expected \(type)")
            case .valueNotFound(let type, let context):
                return .failure("Missing value for '\(context.codingPath.map { $0.stringValue }.joined(separator: "."))': expected \(type)")
            case .dataCorrupted(let context):
                return .failure("Data corrupted: \(context.debugDescription)")
            @unknown default:
                return .failure("Decoding error: \(error.localizedDescription)")
            }
        } catch {
            return .failure(error.localizedDescription)
        }
    }

    /// Format a JSON string with pretty printing and sorted keys.
    ///
    /// - Parameter json: The JSON string to format.
    /// - Returns: The formatted JSON string, or nil if the input is invalid JSON.
    public static func formatJSON(_ json: String) -> String? {
        guard let data = json.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data),
              let formatted = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys]),
              let result = String(data: formatted, encoding: .utf8) else {
            return nil
        }
        return result
    }
}

// MARK: - Errors

public enum ConfigurationCodableError: LocalizedError {
    case encodingFailed
    case invalidJSON
    case decodingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode configuration to JSON"
        case .invalidJSON:
            return "Invalid JSON string"
        case .decodingFailed(let message):
            return "Failed to decode configuration: \(message)"
        }
    }
}
