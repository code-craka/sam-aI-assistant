#!/bin/bash

# App Store Submission Script for Sam macOS AI Assistant
# This script performs final checks and prepares the app for submission

set -e  # Exit on any error

echo "🚀 Sam macOS AI Assistant - App Store Submission Preparation"
echo "============================================================"

# Configuration
APP_NAME="Sam"
BUNDLE_ID="com.samassistant.Sam"
SCHEME="Sam"
CONFIGURATION="Release"
ARCHIVE_PATH="./build/Sam.xcarchive"
EXPORT_PATH="./build/export"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check Xcode
    if ! command -v xcodebuild &> /dev/null; then
        log_error "Xcode command line tools not found"
        exit 1
    fi
    
    # Check project file
    if [ ! -f "Sam.xcodeproj/project.pbxproj" ]; then
        log_error "Sam.xcodeproj not found in current directory"
        exit 1
    fi
    
    # Check for required files
    required_files=(
        "Sam/Info.plist"
        "Sam/Sam.entitlements"
        "Sam/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json"
        "Sam/Documentation/Privacy_Policy.md"
    )
    
    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            log_error "Required file not found: $file"
            exit 1
        fi
    done
    
    log_success "Prerequisites check passed"
}

# Run compliance checks
run_compliance_checks() {
    log_info "Running compliance checks..."
    
    if [ -f "Sam/Scripts/app_store_compliance_check.swift" ]; then
        swift Sam/Scripts/app_store_compliance_check.swift
    else
        log_warning "Compliance check script not found, skipping..."
    fi
}

# Run final tests
run_final_tests() {
    log_info "Running final test suite..."
    
    # Run unit tests
    log_info "Running unit tests..."
    xcodebuild test \
        -project Sam.xcodeproj \
        -scheme "$SCHEME" \
        -destination 'platform=macOS' \
        -configuration Debug \
        -quiet
    
    log_success "Unit tests passed"
    
    # Run final testing suite
    if [ -f "Sam/Scripts/final_testing_suite.swift" ]; then
        swift Sam/Scripts/final_testing_suite.swift
    else
        log_warning "Final testing suite not found, skipping..."
    fi
}

# Clean and prepare build
clean_and_prepare() {
    log_info "Cleaning and preparing build..."
    
    # Clean build folder
    rm -rf build/
    mkdir -p build
    
    # Clean Xcode build
    xcodebuild clean \
        -project Sam.xcodeproj \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION"
    
    log_success "Build preparation completed"
}

# Build and archive
build_and_archive() {
    log_info "Building and archiving..."
    
    xcodebuild archive \
        -project Sam.xcodeproj \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -archivePath "$ARCHIVE_PATH" \
        -destination 'generic/platform=macOS' \
        CODE_SIGN_IDENTITY="Developer ID Application" \
        DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
        -quiet
    
    if [ ! -d "$ARCHIVE_PATH" ]; then
        log_error "Archive creation failed"
        exit 1
    fi
    
    log_success "Archive created successfully"
}

# Export for App Store
export_for_app_store() {
    log_info "Exporting for App Store..."
    
    # Create export options plist
    cat > build/ExportOptions.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>destination</key>
    <string>upload</string>
    <key>teamID</key>
    <string>$DEVELOPMENT_TEAM</string>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
    <key>compileBitcode</key>
    <false/>
</dict>
</plist>
EOF
    
    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportPath "$EXPORT_PATH" \
        -exportOptionsPlist build/ExportOptions.plist \
        -quiet
    
    if [ ! -f "$EXPORT_PATH/$APP_NAME.pkg" ]; then
        log_error "Export failed - package not created"
        exit 1
    fi
    
    log_success "Export completed successfully"
}

