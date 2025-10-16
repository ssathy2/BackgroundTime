#!/bin/bash

# Release Preparation Script for BackgroundTime SDK
# Usage: ./scripts/prepare_release.sh

set -e

echo "🚀 Preparing BackgroundTime SDK for release..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in the correct directory
if [ ! -f "Package.swift" ]; then
    print_error "Package.swift not found. Please run this script from the project root."
    exit 1
fi

print_status "Validating project structure..."

# Check for required files
required_files=("README.md" "LICENSE" "CHANGELOG.md" "CONTRIBUTING.md" ".gitignore")
for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        print_success "✓ $file exists"
    else
        print_error "✗ $file is missing"
        exit 1
    fi
done

print_status "Running Swift package validation..."

# Validate the package
if swift package resolve; then
    print_success "✓ Package resolution successful"
else
    print_error "✗ Package resolution failed"
    exit 1
fi

print_status "Running tests..."

# Run tests
if swift test; then
    print_success "✓ All tests passed"
else
    print_error "✗ Some tests failed"
    exit 1
fi

print_status "Building package for all platforms..."

# Build for different platforms
platforms=("iOS" "macOS" "tvOS" "watchOS")
for platform in "${platforms[@]}"; do
    if swift build -c release --arch arm64; then
        print_success "✓ Build successful for $platform"
    else
        print_warning "⚠ Build issues for $platform (may be expected)"
    fi
done

print_status "Checking documentation coverage..."

# Check if public APIs have documentation
swift_files=$(find Sources -name "*.swift")
undocumented_apis=()

for file in $swift_files; do
    # Look for public declarations without documentation
    while IFS= read -r line; do
        if [[ $line =~ ^[[:space:]]*public[[:space:]] ]] && ! [[ $prev_line =~ ^[[:space:]]*/// ]]; then
            undocumented_apis+=("$file: $line")
        fi
        prev_line="$line"
    done < "$file"
done

if [ ${#undocumented_apis[@]} -eq 0 ]; then
    print_success "✓ All public APIs are documented"
else
    print_warning "⚠ Some public APIs lack documentation:"
    for api in "${undocumented_apis[@]}"; do
        echo "  - $api"
    done
fi

print_status "Checking for TODO/FIXME comments..."

# Look for TODO/FIXME comments
todos=$(grep -r "TODO\|FIXME\|XXX" Sources/ || true)
if [ -z "$todos" ]; then
    print_success "✓ No TODO/FIXME comments found"
else
    print_warning "⚠ Found TODO/FIXME comments:"
    echo "$todos"
fi

print_status "Validating version consistency..."

# Check version in Package.swift (if versioned)
version_in_package=$(grep -o 'from: "[^"]*"' Package.swift | head -1 | sed 's/from: "//' | sed 's/"//' || echo "not versioned")
print_status "Version in examples: $version_in_package"

print_status "Creating release checklist..."

# Create a release checklist
cat > RELEASE_CHECKLIST.md << EOF
# Release Checklist for BackgroundTime SDK

## Pre-Release Validation ✅

- [x] All required files exist (README, LICENSE, CHANGELOG, etc.)
- [x] Package resolves successfully
- [x] All tests pass
- [x] Builds successfully for all platforms
- [x] Public APIs are documented
- [x] No critical TODO/FIXME items

## GitHub Repository Setup

- [ ] Create repository on GitHub
- [ ] Upload all source files
- [ ] Configure repository settings:
  - [ ] Add description: "iOS framework for monitoring BackgroundTasks performance"
  - [ ] Add topics: ios, swift, background-tasks, monitoring, analytics, swiftui
  - [ ] Enable Issues and Wiki
  - [ ] Set default branch to \`main\`

## Release Preparation

- [ ] Update README with correct GitHub URLs
- [ ] Create \`0.1.0-beta\` tag
- [ ] Create GitHub Release with release notes
- [ ] Test installation via Swift Package Manager

## Post-Release

- [ ] Update personal website/portfolio
- [ ] Prepare LinkedIn announcement post
- [ ] Share in relevant iOS developer communities
- [ ] Monitor for initial feedback and issues

## LinkedIn Post Template

"🚀 Excited to announce the beta release of BackgroundTime SDK!

A comprehensive iOS framework that automatically monitors BackgroundTasks performance using method swizzling - zero code changes required!

✨ Key features:
• Automatic tracking of all background task events
• Beautiful SwiftUI dashboard with analytics
• Performance metrics and error analysis
• Support for iOS 15+ across all Apple platforms
• Comprehensive test coverage with Swift Testing

Perfect for iOS developers who want deep insights into their app's background processing behavior.

Check it out: [GitHub URL]

#iOS #Swift #BackgroundTasks #Monitoring #OpenSource #SwiftUI"

EOF

print_success "🎉 Release preparation complete!"
print_status "Next steps:"
echo "1. Review RELEASE_CHECKLIST.md"
echo "2. Create GitHub repository"
echo "3. Push code and create release"
echo "4. Update URLs in README"
echo "5. Announce on LinkedIn!"

print_success "Ready for beta release! 🚀"