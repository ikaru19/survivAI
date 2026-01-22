# survivAI

**survivAI** is a native iOS/macOS app that provides local AI assistance using the llama.cpp inference engine. The app runs large language models entirely on-device without requiring internet connectivity or external API calls.

## Overview

This SwiftUI application provides a simple chat interface for interacting with local LLM models. Users can ask questions through a text input field and receive AI-generated responses processed locally on their device.

## Architecture

### Core Components

- **survivAIApp.swift**: Main app entry point using SwiftUI App lifecycle
- **ContentView.swift**: Primary UI view containing the chat interface
- **LLMWrapper.h/.mm**: Objective-C++ wrapper around the llama.cpp C++ library with full implementation

### Key Features

- Local AI inference (no internet required)
- Simple text-based chat interface  
- Cross-platform support (iOS, macOS, tvOS, visionOS)
- Built with SwiftUI for native Apple platform integration

### Dependencies

- **llama.xcframework**: Multi-platform framework containing llama.cpp binaries
  - Supports: iOS (arm64 + simulator), macOS (arm64/x86_64), tvOS, visionOS
  - Includes GGML backend for optimized inference
  - Headers expose C API for llama.cpp functionality

## Project Structure

```
survivAI/
├── survivAIApp.swift          # App entry point
├── ContentView.swift          # Main chat UI with SwiftUI
├── LLMWrapper.h/.mm          # Objective-C++ llama.cpp wrapper
├── Models.swift              # Data models for conversations
├── Project.swift             # Project configuration
├── survivAI-Bridging-Header.h # Swift/Objective-C bridging
├── survivAI.entitlements     # App capabilities/permissions
├── Assets.xcassets/          # App icons and visual assets
├── Extensions/               # Swift extensions
├── Services/                 # Business logic services
├── ViewModels/              # MVVM view models
├── Views/                   # Additional SwiftUI views
├── Models/                  # Core model files
├── Resources/               # App resources
└── llama.xcframework/       # llama.cpp framework
```

## Technical Implementation

### UI Components
- Text field for user input with rounded border styling
- Button trigger for AI interaction
- Response display area
- Vertical stack layout with proper padding

### Core Implementation
The `LLMWrapper` class is fully implemented with:
- Phi-3 Mini 128K Instruct model integration (Q4_K_M quantization)
- Metal GPU acceleration for A18 Pro optimization  
- Conversation history management with token-aware truncation
- Emergency survival assistant system prompt
- Deterministic sampling for factual responses
- Context-aware conversation summarization

### Platform Support
The included xcframework supports all major Apple platforms:
- iOS 
- macOS (Intel + Apple Silicon)
- tvOS
- visionOS (Apple Vision Pro)

## Development Notes

- Created by Muhammad Syafrizal on 03/05/25
- Uses modern SwiftUI patterns with `@State` property wrappers
- Leverages SwiftUI previews for development
- Complete implementation with Phi-3 model integration
- Optimized for iPhone 16 Pro (A18 Pro) with Metal acceleration
- Uses MVVM architecture with SwiftUI

## For AI Code Analysis

This project demonstrates:
- Native iOS AI app development patterns
- SwiftUI state management for interactive UIs  
- Integration of C/C++ libraries (llama.cpp) with Swift
- Cross-platform Apple ecosystem development
- Local inference architecture for privacy-focused AI apps

The app aims to provide a "survival AI" assistant that works offline, making it useful in scenarios without internet connectivity.