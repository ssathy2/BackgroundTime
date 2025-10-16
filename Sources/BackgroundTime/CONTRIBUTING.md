# Contributing to BackgroundTime SDK

Thank you for your interest in contributing to BackgroundTime SDK! This document provides guidelines for contributing to the project.

## Development Setup

1. **Clone the repository**:
   ```bash
   git clone https://github.com/yourusername/BackgroundTime.git
   cd BackgroundTime
   ```

2. **Open in Xcode**:
   ```bash
   open Package.swift
   ```

3. **Run tests**:
   - In Xcode: Cmd+U
   - Command line: `swift test`

## Code Style

### Swift Guidelines
- Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Use Swift Concurrency (async/await, actors) over Dispatch/Combine when possible
- Prefer value types (structs) over reference types (classes) when appropriate
- Use meaningful variable and function names
- Add documentation comments for public APIs

### SwiftUI Guidelines
- Use `@State` and `@Binding` appropriately
- Prefer composition over complex single views
- Use `@MainActor` for UI-related types
- Follow Apple's accessibility guidelines

## Testing

### Test Requirements
- All new public APIs must include tests
- Use Swift Testing framework (not XCTest)
- Tests should be isolated and repeatable
- Include both positive and negative test cases

### Test Structure
```swift
import Testing
@testable import BackgroundTime

@Suite("Feature Name Tests")
struct FeatureTests {
    @Test("Should do something specific")
    func testSpecificBehavior() async throws {
        // Arrange
        // Act
        // Assert with #expect
    }
}
```

## Pull Request Process

1. **Create a feature branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes**:
   - Write code following the style guidelines
   - Add tests for new functionality
   - Update documentation if needed

3. **Test your changes**:
   ```bash
   swift test
   ```

4. **Commit your changes**:
   ```bash
   git commit -m "feat: add new feature description"
   ```

5. **Push and create PR**:
   ```bash
   git push origin feature/your-feature-name
   ```

## Commit Message Format

We follow conventional commits format:

- `feat:` New features
- `fix:` Bug fixes
- `docs:` Documentation changes
- `test:` Adding or updating tests
- `refactor:` Code refactoring
- `chore:` Maintenance tasks

Examples:
- `feat: add timeline filtering by task type`
- `fix: resolve memory leak in dashboard view`
- `docs: update installation instructions`

## Issue Reporting

When reporting issues, please include:

1. **Environment**:
   - iOS/macOS version
   - Xcode version
   - Swift version
   - BackgroundTime SDK version

2. **Description**:
   - What you expected to happen
   - What actually happened
   - Steps to reproduce

3. **Code samples** (if applicable)

4. **Screenshots** (for UI issues)

## Development Guidelines

### Adding New Features

1. **Consider the scope**: Does this belong in the core SDK or as an extension?
2. **Maintain backward compatibility**: Don't break existing APIs
3. **Update documentation**: Include usage examples
4. **Add tests**: Ensure good test coverage
5. **Consider performance**: Background monitoring should be lightweight

### Modifying Existing Features

1. **Understand the impact**: How might this affect existing users?
2. **Maintain API stability**: Avoid breaking changes in patch/minor releases
3. **Update tests**: Modify existing tests as needed
4. **Update changelog**: Document all changes

## Code Review

All submissions require review. We look for:

- **Correctness**: Does the code work as intended?
- **Style**: Does it follow our guidelines?
- **Tests**: Are there appropriate tests?
- **Documentation**: Is it well documented?
- **Performance**: Does it maintain good performance?

## Release Process

1. Update version in `Package.swift`
2. Update `CHANGELOG.md`
3. Create a release tag
4. Publish release notes

## Questions?

Feel free to open an issue with the `question` label if you need help!

Thank you for contributing! 🎉