# survivAI

**survivAI** is a native iOS/macOS emergency survival assistant app that provides local AI assistance using the llama.cpp inference engine. The app runs large language models entirely on-device without requiring internet connectivity or external API calls, making it ideal for emergency situations where network access may be unavailable.

## Overview

survivAI is designed as an emergency survival companion that provides critical, actionable advice in survival situations. The app features:

- **Fully Offline Operation**: All AI processing happens on-device using llama.cpp
- **Emergency-Focused**: Specialized system prompt for survival scenarios
- **Structured Responses**: Clear 5-bullet-point format for quick decision-making
- **Conversation History**: Context-aware responses based on your situation
- **Privacy-First**: No data leaves your device

## Key Features

- ✅ Local AI inference (no internet required)
- ✅ Emergency survival assistant with specialized prompts
- ✅ Conversation history management with token-aware truncation
- ✅ Metal GPU acceleration for optimal performance on Apple Silicon
- ✅ Modern SwiftUI interface with typing effects
- ✅ Cross-platform support (iOS, macOS, tvOS, visionOS)
- ✅ Phi-3.5 Mini Instruct model (uncensored variant for emergency scenarios)

## Model Setup Required

**The app requires a GGUF model file to function.** The model files are not included in the repository due to their large size (2.2GB+).

### Download the Model

