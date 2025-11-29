//
//  DrawThingsKitTests.swift
//  DrawThingsKit
//

import XCTest
@testable import DrawThingsKit

final class DrawThingsKitTests: XCTestCase {

    // MARK: - ServerProfile Tests

    func testServerProfileInitialization() {
        let profile = ServerProfile(
            name: "Test Server",
            host: "192.168.1.100",
            port: 7859,
            useTLS: true,
            isDefault: false
        )

        XCTAssertEqual(profile.name, "Test Server")
        XCTAssertEqual(profile.host, "192.168.1.100")
        XCTAssertEqual(profile.port, 7859)
        XCTAssertEqual(profile.address, "192.168.1.100:7859")
        XCTAssertTrue(profile.useTLS)
        XCTAssertFalse(profile.isDefault)
    }

    func testServerProfileFromAddress() {
        let profile = ServerProfile(
            name: "From Address",
            address: "example.com:8080",
            useTLS: false
        )

        XCTAssertEqual(profile.host, "example.com")
        XCTAssertEqual(profile.port, 8080)
        XCTAssertEqual(profile.address, "example.com:8080")
    }

    func testServerProfileFromAddressWithoutPort() {
        let profile = ServerProfile(
            name: "No Port",
            address: "example.com",
            useTLS: true
        )

        XCTAssertEqual(profile.host, "example.com")
        XCTAssertEqual(profile.port, 7859) // Default port
    }

    func testServerProfileLocalhost() {
        let profile = ServerProfile.localhost

        XCTAssertEqual(profile.name, "Local Server")
        XCTAssertEqual(profile.host, "localhost")
        XCTAssertEqual(profile.port, 7859)
        XCTAssertTrue(profile.useTLS)
        XCTAssertTrue(profile.isDefault)
    }

    // MARK: - ProfileStorage Tests

    func testProfileStorageSaveAndLoad() {
        let storage = ProfileStorage(
            userDefaults: UserDefaults(suiteName: "DrawThingsKitTests")!,
            keyPrefix: "test"
        )

        // Clear any existing data
        storage.clearProfiles()

        let profiles = [
            ServerProfile(name: "Server 1", host: "host1.com", port: 7859, useTLS: true, isDefault: true),
            ServerProfile(name: "Server 2", host: "host2.com", port: 8080, useTLS: false, isDefault: false)
        ]

        storage.saveProfiles(profiles)

        let loaded = storage.loadProfiles()

        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded[0].name, "Server 1")
        XCTAssertEqual(loaded[1].name, "Server 2")

