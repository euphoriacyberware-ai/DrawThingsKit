# DrawThingsKit

A Swift package providing UI components, utilities, and model management for building Draw Things gRPC client applications.

## Overview

DrawThingsKit abstracts away the complexity of connecting to Draw Things servers, managing generation jobs, and provides reusable SwiftUI components for configuration editing and queue management. It's built on top of **DrawThingsClient** and supports both macOS and iOS applications.

## Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/euphoriacyberware-ai/DrawThingsKit", from: "1.1.0")
]
```

Or add via Xcode: File → Add Packages → Enter the repository URL.

## Quick Start

```swift
import SwiftUI
import SwiftData
import DrawThingsKit

@main
struct MyApp: App {
    @StateObject private var connectionManager = ConnectionManager()
    @StateObject private var configurationManager = ConfigurationManager()
    @StateObject private var queue = JobQueue()
    @StateObject private var processor = QueueProcessor()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(connectionManager)
                .environmentObject(configurationManager)
                .environmentObject(queue)
        }
        .task {
            processor.startProcessing(queue: queue, connectionManager: connectionManager)
        }
    }
}
```

## Package Structure

```
Sources/DrawThingsKit/
├── Configuration/     # JSON serialization & presets
├── Connection/        # Server profiles & connection management
├── Logging/           # DTLogger unified logging system
├── Models/            # Model catalog & ConfigurationManager
├── Queue/             # Job queue, events, processing & HintBuilder
└── Views/
    ├── Configuration/ # Config editors, presets, section views
    ├── Connection/    # Server profile & status views
    └── Queue/         # Queue progress, list & control views
```

---

## Core Components

### ConnectionManager

Manages server profiles and connection lifecycle.

```swift
@StateObject var connectionManager = ConnectionManager()

// Add a profile
let profile = ServerProfile(name: "Local", host: "localhost", port: 7859)
connectionManager.addProfile(profile)

// Update an existing profile
var updated = profile
updated.name = "My Local Server"
connectionManager.updateProfile(updated)

// Delete a profile
connectionManager.deleteProfile(profile)

// Set default profile (used by connectToDefault)
connectionManager.setDefault(profile)

// Get the default profile
if let defaultProfile = connectionManager.defaultProfile {
    print("Default: \(defaultProfile.name)")
}

// Connect to a specific profile
await connectionManager.connect(to: profile)

// Connect to the default profile
await connectionManager.connectToDefault()

// Reconnect to current profile
await connectionManager.reconnect()

// Check state
if connectionManager.connectionState.isConnected {
    // Ready to generate
}

// Disconnect
connectionManager.disconnect()
```

**Profile Management Methods:**
- `addProfile(_:)` - Add a new server profile
- `updateProfile(_:)` - Update an existing profile
- `deleteProfile(_:)` - Remove a profile
- `setDefault(_:)` - Mark a profile as the default

**Connection Methods:**
- `connect(to:)` - Connect to a specific profile
- `connectToDefault()` - Connect to the default profile
- `reconnect()` - Reconnect to the current/last profile
- `disconnect()` - Disconnect from the server

**Published Properties:**
- `profiles: [ServerProfile]` - Saved server profiles
- `activeProfile: ServerProfile?` - Currently connected profile
- `connectionState: ConnectionState` - Current state (.disconnected, .connecting, .connected, .error)
- `modelsManager: ModelsManager` - Available models from server
- `activeService: DrawThingsService?` - Active gRPC service (when connected)
- `defaultProfile: ServerProfile?` - The default profile, if one is set

**Building a Custom UI:**

You can access profiles programmatically to build your own UI instead of using the provided views:

```swift
// Get all profiles
let allProfiles = connectionManager.profiles

// Find a specific profile by name
if let server = connectionManager.profiles.first(where: { $0.name == "My Server" }) {
    await connectionManager.connect(to: server)
}

// Iterate through profiles
for profile in connectionManager.profiles {
    print("\(profile.name): \(profile.address) (TLS: \(profile.useTLS))")
}

// Check which is default
for profile in connectionManager.profiles {
    if profile.isDefault {
        print("\(profile.name) is the default")
    }
}
```

The `profiles` property is `@Published`, so SwiftUI views automatically update when profiles are added, removed, or modified.

### JobQueue

Observable queue state management for generation jobs.

```swift
@StateObject var queue = JobQueue()

// Create and enqueue a job
let job = try GenerationJob(
    prompt: "A beautiful landscape",
    negativePrompt: "ugly, blurry",
    configuration: config
)
queue.enqueue(job)

// Queue control
queue.pause()
queue.resume()

// Clear jobs
queue.clearCompleted()
queue.clearFailed()
queue.clearAll()

