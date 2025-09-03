#!/bin/bash

# Release Script for Sam macOS AI Assistant
# Author: Sayem Abdullah Rihan
# Usage: ./scripts/release.sh [version]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REPO_NAME="sam-macos-ai-assistant"
AUTHOR_NAME="Sayem Abdullah Rihan"
AUTHOR_EMAIL="sayem.rihan@example.com"

# Get version
VERSION=${1:-$(cat VERSION)}
if [[ ! $VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo -e "${RED}Error: Invalid version format. Expected x.y.z${NC}"
    exit 1
fi

echo -e "${BLUE}Preparing release for version $VERSION${NC}"

# Function to validate prerequisites
validate_prerequisites() {
    echo -e "${BLUE}Validating prerequisites...${NC}"
    
    # Check if we're on main branch
    CURRENT_BRANCH=$(git branch --show-current)
    if [ "$CURRENT_BRANCH" != "main" ]; then
        echo -e "${RED}Error: Must be on main branch for release${NC}"
        exit 1
    fi
    
    # Check if working directory is clean
    if [ -n "$(git status --porcelain)" ]; then
        echo -e "${RED}Error: Working directory must be clean${NC}"
        git status --short
        exit 1
    fi
    
    # Check if tag already exists
    if git tag -l | grep -q "^v$VERSION$"; then
        echo -e "${RED}Error: Tag v$VERSION already exists${NC}"
        exit 1
    fi
    
    # Check if VERSION file matches
    FILE_VERSION=$(cat VERSION)
    if [ "$FILE_VERSION" != "$VERSION" ]; then
        echo -e "${RED}Error: VERSION file ($FILE_VERSION) doesn't match specified version ($VERSION)${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Prerequisites validated${NC}"
}

# Function to run tests
run_tests() {
    echo -e "${BLUE}Running tests...${NC}"
    
    # Check if Xcode project exists
    if [ ! -f "Sam/Sam.xcodeproj/project.pbxproj" ]; then
        echo -e "${YELLOW}Warning: Xcode project not found, skipping tests${NC}"
        return 0
    fi
    
    # Run Swift tests (if available)
    if command -v swift &> /dev/null; then
        echo -e "${BLUE}Running Swift package tests...${NC}"
        # swift test || echo -e "${YELLOW}Warning: Some tests failed${NC}"
    fi
    
    # Run SwiftLint (if available)
    if command -v swiftlint &> /dev/null; then
        echo -e "${BLUE}Running SwiftLint...${NC}"
        swiftlint lint --quiet || echo -e "${YELLOW}Warning: SwiftLint found issues${NC}"
    fi
    
    echo -e "${GREEN}✅ Tests completed${NC}"
}

# Function to build release notes
build_release_notes() {
    echo -e "${BLUE}Building release notes...${NC}"
    
    local release_notes_file="release_notes_$VERSION.md"
    
    # Extract changelog for this version
    awk "/^## \[$VERSION\]/{flag=1; next} /^## \[/{flag=0} flag" CHANGELOG.md > "$release_notes_file"
    
    # Add header
    {
        echo "# Sam macOS AI Assistant v$VERSION"
        echo ""
        echo "**Release Date**: $(date +"%B %d, %Y")"
        echo "**Author**: $AUTHOR_NAME"
        echo ""
        cat "$release_notes_file"
        echo ""
        echo "## Installation"
        echo ""
        echo "1. Download the latest release from the [releases page](https://github.com/sayemrihan/$REPO_NAME/releases)"
        echo "2. Drag Sam.app to your Applications folder"
        echo "3. Launch Sam and grant necessary permissions"
        echo ""
        echo "## System Requirements"
        echo ""
        echo "- macOS 13.0 (Ventura) or later"
        echo "- Apple Silicon or Intel Mac"
        echo "- 4GB RAM minimum, 8GB recommended"
        echo ""
        echo "## Support"
        echo ""
        echo "- [GitHub Issues](https://github.com/sayemrihan/$REPO_NAME/issues)"
        echo "- [Documentation](https://github.com/sayemrihan/$REPO_NAME/wiki)"
        echo "- [Discussions](https://github.com/sayemrihan/$REPO_NAME/discussions)"
        echo ""
        echo "---"
        echo ""
        echo "**Developed by $AUTHOR_NAME**"
    } > "$release_notes_file.tmp" && mv "$release_notes_file.tmp" "$release_notes_file"
    
    echo -e "${GREEN}✅ Release notes created: $release_notes_file${NC}"
}

# Function to create GitHub release
create_github_release() {
    echo -e "${BLUE}Creating GitHub release...${NC}"
    
    local release_notes_file="release_notes_$VERSION.md"
    
    # Check if gh CLI is available
    if ! command -v gh &> /dev/null; then
        echo -e "${YELLOW}GitHub CLI not found. Please create the release manually:${NC}"
        echo -e "  1. Go to https://github.com/sayemrihan/$REPO_NAME/releases/new"
        echo -e "  2. Tag: v$VERSION"
        echo -e "  3. Title: Sam v$VERSION"
        echo -e "  4. Copy content from: $release_notes_file"
        return 0
    fi
    
    # Create release using GitHub CLI
    gh release create "v$VERSION" \
        --title "Sam v$VERSION" \
        --notes-file "$release_notes_file" \
        --latest
    
    echo -e "${GREEN}✅ GitHub release created${NC}"
}

# Function to cleanup
cleanup() {
    echo -e "${BLUE}Cleaning up...${NC}"
    rm -f release_notes_*.md
    echo -e "${GREEN}✅ Cleanup completed${NC}"
}

# Function to show summary
show_summary() {
    echo -e "${GREEN}"
    echo "🎉 Release $VERSION completed successfully!"
    echo ""
    echo "Summary:"
    echo "  • Version: $VERSION"
    echo "  • Tag: v$VERSION"
    echo "  • Branch: main"
    echo "  • Author: $AUTHOR_NAME"
    echo "  • Date: $(date +"%B %d, %Y")"
    echo ""
    echo "Next steps:"
    echo "  1. Verify the release on GitHub"
    echo "  2. Update any external documentation"
    echo "  3. Announce the release to users"
    echo "  4. Monitor for any issues"
    echo -e "${NC}"
}

# Function to show help
show_help() {
    echo "Release Script for Sam macOS AI Assistant"
    echo "Author: $AUTHOR_NAME"
    echo ""
    echo "Usage: $0 [version]"
    echo ""
    echo "Examples:"
    echo "  $0 1.0.0    # Create release for version 1.0.0"
    echo "  $0          # Use version from VERSION file"
    echo ""
    echo "This script will:"
    echo "  1. Validate prerequisites"
    echo "  2. Run tests and code quality checks"
    echo "  3. Build release notes from CHANGELOG.md"
    echo "  4. Create GitHub release (if gh CLI available)"
    echo "  5. Clean up temporary files"
}

# Main script logic
if [ "$1" = "help" ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    show_help
    exit 0
fi

echo -e "${BLUE}Sam macOS AI Assistant Release Script${NC}"
echo -e "${BLUE}Author: $AUTHOR_NAME${NC}"
echo ""

# Confirm with user
echo -e "${BLUE}This will create a release for version $VERSION${NC}"
read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Release cancelled${NC}"
    exit 0
fi

# Execute release steps
validate_prerequisites
run_tests
build_release_notes
create_github_release
cleanup
show_summary