        // Cleanup
        storage.clearProfiles()
    }

    func testProfileStorageEmpty() {
        let storage = ProfileStorage(
            userDefaults: UserDefaults(suiteName: "DrawThingsKitTestsEmpty")!,
            keyPrefix: "empty"
        )

        storage.clearProfiles()

        let loaded = storage.loadProfiles()
        XCTAssertTrue(loaded.isEmpty)
    }

    // MARK: - ConnectionState Tests

    func testConnectionStateIsConnected() {
        XCTAssertTrue(ConnectionState.connected.isConnected)
        XCTAssertFalse(ConnectionState.disconnected.isConnected)
        XCTAssertFalse(ConnectionState.connecting.isConnected)
        XCTAssertFalse(ConnectionState.error("test").isConnected)
    }

    func testConnectionStateIsConnecting() {
        XCTAssertTrue(ConnectionState.connecting.isConnecting)
        XCTAssertFalse(ConnectionState.connected.isConnecting)
        XCTAssertFalse(ConnectionState.disconnected.isConnecting)
        XCTAssertFalse(ConnectionState.error("test").isConnecting)
    }

    func testConnectionStateErrorMessage() {
        XCTAssertNil(ConnectionState.connected.errorMessage)
        XCTAssertNil(ConnectionState.disconnected.errorMessage)
        XCTAssertNil(ConnectionState.connecting.errorMessage)
        XCTAssertEqual(ConnectionState.error("Connection failed").errorMessage, "Connection failed")
    }

    // MARK: - Configuration JSON Tests

    func testConfigurationToJSON() throws {
        let config = DrawThingsConfiguration(
            width: 1024,
            height: 768,
            steps: 30,
            model: "test_model.safetensors",
            sampler: .dpmpp2mkarras,
            guidanceScale: 7.5,
            seed: 12345
        )

        let json = try config.toJSON()

        XCTAssertTrue(json.contains("\"width\" : 1024"))
        XCTAssertTrue(json.contains("\"height\" : 768"))
        XCTAssertTrue(json.contains("\"steps\" : 30"))
        XCTAssertTrue(json.contains("\"model\" : \"test_model.safetensors\""))
        XCTAssertTrue(json.contains("\"seed\" : 12345"))
    }

    func testConfigurationFromJSON() throws {
        let json = """
        {
            "width": 512,
            "height": 512,
            "steps": 20,
            "model": "sd_model.safetensors",
            "sampler": 0,
            "guidanceScale": 7.0,
            "seed": 42,
            "clipSkip": 1,
            "shift": 1.0,
            "batchCount": 1,
            "batchSize": 1,
            "strength": 1.0,
            "imageGuidanceScale": 1.5,
            "clipWeight": 1.0,
            "guidanceEmbed": 3.5,
            "speedUpWithGuidanceEmbed": true,
            "cfgZeroStar": false,
            "cfgZeroInitSteps": 0,
            "maskBlur": 1.5,
            "maskBlurOutset": 0,
            "preserveOriginalAfterInpaint": true,
            "sharpness": 0.0,
            "stochasticSamplingGamma": 0.3,
            "aestheticScore": 6.0,
            "negativeAestheticScore": 2.5,
            "negativePromptForImagePrior": true,
            "imagePriorSteps": 5,
            "cropTop": 0,
            "cropLeft": 0,
            "originalImageHeight": 0,
            "originalImageWidth": 0,
            "targetImageHeight": 0,
            "targetImageWidth": 0,
            "negativeOriginalImageHeight": 0,
            "negativeOriginalImageWidth": 0,
            "upscalerScaleFactor": 0,
            "resolutionDependentShift": true,
            "t5TextEncoder": true,
            "separateClipL": false,
            "separateOpenClipG": false,
            "separateT5": false,
            "tiledDiffusion": false,
            "diffusionTileWidth": 16,
            "diffusionTileHeight": 16,
            "diffusionTileOverlap": 2,
            "tiledDecoding": false,
            "decodingTileWidth": 10,
            "decodingTileHeight": 10,
            "decodingTileOverlap": 2,
            "hiresFix": false,
            "hiresFixWidth": 0,
            "hiresFixHeight": 0,
            "hiresFixStrength": 0.7,
            "stage2Steps": 10,
            "stage2Guidance": 1.0,
            "stage2Shift": 1.0,
            "teaCache": false,
            "teaCacheStart": 5,
            "teaCacheEnd": -1,
            "teaCacheThreshold": 0.06,
            "teaCacheMaxSkipSteps": 3,
            "causalInference": 0,
            "causalInferencePad": 0,
            "fps": 5,
            "motionScale": 127,
            "guidingFrameNoise": 0.02,
            "startFrameGuidance": 1.0,
            "numFrames": 14,
            "refinerStart": 0.85,
            "zeroNegativePrompt": false,
            "seedMode": 2,
            "loras": [],
            "controls": []
        }
        """

        let config = try DrawThingsConfiguration.fromJSON(json)

        XCTAssertEqual(config.width, 512)
        XCTAssertEqual(config.height, 512)
        XCTAssertEqual(config.steps, 20)
        XCTAssertEqual(config.model, "sd_model.safetensors")
        XCTAssertEqual(config.seed, 42)
        XCTAssertEqual(config.sampler, .dpmpp2mkarras)
    }

    func testConfigurationRoundTrip() throws {
        let original = DrawThingsConfiguration(
            width: 1024,
            height: 1024,
            steps: 50,
            model: "flux_model.safetensors",
            sampler: .eulera,
            guidanceScale: 3.5,
            seed: 99999,
            loras: [LoRAConfig(file: "style.safetensors", weight: 0.8, mode: .all)],
            controls: [ControlConfig(file: "depth.safetensors", weight: 0.5)]
        )

        let json = try original.toJSON()
        let restored = try DrawThingsConfiguration.fromJSON(json)

        XCTAssertEqual(original.width, restored.width)
        XCTAssertEqual(original.height, restored.height)
        XCTAssertEqual(original.steps, restored.steps)
        XCTAssertEqual(original.model, restored.model)
        XCTAssertEqual(original.sampler, restored.sampler)
        XCTAssertEqual(original.guidanceScale, restored.guidanceScale)
        XCTAssertEqual(original.seed, restored.seed)
        XCTAssertEqual(original.loras.count, restored.loras.count)
        XCTAssertEqual(original.controls.count, restored.controls.count)
    }

    // MARK: - Dimension Presets Tests

    func testDimensionPresets() {
        XCTAssertEqual(DimensionPresets.square1024.width, 1024)
        XCTAssertEqual(DimensionPresets.square1024.height, 1024)

        XCTAssertEqual(DimensionPresets.portrait768x1024.width, 768)
        XCTAssertEqual(DimensionPresets.portrait768x1024.height, 1024)

        XCTAssertEqual(DimensionPresets.hd1280x720.width, 1280)
        XCTAssertEqual(DimensionPresets.hd1280x720.height, 720)

        XCTAssertFalse(DimensionPresets.all.isEmpty)
        XCTAssertFalse(DimensionPresets.common.isEmpty)
    }

    // MARK: - Sampler Presets Tests

    func testSamplerPresets() {
        XCTAssertFalse(SamplerPresets.all.isEmpty)
        XCTAssertFalse(SamplerPresets.common.isEmpty)

        // Test name lookup
        XCTAssertEqual(SamplerPresets.name(for: .dpmpp2mkarras), "DPM++ 2M Karras")
        XCTAssertEqual(SamplerPresets.name(for: .eulera), "Euler Ancestral")

        // Test info lookup
        let info = SamplerPresets.info(for: .ddim)
        XCTAssertNotNil(info)
        XCTAssertEqual(info?.name, "DDIM")
    }

    // MARK: - GenerationJob Tests

    func testGenerationJobCreation() throws {
        let config = DrawThingsConfiguration(
            width: 1024,
            height: 1024,
            steps: 30,
            model: "test.safetensors"
        )

        let job = try GenerationJob(
            prompt: "A beautiful sunset",
            negativePrompt: "blurry",
            configuration: config
        )

        XCTAssertEqual(job.prompt, "A beautiful sunset")
        XCTAssertEqual(job.negativePrompt, "blurry")
        XCTAssertEqual(job.status, .pending)
        XCTAssertTrue(job.isPending)
        XCTAssertFalse(job.isProcessing)
        XCTAssertFalse(job.isFinished)
        XCTAssertTrue(job.resultImages.isEmpty)
    }

    func testGenerationJobNameGeneration() throws {
        let config = DrawThingsConfiguration()

        // Short prompt
        let job1 = try GenerationJob(
            prompt: "Cat",
            configuration: config
        )
        XCTAssertEqual(job1.name, "Cat")

        // Long prompt (should truncate)
        let job2 = try GenerationJob(
            prompt: "A very long prompt with many words that should be truncated to a reasonable length",
            configuration: config
        )
        XCTAssertTrue(job2.name.count <= 30)
    }

    func testJobStatus() throws {
        var job = try GenerationJob(
            prompt: "Test",
            configuration: DrawThingsConfiguration()
        )

        XCTAssertTrue(job.isPending)
        XCTAssertFalse(job.isFinished)

        job.status = .processing
        XCTAssertTrue(job.isProcessing)
        XCTAssertFalse(job.isFinished)

        job.status = .completed
        XCTAssertTrue(job.isCompleted)
        XCTAssertTrue(job.isFinished)

        job.status = .failed
        XCTAssertTrue(job.isFailed)
        XCTAssertTrue(job.isFinished)
        XCTAssertTrue(job.canRetry) // First failure, can retry
    }

    func testJobProgress() {
        let progress = JobProgress(currentStep: 15, totalSteps: 30, stage: "Sampling")

        XCTAssertEqual(progress.currentStep, 15)
        XCTAssertEqual(progress.totalSteps, 30)
        XCTAssertEqual(progress.progressFraction, 0.5, accuracy: 0.01)
        XCTAssertEqual(progress.progressPercentage, 50)
        XCTAssertEqual(progress.stage, "Sampling")
    }

    // MARK: - QueueStorage Tests

    func testQueueStorageSaveAndLoad() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("DrawThingsKitTests")
            .appendingPathComponent("test_queue.json")

        let storage = QueueStorage(fileURL: tempURL)
        storage.clearJobs()

        let config = DrawThingsConfiguration()
        let jobs = [
            try GenerationJob(prompt: "Job 1", configuration: config),
            try GenerationJob(prompt: "Job 2", configuration: config)
        ]

        storage.saveJobs(jobs)

        let loaded = storage.loadJobs()
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded[0].prompt, "Job 1")
        XCTAssertEqual(loaded[1].prompt, "Job 2")

        storage.clearJobs()
    }

    func testQueueStorageEmpty() {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("DrawThingsKitTests")
            .appendingPathComponent("empty_queue.json")

        let storage = QueueStorage(fileURL: tempURL)
        storage.clearJobs()

        let loaded = storage.loadJobs()
        XCTAssertTrue(loaded.isEmpty)
    }
}