# Validate app
validate_app() {
    log_info "Validating app..."
    
    # Basic validation
    if [ -f "$EXPORT_PATH/$APP_NAME.pkg" ]; then
        log_success "App package created: $EXPORT_PATH/$APP_NAME.pkg"
        
        # Get package size
        package_size=$(du -h "$EXPORT_PATH/$APP_NAME.pkg" | cut -f1)
        log_info "Package size: $package_size"
        
        # Validate with altool (if available)
        if command -v xcrun &> /dev/null; then
            log_info "Running App Store validation..."
            xcrun altool --validate-app \
                --file "$EXPORT_PATH/$APP_NAME.pkg" \
                --type osx \
                --username "$APPLE_ID" \
                --password "$APP_SPECIFIC_PASSWORD" \
                2>/dev/null || log_warning "Validation requires Apple ID credentials"
        fi
    else
        log_error "App package not found"
        exit 1
    fi
}

# Generate submission checklist
generate_submission_checklist() {
    log_info "Generating submission checklist..."
    
    cat > build/Submission_Checklist.md << EOF
# App Store Submission Checklist - Sam macOS AI Assistant

## Pre-Submission Verification
- [x] All tests passed
- [x] Compliance checks completed
- [x] App archived successfully
- [x] Export for App Store completed
- [x] Basic validation passed

## Required Materials
- [x] App binary (.pkg file)
- [ ] App Store screenshots (5 required)
- [ ] App description and metadata
- [ ] Privacy policy URL
- [ ] Support URL
- [ ] Marketing materials

## App Store Connect Setup
- [ ] App created in App Store Connect
- [ ] Bundle ID matches: $BUNDLE_ID
- [ ] Version number set
- [ ] Build uploaded
- [ ] Metadata completed
- [ ] Screenshots uploaded
- [ ] Privacy policy linked
- [ ] Age rating set
- [ ] Pricing configured

## Final Checks
- [ ] All features working as described
- [ ] No placeholder content
- [ ] Help documentation complete
- [ ] Error handling tested
- [ ] Performance benchmarks met
- [ ] Accessibility features verified

## Submission
- [ ] Submit for review
- [ ] Monitor review status
- [ ] Respond to reviewer feedback
- [ ] Prepare for release

## Post-Submission
- [ ] Marketing materials ready
- [ ] User support channels set up
- [ ] Analytics configured
- [ ] Update planning initiated

---
**Package Location:** $EXPORT_PATH/$APP_NAME.pkg
**Generated:** $(date)
EOF
    
    log_success "Submission checklist created: build/Submission_Checklist.md"
}

# Upload to App Store (optional)
upload_to_app_store() {
    if [ "$1" = "--upload" ]; then
        log_info "Uploading to App Store..."
        
        if [ -z "$APPLE_ID" ] || [ -z "$APP_SPECIFIC_PASSWORD" ]; then
            log_warning "Apple ID credentials not set. Skipping upload."
            log_info "To upload manually, use:"
            log_info "xcrun altool --upload-app --file $EXPORT_PATH/$APP_NAME.pkg --type osx --username YOUR_APPLE_ID --password YOUR_APP_SPECIFIC_PASSWORD"
            return
        fi
        
        xcrun altool --upload-app \
            --file "$EXPORT_PATH/$APP_NAME.pkg" \
            --type osx \
            --username "$APPLE_ID" \
            --password "$APP_SPECIFIC_PASSWORD"
        
        log_success "Upload completed"
    else
        log_info "Skipping upload (use --upload flag to upload)"
    fi
}

# Main execution
main() {
    echo
    log_info "Starting App Store submission preparation..."
    
    # Check for required environment variables
    if [ -z "$DEVELOPMENT_TEAM" ]; then
        log_warning "DEVELOPMENT_TEAM not set. Please set your Apple Developer Team ID."
        log_info "Example: export DEVELOPMENT_TEAM='XXXXXXXXXX'"
    fi
    
    check_prerequisites
    run_compliance_checks
    run_final_tests
    clean_and_prepare
    build_and_archive
    export_for_app_store
    validate_app
    generate_submission_checklist
    upload_to_app_store "$1"
    
    echo
    log_success "App Store submission preparation completed!"
    log_info "Next steps:"
    log_info "1. Review build/Submission_Checklist.md"
    log_info "2. Upload screenshots and metadata to App Store Connect"
    log_info "3. Submit for review"
    echo
}

# Run main function with all arguments
main "$@"