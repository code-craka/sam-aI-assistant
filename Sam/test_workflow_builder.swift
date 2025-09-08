#!/usr/bin/env swift

import Foundation

// Simple test to verify WorkflowBuilder compilation
print("Testing WorkflowBuilder compilation...")

// Test that we can create a WorkflowBuilder instance
let builder = WorkflowBuilder()
print("✓ WorkflowBuilder instance created successfully")

// Test built-in templates
let allTemplates = WorkflowBuilder.getAllBuiltInTemplates()
print("✓ Found \(allTemplates.count) built-in templates")

// Test template search
let searchResults = WorkflowBuilder.searchTemplates("backup")
print("✓ Found \(searchResults.count) templates matching 'backup'")

// Test template categories
let fileManagementTemplates = WorkflowBuilder.getTemplates(for: .fileManagement)
print("✓ Found \(fileManagementTemplates.count) file management templates")

print("All WorkflowBuilder tests passed! ✅")