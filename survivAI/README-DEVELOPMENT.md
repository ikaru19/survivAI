# survivAI Development Guide

## Project Structure

This app uses the MVVM architecture pattern:

- **Models**: Data structures and business logic
- **Views**: UI components and layouts
- **ViewModels**: Connecting models to views, handling UI logic
- **Services**: Business logic abstractions

## Key Files

- `Models.swift`: Core data types used throughout the app
- `LLMWrapper.mm`: Objective-C++ bridge to the LLaMA model
- `TextProcessingService.swift`: Text cleaning and formatting
- `LLMService.swift`: Swift wrapper for the LLM functionality
- `ChatViewModel.swift`: Main view model for the chat interface
- `ChatView.swift`: Main chat UI

## Important Notes

1. **Models**: All models are defined in `Models.swift` in the root of the project. This ensures they're available to all files without circular imports.

2. **Memory Management**: The LLM model is resource-intensive, so always free resources in `dealloc` methods.

3. **Text Processing**: Text processing is done in Swift rather than Objective-C++ for better performance and maintainability.

4. **UI Performance**: Use `@ViewBuilder` for conditional view creation and be careful with expensive operations in view updates.

## Common Errors

1. **Model Import Issues**: If you get type errors related to `EmergencyResponse` or `UrgencyLevel`, make sure you're not redefining these types in multiple files. They should only be defined in `Models.swift`.

2. **LLM Handling**: If you get errors with the LLM interface, check the `LLMWrapper.mm` file and ensure error handling is appropriate.

3. **UI Update Problems**: If the UI isn't updating as expected, check your `@Published` properties and make sure your view observes the viewModel correctly.

## Build Performance

To improve build times:
- Move complex text processing from Objective-C++ to Swift
- Minimize unnecessary imports
- Use Swift's concurrency features with `async/await` instead of callback chains 