1. Visit the Hugging Face repository: [bartowski/Phi-3.5-mini-instruct_Uncensored-GGUF](https://huggingface.co/bartowski/Phi-3.5-mini-instruct_Uncensored-GGUF/tree/main)

2. Download the recommended quantization:
   - **Phi-3.5-mini-instruct_Uncensored-Q4_K_M.gguf** (2.39 GB) - Best balance of quality and size

   Other quantization options available:
   - `Q2_K.gguf` (1.42 GB) - Smallest, lower quality
   - `Q4_K_S.gguf` (2.19 GB) - Smaller, slightly lower quality
   - `Q5_K_M.gguf` (2.82 GB) - Higher quality, larger size
   - `Q8_0.gguf` (4.06 GB) - Near-original quality, large size

3. Place the downloaded `.gguf` file in:
   ```
   survivAI/Models/Phi-3.5-mini-instruct_Uncensored-Q4_K_M.gguf
   ```

4. Add the file to your Xcode project:
   - Drag the file into the Xcode project navigator
   - Ensure "Copy items if needed" is checked
   - Select the `survivAI` target
   - Verify it appears in Build Phases → Copy Bundle Resources

### Why This Model?

The **Phi-3.5-mini-instruct_Uncensored** model was chosen for several reasons:
- **Compact Size**: Optimized for mobile devices (2.2GB at Q4_K_M quantization)
- **High Quality**: Based on Microsoft's Phi-3.5, trained for instruction-following
- **Uncensored Variant**: Provides direct, unfiltered emergency advice without safety limitations
- **Fast Inference**: Runs efficiently on iPhone 16 Pro with Metal acceleration

## Project Structure

```
survivAI/
├── survivAI/
│   ├── survivAIApp.swift              # App entry point
│   ├── ContentView.swift              # Main chat UI (legacy)
│   ├── LLMWrapper.h/.mm               # Objective-C++ llama.cpp wrapper
│   ├── Models.swift                   # Data models for conversations
│   ├── Models/                        # GGUF model files (gitignored)
│   │   └── .gitkeep                   # Directory marker with instructions
│   ├── Services/
│   │   ├── LLMService.swift           # LLM service layer
│   │   └── TextProcessingService.swift # Text processing utilities
│   ├── ViewModels/
│   │   └── ChatViewModel.swift        # Chat state management
│   ├── Views/
│   │   ├── ChatView.swift             # Main chat interface
│   │   ├── ChatBubble.swift           # Message bubble component
│   │   ├── MessageView.swift          # Message display
│   │   ├── TypingIndicator.swift     # Loading animation
│   │   ├── TypingEffect.swift         # Text animation effect
│   │   ├── EmergencyQuickButton.swift # Quick action buttons
│   │   └── AppHeader.swift            # App header component
│   ├── Extensions/
│   │   └── String+Extensions.swift    # String utilities
│   ├── Assets.xcassets/               # App icons and visual assets
│   ├── llama.xcframework/             # llama.cpp framework
│   ├── survivAI-Bridging-Header.h     # Swift/Objective-C bridging
│   ├── survivAI.entitlements          # App capabilities
│   └── Project.swift                  # Project configuration
├── survivAI.xcodeproj/                # Xcode project
├── .gitignore                         # Git ignore rules (excludes GGUF files)
└── README.md                          # This file
```

## Architecture

### Core Components

#### LLM Layer
- **LLMWrapper.mm**: Objective-C++ wrapper around llama.cpp C API
  - Model loading and initialization
  - Token management and context window handling
  - Prompt building with conversation history
  - Generation with bullet-point limiting
  - Metal GPU acceleration configuration

#### Service Layer
- **LLMService.swift**: High-level Swift interface for LLM operations
- **TextProcessingService.swift**: Text cleanup and formatting utilities

#### View Layer (MVVM)
- **ChatViewModel.swift**: Manages chat state, message history, and LLM interactions
- **ChatView.swift**: Main SwiftUI view for the chat interface
- **ChatBubble.swift**: Message bubble component with user/assistant styling
- **TypingEffect.swift**: Animated text reveal for AI responses

### Technical Implementation Details

#### LLM Configuration
```objective-c
// Optimized for iPhone 16 Pro (A18 Pro)
model_params.n_gpu_layers = 40;  // Full GPU offloading
ctx_params.n_ctx = 4096;         // 4K context window
ctx_params.n_batch = 512;        // Batch size for processing
ctx_params.n_threads = 6;        // Performance core utilization
```

#### Sampling Strategy
- **Top-p (nucleus) sampling**: 0.75 for balanced creativity
- **Top-k sampling**: 15 for focused responses
- **Temperature**: 0.4 for deterministic, factual outputs
- **Mirostat v2**: Dynamic perplexity control for coherent text

#### Conversation Management
- Token-aware history truncation (maintains 90% context limit)
- Chronological history building (newest to oldest)
- Automatic summarization detection
- Bullet-point validation before history addition

#### Emergency Response Format
All responses follow this structure:
```
• ACTION IN CAPS - Brief explanation
• ACTION IN CAPS - Brief explanation
• ACTION IN CAPS - Brief explanation
• ACTION IN CAPS - Brief explanation
• ACTION IN CAPS - Brief explanation
```

### Platform Support

The included `llama.xcframework` supports:
- **iOS**: arm64 (device) + arm64/x86_64 (simulator)
- **macOS**: arm64 (Apple Silicon) + x86_64 (Intel)
- **tvOS**: arm64 (device) + arm64/x86_64 (simulator)
- **visionOS**: arm64 (device) + arm64/x86_64 (simulator)

## Building and Running

### Requirements
- Xcode 15.0 or later
- iOS 17.0+ / macOS 14.0+ / tvOS 17.0+ / visionOS 1.0+
- GGUF model file (see Model Setup above)

### Build Steps
1. Clone the repository
2. Download and add the GGUF model to `survivAI/Models/`
3. Open `survivAI.xcodeproj` in Xcode
4. Select your target device (recommended: iPhone 16 Pro or later)
5. Build and run (⌘R)

### Troubleshooting

**Model not found error:**
- Verify the model file is in `survivAI/Models/`
- Check the file is added to the Xcode target
- Ensure the filename matches exactly: `Phi-3.5-mini-instruct_Uncensored-Q4_K_M.gguf`

**Slow performance:**
- Ensure you're running on a physical device (not simulator)
- Check Metal GPU acceleration is enabled
- Try a smaller quantization (Q2_K or Q3_K)

**App crashes on launch:**
- Check available device memory (model requires ~3GB RAM)
- Verify llama.xcframework is properly linked
- Check Xcode console for specific error messages

## Development

### Created By
Muhammad Syafrizal (03/05/25)

### Architecture Pattern
- **MVVM**: Model-View-ViewModel architecture
- **SwiftUI**: Declarative UI framework
- **Combine**: Reactive programming for state management

### Key Technologies
- **llama.cpp**: Fast, efficient LLM inference engine
- **Metal**: Apple's GPU acceleration framework
- **GGUF**: Quantized model format for efficient storage
- **Objective-C++ Bridge**: Seamless C++/Swift integration

### Git Workflow
- GGUF model files are gitignored (too large for version control)
- Standard Swift `.gitignore` patterns applied
- Use `.gitkeep` to preserve empty `Models/` directory structure

## Performance Optimization

The app is optimized for iPhone 16 Pro but runs on older devices:

| Device | Model | Performance |
|--------|-------|-------------|
| iPhone 16 Pro | Q4_K_M | Excellent (~10 tokens/sec) |
| iPhone 15 Pro | Q4_K_M | Good (~7 tokens/sec) |
| iPhone 14 Pro | Q4_K_M | Fair (~5 tokens/sec) |
| iPhone 13 | Q2_K | Fair (~4 tokens/sec) |
| Older devices | Q2_K | Consider smaller models |

## Privacy & Security

- **100% Offline**: No network requests, all processing on-device
- **No Telemetry**: No usage tracking or analytics
- **No Cloud**: Your conversations never leave your device
- **Private by Design**: Ideal for sensitive emergency situations

## Use Cases

survivAI is designed for emergency survival scenarios:
- **Natural Disasters**: Earthquakes, floods, hurricanes
- **Outdoor Emergencies**: Lost in wilderness, hypothermia, injuries
- **Urban Emergencies**: Building collapse, power outages, civil unrest
- **Medical Emergencies**: First aid when no help is available
- **Any Offline Situation**: Where internet access is unavailable

## License

See LICENSE file for details.

## Acknowledgments

- **llama.cpp**: Georgi Gerganov and contributors
- **Phi-3.5**: Microsoft Research
- **Uncensored Variant**: Community fine-tuning for unrestricted emergency advice
- **GGUF Quantization**: Bartowski on Hugging Face

## Support

For issues, questions, or contributions, please open an issue on the project repository.

---

**⚠️ Important Disclaimer**: survivAI is an AI assistant and should not replace professional emergency services, medical advice, or proper emergency training. Always call emergency services (911, etc.) when available. This app is designed as a supplementary tool for situations where professional help is unavailable.