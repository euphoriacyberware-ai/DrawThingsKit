# DrawThingsKit

A Swift package providing UI components, utilities, and model management for building Draw Things gRPC client applications.

## Overview

DrawThingsKit abstracts away the complexity of connecting to Draw Things servers, managing generation jobs, and provides reusable SwiftUI components for configuration editing and queue management. It's built on top of **DrawThingsClient** and designed for macOS applications.

## Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/euphoriacyberware-ai/DrawThingsKit", from: "1.0.0")
]
```

Or add via Xcode: File → Add Packages → Enter the repository URL.

## Quick Start

```swift
import SwiftUI
import DrawThingsKit

@main
struct MyApp: App {
    @StateObject private var connectionManager = ConnectionManager()
    @StateObject private var queue = JobQueue()
    @StateObject private var processor = QueueProcessor()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(connectionManager)
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
├── Models/            # Model catalog management
├── Queue/             # Job queue & processing
└── Views/             # Reusable SwiftUI components (macOS)
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
- `isPaused: Bool` - Whether queue is paused
- `currentPreview: NSImage?` - Preview of current generation
- `currentProgress: JobProgress?` - Progress of current job

**Computed Properties:**
- `pendingJobs`, `completedJobs`, `failedJobs` - Filtered job lists
- `pendingCount`, `activeQueueCount` - Counts
- `hasPendingJobs`, `isEmpty` - State checks

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

// Results (after completion)
job.resultImages  // Array of PNG Data
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
config.seed = 12345  // nil for random

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

// Toolbar-style control strip
QueueToolbar(queue: queue) {
    // Add job action
}

// Compact list (no progress section)
QueueListView(queue: queue)

// Sidebar-style layout
QueueSidebarView(queue: queue)
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
    var previewImageData: Data?

    var progressFraction: Double   // 0.0 to 1.0
    var progressPercentage: Int    // 0 to 100
}
```

### HintData

Used for control images (shuffle hints, IP-Adapter, etc.):

```swift
struct HintData {
    var type: String      // "shuffle", "ip_adapter", etc.
    var imageData: Data   // Image bytes
    var weight: Float
}
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
    @EnvironmentObject var connectionManager: ConnectionManager
    @EnvironmentObject var queue: JobQueue

    @State private var prompt = ""
    @State private var negativePrompt = ""

    var body: some View {
        VStack {
            // Connection status
            ConnectionStatusBadge(connectionManager: connectionManager)

            // Prompt input
            TextField("Prompt", text: $prompt)
            TextField("Negative", text: $negativePrompt)

            // Generate button
            Button("Generate") {
                generate()
            }
            .disabled(!connectionManager.connectionState.isConnected)

            // Queue progress
            QueueProgressView(queue: queue)

            // Queue controls
            QueueControlsView(queue: queue)
        }
    }

    func generate() {
        var config = DrawThingsConfiguration()
        config.width = 1024
        config.height = 1024
        config.steps = 30
        config.model = connectionManager.modelsManager.checkpoints.first?.file ?? ""

        do {
            let job = try GenerationJob(
                prompt: prompt,
                negativePrompt: negativePrompt,
                configuration: config
            )
            queue.enqueue(job)
        } catch {
            print("Failed to create job: \(error)")
        }
    }
}
```

---

## Requirements

- macOS 13.0+ (for SwiftUI views)
- Swift 5.9+
- DrawThingsClient package

## License

MIT License
