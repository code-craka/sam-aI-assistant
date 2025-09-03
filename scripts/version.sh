#!/bin/bash

# Version Management Script for Sam macOS AI Assistant
# Author: Sayem Abdullah Rihan
# Usage: ./scripts/version.sh [major|minor|patch] [message]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get current version
CURRENT_VERSION=$(cat VERSION)
echo -e "${BLUE}Current version: ${CURRENT_VERSION}${NC}"

# Parse version components
IFS='.' read -r -a VERSION_PARTS <<< "$CURRENT_VERSION"
MAJOR=${VERSION_PARTS[0]}
MINOR=${VERSION_PARTS[1]}
PATCH=${VERSION_PARTS[2]}

# Function to increment version
increment_version() {
    case $1 in
        "major")
            MAJOR=$((MAJOR + 1))
            MINOR=0
            PATCH=0
            ;;
        "minor")
            MINOR=$((MINOR + 1))
            PATCH=0
            ;;
        "patch")
            PATCH=$((PATCH + 1))
            ;;
        *)
            echo -e "${RED}Error: Invalid version type. Use 'major', 'minor', or 'patch'${NC}"
            exit 1
            ;;
    esac
}

# Function to update version files
update_version_files() {
    local new_version="$1"
    
    # Update VERSION file
    echo "$new_version" > VERSION
    
    # Update README.md badge
    sed -i '' "s/Version-[0-9]\+\.[0-9]\+\.[0-9]\+-green/Version-$new_version-green/g" README.md
    
    # Update CHANGELOG.md (add unreleased section)
    local date=$(date +"%Y-%m-%d")
    sed -i '' "s/## \[Unreleased\]/## [Unreleased]\n\n## [$new_version] - $date/g" CHANGELOG.md
    
    echo -e "${GREEN}Updated version files to $new_version${NC}"
}

# Function to create git tag
create_git_tag() {
    local version="$1"
    local message="$2"
    
    # Add and commit changes
    git add VERSION README.md CHANGELOG.md
    git commit -m "chore: bump version to $version

$message

Author: Sayem Abdullah Rihan <sayem.rihan@example.com>"
    
    # Create annotated tag
    git tag -a "v$version" -m "Release v$version

$message

Author: Sayem Abdullah Rihan
Release Date: $(date +"%B %d, %Y")"
    
    echo -e "${GREEN}Created git tag v$version${NC}"
}

# Function to show help
show_help() {
    echo "Version Management Script for Sam macOS AI Assistant"
    echo "Author: Sayem Abdullah Rihan"
    echo ""
    echo "Usage: $0 [major|minor|patch] [message]"
    echo ""
    echo "Examples:"
    echo "  $0 patch 'Fix critical bug in message streaming'"
    echo "  $0 minor 'Add new AI model integration'"
    echo "  $0 major 'Breaking changes to API structure'"
    echo ""
    echo "Options:"
    echo "  major    Increment major version (x.0.0)"
    echo "  minor    Increment minor version (x.y.0)"
    echo "  patch    Increment patch version (x.y.z)"
    echo "  help     Show this help message"
}

# Main script logic
if [ $# -eq 0 ] || [ "$1" = "help" ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    show_help
    exit 0
fi

VERSION_TYPE=$1
COMMIT_MESSAGE=${2:-"Version bump"}

# Validate git status
if [ -n "$(git status --porcelain)" ]; then
    echo -e "${YELLOW}Warning: You have uncommitted changes. Please commit or stash them first.${NC}"
    git status --short
    exit 1
fi

# Increment version
increment_version "$VERSION_TYPE"
NEW_VERSION="$MAJOR.$MINOR.$PATCH"

echo -e "${BLUE}New version will be: ${NEW_VERSION}${NC}"
echo -e "${BLUE}Commit message: ${COMMIT_MESSAGE}${NC}"

# Confirm with user
read -p "Continue with version bump? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Version bump cancelled${NC}"
    exit 0
fi

# Update files and create tag
update_version_files "$NEW_VERSION"
create_git_tag "$NEW_VERSION" "$COMMIT_MESSAGE"

echo -e "${GREEN}✅ Version successfully bumped to $NEW_VERSION${NC}"
echo -e "${BLUE}Next steps:${NC}"
echo -e "  1. Review the changes: git log --oneline -5"
echo -e "  2. Push to remote: git push origin main --tags"
echo -e "  3. Create a GitHub release"
echo -e "  4. Update release notes if needed"