// Retry failed job
queue.retry(failedJob)
```

**Published Properties:**
- `jobs: [GenerationJob]` - All jobs in queue
- `currentJob: GenerationJob?` - Currently processing job
- `isProcessing: Bool` - Whether a job is running
- `isPaused: Bool` - Whether queue is paused (defaults to `false`)
- `currentPreview: PlatformImage?` - Preview of current generation
- `currentProgress: JobProgress?` - Progress of current job

**Computed Properties:**
- `pendingJobs`, `completedJobs`, `failedJobs` - Filtered job lists
- `pendingCount`, `activeQueueCount` - Counts
- `hasPendingJobs`, `isEmpty` - State checks

**Auto-Processing Behavior:**

By default, the queue is ready to process (`isPaused = false`). When jobs are enqueued and a connection is available, processing starts automatically. The queue pauses automatically on connection errors and resumes when you call `resume()` after reconnecting.

To start the queue in a paused state (requiring explicit user action to begin):

```swift
@main
struct MyApp: App {
    @StateObject private var queue = JobQueue()

    init() {
        // Start paused - user must explicitly resume
        queue.pause()
    }

    // Or pause in .task after the view appears
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    queue.pause()  // Start paused
                }
        }
    }
}
```

#### Job Events

The `JobQueue` provides a Combine publisher for job lifecycle events, making it easy to react to job completion, failures, and progress updates.

**All image data is provided as native `PlatformImage` types** (NSImage on macOS, UIImage on iOS). The Kit handles all DTTensor format conversion internally, so your app works with familiar image types.

```swift
import Combine

// Subscribe to job events
var cancellables = Set<AnyCancellable>()

queue.events
    .sink { event in
        switch event {
        case .jobAdded(let job):
            print("Job added: \(job.id)")

        case .jobStarted(let job):
            print("Job started: \(job.id)")

        case .jobProgress(let job, let progress):
            // Preview is already converted to PlatformImage
            if let previewImage = progress.previewImage {
                // Display preview directly - no conversion needed
                displayPreview(previewImage)
            }

        case .jobCompleted(let job, let images):
            // Images are native PlatformImage types, ready to display
            print("Job completed with \(images.count) images")
            if let firstImage = images.first {
                displayResult(firstImage)
                // Convert to PNG for storage if needed
                if let pngData = firstImage.pngData() {
                    saveToDatabase(pngData)
                }
            }

        case .jobFailed(let job, let error):
            print("Job failed: \(error)")

        case .jobCancelled(let job):
            print("Job cancelled: \(job.id)")

        case .jobRemoved(let jobId):
            print("Job removed: \(jobId)")
        }
    }
    .store(in: &cancellables)
```

**In SwiftUI**, use `.onReceive` to handle events:

```swift
struct ContentView: View {
    @EnvironmentObject var queue: JobQueue
    @State private var resultImage: PlatformImage?

    var body: some View {
        VStack {
            if let image = resultImage {
                Image(platformImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        }
        .onReceive(queue.events) { event in
            handleJobEvent(event)
        }
    }

    func handleJobEvent(_ event: JobEvent) {
        switch event {
        case .jobCompleted(_, let images):
            // Images are ready to display
            resultImage = images.first
        case .jobFailed(_, let error):
            // Show error alert
            print("Error: \(error)")
        default:
            break
        }
    }
}
```

**JobEvent Types:**
| Event | Associated Data | Description |
|-------|-----------------|-------------|
| `.jobAdded` | `GenerationJob` | Job was added to queue |
| `.jobStarted` | `GenerationJob` | Job began processing |
| `.jobProgress` | `GenerationJob`, `JobProgress` | Progress update with preview image |
| `.jobCompleted` | `GenerationJob`, `[PlatformImage]` | Job finished with result images |
| `.jobFailed` | `GenerationJob`, `String` | Job failed with error message |
| `.jobCancelled` | `GenerationJob` | Job was cancelled |
| `.jobRemoved` | `UUID` | Job was removed from queue |

### QueueProcessor

Processes jobs from the queue using the Draw Things service.

```swift
let processor = QueueProcessor()

// Start processing loop
processor.startProcessing(queue: queue, connectionManager: connectionManager)

// Stop processing
processor.stopProcessing()
```

The processor automatically:
- Picks up pending jobs when connected and unpaused
- Updates progress with previews
- Marks jobs completed with results
- Pauses on connectivity errors
- Fails jobs that return no images

### GenerationJob

A queued image generation job.

```swift
let job = try GenerationJob(
    name: "My Generation",           // Optional display name
    prompt: "A cat",
    negativePrompt: "ugly",
    configuration: config,
    canvasImageData: imageData,      // Optional for img2img
    maskImageData: maskData,         // Optional for inpainting
    hints: [hintData]                // Optional control hints
)

// Status
job.status      // .pending, .processing, .completed, .failed, .cancelled
job.isPending
job.isCompleted
job.canRetry    // Failed with retries remaining

// Results (after completion) - native PlatformImage types
job.resultImages      // [PlatformImage] - all result images
job.firstResultImage  // PlatformImage? - convenience for first image
```

### ModelsManager

Manages model catalogs from the connected server.

The Draw Things server must have "Model Browsing" enabled for model lists to be populated.

```swift
// Access via connectionManager
let models = connectionManager.modelsManager

// Check if models are available
if models.isEmpty {
    print("No models loaded - is Model Browsing enabled on the server?")
}

// Available model types (all are @Published arrays)
models.checkpoints          // [CheckpointModel] - Base models
models.loras               // [LoRAModel] - LoRA models
models.controlNets         // [ControlNetModel] - ControlNet models
models.textualInversions   // [TextualInversionModel] - Embeddings
models.upscalers           // [UpscalerModel] - Upscaler models

// Filter checkpoints by type
models.baseModels           // Checkpoints that are not refiners
models.refinerModels        // Checkpoints that are refiners

// Set selected checkpoint for compatibility filtering
models.selectedCheckpoint = models.checkpoints.first

// Get models compatible with selected checkpoint (version matching)
models.compatibleLoRAs              // LoRAs matching checkpoint version
models.compatibleControlNets        // ControlNets matching checkpoint version
models.compatibleTextualInversions  // Embeddings matching checkpoint version

// Summary string for display
models.summary  // "5 models, 12 LoRAs, 3 ControlNets"

// Clear all model data
models.clear()
```

**Finding and Using Models:**

```swift
// Find a specific checkpoint by name
if let sdxl = models.checkpoints.first(where: { $0.name.contains("SDXL") }) {
    config.model = sdxl.file
    models.selectedCheckpoint = sdxl  // Enable compatibility filtering
}

// Find LoRAs and add to configuration
let detailLora = models.compatibleLoRAs.first { $0.name.contains("detail") }
if let lora = detailLora {
    config.loras = [LoRAConfig(file: lora.file, weight: 0.8)]
}

// Find upscaler
if let upscaler = models.upscalers.first(where: { $0.scaleFactor == 4 }) {
    config.upscaler = upscaler.file
    config.upscalerScaleFactor = Int32(upscaler.scaleFactor ?? 4)
}

// Use textual inversion keyword in prompt
if let embedding = models.textualInversions.first(where: { $0.name == "bad_hands" }) {
    config.negativePrompt = embedding.keyword ?? embedding.name
}
```

**Model Type Properties:**

Each model type exposes relevant metadata:

| Type | Key Properties |
|------|----------------|
| `CheckpointModel` | `name`, `file`, `version`, `modifier`, `autoencoder` |
| `LoRAModel` | `name`, `file`, `version`, `isLoHa`, `isConsistencyModel` |
| `ControlNetModel` | `name`, `file`, `version` |
| `TextualInversionModel` | `name`, `file`, `keyword`, `version`, `deprecated` |
| `UpscalerModel` | `name`, `file`, `scaleFactor`, `blocks` |

All model types use `file` as their `id` for `Identifiable` conformance.

### ConfigurationManager

Manages the active configuration, prompt state, and model selections for generation.

```swift
@StateObject var configurationManager = ConfigurationManager()

// Set prompt
configurationManager.prompt = "A beautiful sunset"
configurationManager.negativePrompt = "ugly, blurry"

// Access/modify configuration
configurationManager.activeConfiguration.width = 1024
configurationManager.activeConfiguration.height = 1024
configurationManager.activeConfiguration.steps = 30

// Model selection (optional - use with pickers)
configurationManager.selectedCheckpoint = modelsManager.checkpoints.first
configurationManager.selectedRefiner = modelsManager.refinerModels.first

// Sync model selections to configuration before generation
configurationManager.syncModelsToConfiguration()

// Clipboard operations
configurationManager.copyToClipboard()      // Copy config as JSON
configurationManager.pasteFromClipboard()   // Paste config from JSON

// Import/export JSON
let json = configurationManager.exportToJSON()
configurationManager.loadFromJSON(json)

// Reset to defaults
configurationManager.resetToDefaults()

// Resolve model selections after loading a preset
configurationManager.resolveModels(from: modelsManager)
```

**Published Properties:**
- `activeConfiguration: DrawThingsConfiguration` - The current configuration
- `prompt: String` - The generation prompt
- `negativePrompt: String` - The negative prompt
- `selectedCheckpoint: CheckpointModel?` - Selected base model
- `selectedRefiner: CheckpointModel?` - Selected refiner model

**Usage with JobQueue:**

```swift
func generate() {
    configurationManager.syncModelsToConfiguration()

    let job = try GenerationJob(
        prompt: configurationManager.prompt,
        negativePrompt: configurationManager.negativePrompt,
        configuration: configurationManager.activeConfiguration
    )
    queue.enqueue(job)
}
```

---

## Configuration

### DrawThingsConfiguration

The main configuration object (re-exported from DrawThingsClient).

```swift
var config = DrawThingsConfiguration()

// Core parameters
config.width = 1024
config.height = 1024
config.steps = 30
config.model = "sd_xl_base_1.0.safetensors"
config.sampler = .dpmpp2mkarras
config.guidanceScale = 7.0
config.seed = 12345           // Int64? - nil for random seed
config.refinerModel = "sd_xl_refiner_1.0.safetensors"  // String? - optional refiner
config.refinerStart = 0.85    // Float - when to switch to refiner

// LoRAs
config.loras = [
    LoRAConfig(file: "detail_lora.safetensors", weight: 0.8)
]

// Controls
config.controls = [
    ControlConfig(file: "controlnet_canny.safetensors", weight: 1.0)
]
```

### JSON Serialization

```swift
// Export to JSON
let json = try config.toJSON()

// Import from JSON
let config = try DrawThingsConfiguration.fromJSON(json)

// Validate JSON
let result = DrawThingsConfiguration.validateJSON(json)
if result.isValid {
    let config = result.configuration!
}

// Format JSON
let formatted = DrawThingsConfiguration.formatJSON(json)
```

### Presets

```swift
// Dimension presets
DimensionPresets.square1024      // 1024x1024
DimensionPresets.portrait768x1024
DimensionPresets.landscape1216x832
DimensionPresets.all             // All presets

// Sampler presets
SamplerPresets.all               // All samplers with display names
SamplerPresets.common            // Common samplers
SamplerPresets.name(for: .euler) // "Euler"

// Defaults
ConfigurationDefaults.width      // 1024
ConfigurationDefaults.steps      // 30
ConfigurationDefaults.sampler    // .dpmpp2mkarras
```

---

## SwiftUI Views (macOS)

### Connection Views

```swift
// Full profile manager with list
ServerProfilesView(connectionManager: connectionManager)

// Compact dropdown picker
ServerProfilePicker(connectionManager: connectionManager)

// Status badge (clickable to connect/disconnect)
ConnectionStatusBadge(connectionManager: connectionManager)

// Expanded status with error display
ConnectionStatusView(connectionManager: connectionManager) {
    await connectionManager.reconnect()
}
```

### Queue Views

```swift
// Full queue interface with progress and list
QueueView(queue: queue)

// Current job progress with preview
QueueProgressView(queue: queue)

// Compact progress badge for toolbars
QueueProgressBadge(queue: queue)

// Play/pause/clear controls
QueueControlsView(queue: queue)

// Toolbar-style control strip with add action
QueueToolbar(queue: queue) {
    // Add job action
}

// Compact list (no progress section)
QueueListView(queue: queue)

// Sidebar-style layout (contains internal List - do not wrap in List or Section)
QueueSidebarView(queue: queue)

// Individual job rows
QueueItemRow(job: job, queue: queue)
QueueItemCompactRow(job: job, queue: queue)
```

### Configuration Editor

```swift
@State private var configJSON = "{}"

ConfigurationEditorView(json: $configJSON, title: "Edit Configuration")
```

Features:
- Monospace code editor
- Paste, Copy, Format, Validate, Clear buttons
- Real-time validation status
- Auto-format on paste

### Configuration Actions

Views for managing configuration presets and clipboard operations:

```swift
// Full action bar with Copy, Paste, Save, Presets buttons
ConfigurationActionsView(
    configurationManager: configurationManager,
    modelContext: modelContext
)

// Compact single-row version
ConfigurationActionsCompactView(
    configurationManager: configurationManager,
    modelContext: modelContext
)

// Save configuration sheet (presented modally)
SaveConfigurationSheet(
    configurationManager: configurationManager,
    modelContext: modelContext,
    isPresented: $showingSaveSheet
)

// Preset picker menu
PresetPickerMenu(
    configurationManager: configurationManager,
    presets: savedConfigurations
)

// Preset list for settings/management
PresetListView(
    configurationManager: configurationManager,
    modelContext: modelContext
)
```

**ConfigurationActionsView Features:**
- **Copy**: Copy current configuration to clipboard as JSON
- **Paste**: Paste configuration from clipboard
- **Save**: Save current configuration as a named preset
- **Presets**: Load from saved presets or reset to defaults

### Configuration Section Views

Reusable SwiftUI form sections for building configuration UIs. Each section is a composable view that binds directly to `DrawThingsConfiguration` properties.

**Standard Sections** (always visible):

```swift
// Prompt input fields
PromptSection(
    prompt: $configurationManager.prompt,
    negativePrompt: $configurationManager.negativePrompt
)

// Model selection - checkpoint, refiner, sampler, Mixture of Experts toggle
ModelSection(
    modelsManager: connectionManager.modelsManager,
    selectedCheckpoint: $configurationManager.selectedCheckpoint,
    selectedRefiner: $configurationManager.selectedRefiner,
    refinerStart: $configurationManager.activeConfiguration.refinerStart,
    sampler: $configurationManager.activeConfiguration.sampler,
    modelName: $configurationManager.activeConfiguration.model,
    refinerName: $configurationManager.activeConfiguration.refinerModel,
    mixtureOfExperts: $configurationManager.mixtureOfExperts
)

// LoRA management with weight sliders
// When Mixture of Experts is enabled, shows mode selector (All/Base/Refiner)
LoRASection(
    modelsManager: connectionManager.modelsManager,
    selectedLoRAs: $configurationManager.selectedLoRAs,
    mixtureOfExperts: configurationManager.mixtureOfExperts
)

// Core generation parameters
// When showAdvanced is true, also shows CFG Zero Star toggle and Init Steps
ParametersSection(
    steps: $configurationManager.activeConfiguration.steps,
    guidanceScale: $configurationManager.activeConfiguration.guidanceScale,
    cfgZeroStar: $configurationManager.activeConfiguration.cfgZeroStar,
    cfgZeroInitSteps: $configurationManager.activeConfiguration.cfgZeroInitSteps,
    resolutionDependentShift: $configurationManager.activeConfiguration.resolutionDependentShift,
    shift: $configurationManager.activeConfiguration.shift,
    showAdvanced: showAdvanced
)

// Dimensions with presets and swap button
DimensionsSection(
    width: $configurationManager.activeConfiguration.width,
    height: $configurationManager.activeConfiguration.height
)

// Seed with mode selector
// When showAdvanced is true, shows additional seed modes
SeedSection(
    seed: $configurationManager.activeConfiguration.seed,
    seedMode: $configurationManager.activeConfiguration.seedMode,
    showAdvanced: showAdvanced
)

// Image-to-image strength
StrengthSection(
    strength: $configurationManager.activeConfiguration.strength
)

// Batch size (1-4 images per generation)
BatchSection(
    batchSize: $configurationManager.activeConfiguration.batchSize
)

// ControlNet model selection
ControlNetSection(
    modelsManager: connectionManager.modelsManager,
    selectedControls: $configurationManager.selectedControls
)
```

**Advanced Sections** (typically shown when an "Advanced" toggle is enabled):

```swift
if showAdvanced {
    // Advanced generation settings
    // Includes: Clip Skip, Tiled Diffusion/Decoding, HiRes Fix, Sharpness, Inpainting
    AdvancedSection(
        clipSkip: $config.clipSkip,
        tiledDiffusion: $config.tiledDiffusion,
        diffusionTileWidth: $config.diffusionTileWidth,
        diffusionTileHeight: $config.diffusionTileHeight,
        diffusionTileOverlap: $config.diffusionTileOverlap,
        tiledDecoding: $config.tiledDecoding,
        decodingTileWidth: $config.decodingTileWidth,
        decodingTileHeight: $config.decodingTileHeight,
        decodingTileOverlap: $config.decodingTileOverlap,
        hiresFix: $config.hiresFix,
        hiresFixWidth: $config.hiresFixWidth,
        hiresFixHeight: $config.hiresFixHeight,
        hiresFixStrength: $config.hiresFixStrength,
        sharpness: $config.sharpness,
        aestheticScore: $config.aestheticScore,
        negativeAestheticScore: $config.negativeAestheticScore,
        maskBlur: $config.maskBlur,
        maskBlurOutset: $config.maskBlurOutset,
        preserveOriginalAfterInpaint: $config.preserveOriginalAfterInpaint
    )

    // TEA Cache for faster generation
    TeaCacheSection(
        teaCache: $config.teaCache,
        teaCacheStart: $config.teaCacheStart,
        teaCacheEnd: $config.teaCacheEnd,
        teaCacheThreshold: $config.teaCacheThreshold,
        teaCacheMaxSkipSteps: $config.teaCacheMaxSkipSteps
    )

    // Video generation settings
    VideoSection(
        numFrames: $config.numFrames
    )

    // Causal inference for video models (CausVid)
    CausalInferenceSection(
        causalInferenceEnabled: $config.causalInferenceEnabled,
        causalInference: $config.causalInference,
        causalInferencePad: $config.causalInferencePad
    )
}
```

**Section Details:**

| Section | Description |
|---------|-------------|
| `PromptSection` | Text fields for prompt and negative prompt |
| `ModelSection` | Checkpoint/refiner pickers, sampler, Mixture of Experts toggle |
| `LoRASection` | LoRA selection with weight sliders, optional mode selector |
| `ParametersSection` | Steps, CFG Scale, CFG Zero Star (advanced), Resolution Dependent Shift, Shift |
| `DimensionsSection` | Width/height sliders with presets and aspect ratio display |
| `SeedSection` | Seed input with randomize, seed mode picker |
| `StrengthSection` | Img2img strength slider |
| `BatchSection` | Batch size slider |
| `ControlNetSection` | ControlNet model selection with weight sliders |
| `AdvancedSection` | Clip Skip, tiling, HiRes Fix, sharpness, inpainting settings |
| `TeaCacheSection` | TEA Cache toggle and parameters for faster generation |
| `VideoSection` | Number of frames for video generation |
| `CausalInferenceSection` | CausVid settings for video models |

**ParameterSlider:**

All sections use the `ParameterSlider` component for numeric inputs:

```swift
// Reusable slider with label and value display
ParameterSlider(
    label: "Steps",
    value: $stepsBinding,  // Binding<Double>
    range: 1...150,
    step: 1,
    format: "%.0f"
)
```

Sliders snap to step values when released, avoiding dense tick marks for large ranges.

---

## Data Types

### ServerProfile

```swift
struct ServerProfile {
    let id: UUID
    var name: String
    var host: String
    var port: Int
    var useTLS: Bool
    var isDefault: Bool

    var address: String  // "host:port"

    static var localhost: ServerProfile  // Default localhost profile
}
```

### ConnectionState

```swift
enum ConnectionState {
    case disconnected
    case connecting
    case connected
    case error(String)

    var isConnected: Bool
    var isConnecting: Bool
    var errorMessage: String?
}
```

### JobStatus

```swift
enum JobStatus {
    case pending
    case processing
    case completed
    case failed
    case cancelled
}
```

### JobProgress

```swift
struct JobProgress {
    var currentStep: Int
    var totalSteps: Int
    var stage: String?
    var previewImage: PlatformImage?  // Preview as native image type

    var progressFraction: Double   // 0.0 to 1.0
    var progressPercentage: Int    // 0 to 100
}
```

The `previewImage` is automatically converted from the server's DTTensor format with correct color handling for different model families (Flux, Qwen, Wan, SD3, etc.).

### HintData

Used for control images (shuffle hints, IP-Adapter, etc.):

```swift
struct HintData {
    var type: String      // "shuffle", "ip_adapter", etc.
    var imageData: Data   // Image bytes
    var weight: Float
}
```

### HintBuilder

A fluent builder for constructing hints for image generation. This helper abstracts the complexity of hint construction and ensures proper formatting for Draw Things.

```swift
// Basic usage - add moodboard images for style transfer
let hints = HintBuilder()
    .addMoodboardImage(styleImageData, weight: 1.0)
    .addMoodboardImage(referenceImageData, weight: 0.8)
    .build()

let job = try GenerationJob(
    prompt: "A portrait in the style of image 2 with colors from image 3",
    configuration: config,
    canvasImageData: sourceImage,  // This is "image 1"
    hints: hints                    // Moodboard images become "image 2", "image 3", etc.
)
```

**Moodboard/Shuffle Hints:**

Used with models like Qwen Image Edit for style and content transfer. Images are referenced as "image 2", "image 3", etc. in prompts (canvas/source image is "image 1").

```swift
// Single image
builder.addMoodboardImage(imageData, weight: 1.0)

// Multiple images with same weight
builder.addMoodboardImages([image1, image2, image3], weight: 1.0)

// Multiple images with individual weights
builder.addMoodboardImages([
    (data: dressImage, weight: 1.0),
    (data: styleImage, weight: 0.8),
    (data: colorImage, weight: 0.5)
])
```

**ControlNet Hints:**

```swift
let hints = HintBuilder()
    .addDepthMap(depthImageData, weight: 1.0)      // Structural guidance
    .addPose(poseImageData, weight: 0.8)           // Character positioning
    .addCannyEdges(edgeImageData, weight: 1.0)     // Edge detection
    .addScribble(sketchImageData, weight: 0.7)     // Rough sketch
    .addColorReference(colorImageData, weight: 0.5) // Color palette
    .addLineArt(lineArtData, weight: 1.0)          // Line art
    .build()
```

**Generic Hints:**

For custom or less common hint types:

```swift
// Using HintType enum
builder.addHint(type: .tile, imageData: tileData, weight: 1.0)
builder.addHint(type: .seg, imageData: segmentationData, weight: 0.8)

// Using custom string
builder.addHint(type: "custom_type", imageData: imageData, weight: 1.0)
```

**HintType Enum:**

All supported hint types:

| Type | Description |
|------|-------------|
| `.shuffle` | Moodboard/reference images for style transfer |
| `.depth` | Depth map for structural guidance |
| `.pose` | Pose skeleton for character positioning |
| `.canny` | Canny edge detection |
| `.scribble` | Rough sketches for composition |
| `.color` | Color palette reference |
| `.lineart` | Line art for structural guidance |
| `.softedge` | Soft edge detection |
| `.seg` | Segmentation map |
| `.inpaint` | Inpainting hint |
| `.ip2p` | Image-to-image prompt |
| `.mlsd` | MLSD line detection |
| `.tile` | Tile-based generation |
| `.blur` | Blur hint |
| `.lowquality` | Low quality hint |
| `.gray` | Grayscale hint |
| `.custom` | Generic custom type |

**Inline Builder Syntax:**

GenerationJob supports an inline builder closure for convenience:

```swift
let job = try GenerationJob(
    prompt: "A person wearing the dress from image 2",
    configuration: config,
    canvasImageData: personImage
) { builder in
    builder.addMoodboardImage(dressImage, weight: 1.0)
    builder.addMoodboardImage(backgroundImage, weight: 0.5)
}
```

**Builder Properties:**

```swift
let builder = HintBuilder()
builder.count     // Number of hints added
builder.isEmpty   // Whether any hints have been added
builder.clear()   // Remove all hints and start fresh
```

### Model Types

```swift
struct CheckpointModel { let name, file, version: String; ... }
struct LoRAModel { let name, file, version: String; ... }
struct ControlNetModel { let name, file, version: String; ... }
struct TextualInversionModel { let name, file, keyword: String; ... }
struct UpscalerModel { let name, file: String; let scaleFactor: Int; ... }
```

---

## Persistence

### Profile Storage

Profiles are automatically persisted to UserDefaults:

```swift
// Default storage (uses app bundle ID)
let manager = ConnectionManager()

// Custom storage
let storage = ProfileStorage(
    userDefaults: .standard,
    keyPrefix: "myapp"
)
let manager = ConnectionManager(storage: storage)
```

### Queue Storage

Jobs are persisted to JSON in Application Support:

```swift
// Default location: ~/Library/Application Support/{BundleID}/queue.json
let queue = JobQueue()

// Custom location
let storage = QueueStorage(fileURL: customURL)
let queue = JobQueue(storage: storage)

// Storage info
storage.storageLocation  // URL
storage.exists           // Bool
storage.fileSize         // Int64?
```

---

## Error Handling

### Connection Errors

```swift
switch connectionManager.connectionState {
case .error(let message):
    print("Connection failed: \(message)")
default:
    break
}
```

### Generation Errors

```swift
enum GenerationError: LocalizedError {
    case notConnected
    case configurationError(String)
    case serverError(String)
    case cancelled
}
```

### Queue Auto-Pause

On connectivity errors, the queue automatically pauses:
- Job remains at head of queue
- `queue.lastError` contains the error message
- Resume after reconnecting with `queue.resume()`

### Job Failures

Jobs marked as failed when:
- Server returns an error
- No images returned from generation
- Configuration is invalid

Retry with `queue.retry(job)` (max 3 retries).

---

## Complete Example

```swift
import SwiftUI
import DrawThingsKit

struct GeneratorView: View {
    // Note: Views require explicit parameters, not @EnvironmentObject
    @ObservedObject var connectionManager: ConnectionManager
    @ObservedObject var configurationManager: ConfigurationManager
    @ObservedObject var queue: JobQueue

    @State private var generatedImage: PlatformImage?
    @State private var errorMessage: String?

    var body: some View {
        VStack {
            // Connection status
            ConnectionStatusBadge(connectionManager: connectionManager)

            // Prompt input
            PromptSection(
                prompt: $configurationManager.prompt,
                negativePrompt: $configurationManager.negativePrompt
            )

            // Model selection (full signature with all bindings)
            ModelSection(
                modelsManager: connectionManager.modelsManager,
                selectedCheckpoint: $configurationManager.selectedCheckpoint,
                selectedRefiner: $configurationManager.selectedRefiner,
                refinerStart: $configurationManager.activeConfiguration.refinerStart,
                sampler: $configurationManager.activeConfiguration.sampler,
                modelName: $configurationManager.activeConfiguration.model,
                refinerName: $configurationManager.activeConfiguration.refinerModel,
                mixtureOfExperts: $configurationManager.mixtureOfExperts
            )

            // Generate button
            Button("Generate") {
                generate()
            }
            .disabled(!connectionManager.connectionState.isConnected)

            // Queue progress
            QueueProgressView(queue: queue)

            // Display result
            if let image = generatedImage {
                Image(platformImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }

            // Error display
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
            }
        }
        .onReceive(queue.events) { event in
            handleJobEvent(event)
        }
    }

    func generate() {
        configurationManager.syncModelsToConfiguration()

        do {
            let job = try GenerationJob(
                prompt: configurationManager.prompt,
                negativePrompt: configurationManager.negativePrompt,
                configuration: configurationManager.activeConfiguration
            )
            queue.enqueue(job)
            errorMessage = nil
        } catch {
            errorMessage = "Failed to create job: \(error.localizedDescription)"
        }
    }

    func handleJobEvent(_ event: JobEvent) {
        switch event {
        case .jobCompleted(_, let images):
            // Images are native PlatformImage types - ready to display
            generatedImage = images.first
        case .jobFailed(_, let error):
            errorMessage = error
        default:
            break
        }
    }
}

// Helper extension for cross-platform Image
extension Image {
    init(platformImage: PlatformImage) {
        #if os(macOS)
        self.init(nsImage: platformImage)
        #else
        self.init(uiImage: platformImage)
        #endif
    }
}
```

---

## Cross-Platform Support

DrawThingsKit supports both macOS and iOS:

| Platform | Minimum Version |
|----------|-----------------|
| macOS | 13.0+ |
| iOS | 16.0+ |

### Platform-Specific Notes

- **Views**: All SwiftUI views work on both platforms
- **Images**: Use `PlatformImage` type alias (resolves to `NSImage` on macOS, `UIImage` on iOS)
- **Image Conversion**: The Kit handles all DTTensor conversion internally - you work with native image types

```swift
// Cross-platform image handling
// Results and previews from JobQueue are already PlatformImage
queue.events.sink { event in
    switch event {
    case .jobCompleted(_, let images):
        // images is [PlatformImage] - ready to use
        let firstImage: PlatformImage? = images.first
    case .jobProgress(_, let progress):
        // previewImage is PlatformImage? - ready to display
        let preview: PlatformImage? = progress.previewImage
    default:
        break
    }
}

// For sending images TO Draw Things (canvas, hints), use PlatformImageHelpers
let canvasData = try PlatformImageHelpers.imageToDTTensor(myImage)
```

**Note**: The `ConfigurationEditorView` uses `NSPasteboard` and is only available on macOS. Other views work on both platforms.

---

## Logging

DrawThingsKit includes a unified logging system using Apple's `os.log` for efficient, structured logging.

### DTLogger

```swift
// Log messages at different levels
DTLogger.debug("Starting connection", category: .connection)
DTLogger.info("Job enqueued: \(job.id)", category: .queue)
DTLogger.warning("Retrying failed job", category: .queue)
DTLogger.error("Failed to parse config: \(error)", category: .configuration)
DTLogger.fault("Critical failure", category: .general)

// Log data payloads (debug builds only)
DTLogger.logData(requestData, label: "gRPC Request", category: .grpc)

// Log JSON configuration (debug builds only)
DTLogger.logConfiguration(configJSON, label: "Generation Config", category: .configuration)

// Scoped operation logging with timing
let endOperation = DTLogger.startOperation("Image Generation", category: .generation)
// ... do work ...
endOperation()  // Logs "Image Generation completed in 2.34s"
```

**Log Categories:**
| Category | Description |
|----------|-------------|
| `.connection` | Server connection lifecycle |
| `.queue` | Job queue operations |
| `.generation` | Image generation process |
| `.grpc` | gRPC communication details |
| `.models` | Model loading and selection |
| `.configuration` | Configuration parsing and validation |
| `.general` | General purpose logging |

**Log Levels:**
| Level | Use Case |
|-------|----------|
| `.debug` | Verbose development info |
| `.info` | General information |
| `.warning` | Potential issues |
| `.error` | Recoverable errors |
| `.fault` | Critical, unrecoverable errors |

**Configuration:**

```swift
// Access shared logger
let logger = DTLogger.shared

// Set minimum log level
logger.minimumLevel = .info  // Ignores debug messages

// Enable/disable logging
logger.isEnabled = false

// Console output (default: true in DEBUG, false in RELEASE)
logger.logToConsole = true

// Include timestamps in console output
logger.includeTimestamps = true
```

**Viewing Logs:**

In Terminal:
```bash
log stream --predicate 'subsystem == "com.drawthings.kit"' --level debug
```

In Xcode console, logs appear with timestamps and category prefixes:
```
[12:34:56.789] [Generation] Job A1B2C3D4 prompt: "a beautiful sunset"
[12:34:56.790] [gRPC] Sending generateImage request (prompt: 42 chars, config: 1024 bytes)
[12:34:58.123] [Generation] Job A1B2C3D4 completed in 1340.00ms
```

---

## Requirements

- macOS 13.0+ / iOS 16.0+
- Swift 5.9+
- DrawThingsClient package

## License

MIT License
