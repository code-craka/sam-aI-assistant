import Foundation
import CryptoKit

/// Service for detecting duplicate files using various strategies
@MainActor
class DuplicateDetectionService: ObservableObject {
    
    // MARK: - Properties
    @Published var isScanning = false
    @Published var scanProgress: Double = 0.0
    @Published var currentFile: String = ""
    
    private let fileManager = FileManager.default
    private let metadataService = MetadataExtractionService()
    
    // MARK: - Public Methods
    
    /// Detect duplicates in specified directories
    func detectDuplicates(
        in directories: [URL],
        methods: Set<DuplicateDetectionMethod> = [.contentHash, .nameAndSize],
        progressHandler: @escaping (Double, String) -> Void
    ) async throws -> DuplicateDetectionResult {
        
        await MainActor.run {
            isScanning = true
            scanProgress = 0.0
        }
        
        defer {
            Task { @MainActor in
                isScanning = false
                scanProgress = 0.0
                currentFile = ""
            }
        }
        
        let startTime = Date()
        
        // Step 1: Collect all files
        await MainActor.run {
            currentFile = "Collecting files..."
        }
        progressHandler(0.1, "Collecting files...")
        
        let allFiles = try await collectFiles(from: directories)
        
        // Step 2: Calculate hashes and metadata if needed
        var fileInfoMap: [URL: FileAnalysisInfo] = [:]
        
        for (index, file) in allFiles.enumerated() {
            let progress = 0.1 + (Double(index) / Double(allFiles.count)) * 0.7
            await MainActor.run {
                scanProgress = progress
                currentFile = "Analyzing \(file.lastPathComponent)..."
            }
            progressHandler(progress, "Analyzing \(file.lastPathComponent)...")
            
            do {
                let analysisInfo = try await analyzeFile(file, methods: methods)
                fileInfoMap[file] = analysisInfo
            } catch {
                // Skip files that can't be analyzed
                print("Failed to analyze \(file.lastPathComponent): \(error)")
            }
        }
        
        // Step 3: Find duplicates using specified methods
        await MainActor.run {
            currentFile = "Finding duplicates..."
        }
        progressHandler(0.8, "Finding duplicates...")
        
        let duplicateGroups = findDuplicateGroups(from: fileInfoMap, methods: methods)
        
        // Step 4: Calculate statistics
        await MainActor.run {
            currentFile = "Calculating statistics..."
        }
        progressHandler(0.9, "Calculating statistics...")
        
        let totalDuplicates = duplicateGroups.reduce(0) { $0 + max(0, $1.files.count - 1) }
        let potentialSavings = duplicateGroups.reduce(Int64(0)) { total, group in
            let duplicateFiles = group.duplicateFiles
            return total + duplicateFiles.reduce(Int64(0)) { $0 + $1.size }
        }
        
        await MainActor.run {
            scanProgress = 1.0
        }
        progressHandler(1.0, "Complete")
        
        return DuplicateDetectionResult(
            duplicateGroups: duplicateGroups,
            totalDuplicates: totalDuplicates,
            potentialSpaceSavings: potentialSavings,
            scanTime: Date().timeIntervalSince(startTime),
            scannedFiles: allFiles.count
        )
    }
    
    /// Remove duplicate files, keeping the original
    func removeDuplicates(
        from groups: [DuplicateGroup],
        keepStrategy: KeepStrategy = .oldest
    ) async throws -> DuplicateRemovalResult {
        
        var removedFiles: [URL] = []
        var errors: [DuplicateRemovalError] = []
        var spaceSaved: Int64 = 0
        
        for group in groups {
            let filesToKeep = selectFilesToKeep(from: group, strategy: keepStrategy)
            let filesToRemove = group.files.filter { file in
                !filesToKeep.contains { $0.id == file.id }
            }
            
            for file in filesToRemove {
                do {
                    // Move to trash instead of permanent deletion for safety
                    var trashedURL: NSURL?
                    try fileManager.trashItem(at: file.url, resultingItemURL: &trashedURL)
                    removedFiles.append(file.url)
                    spaceSaved += file.size
                } catch {
                    errors.append(DuplicateRemovalError(
                        file: file.url,
                        error: error.localizedDescription
                    ))
                }
            }
        }
        
        return DuplicateRemovalResult(
            removedFiles: removedFiles,
            spaceSaved: spaceSaved,
            errors: errors
        )
    }
    
    // MARK: - Private Methods
    
    private func collectFiles(from directories: [URL]) async throws -> [URL] {
        var allFiles: [URL] = []
        
        for directory in directories {
            let files = try await collectFilesRecursively(from: directory)
            allFiles.append(contentsOf: files)
        }
        
        return allFiles
    }
    
    private func collectFilesRecursively(from directory: URL) async throws -> [URL] {
        var files: [URL] = []
        
        let resourceKeys: [URLResourceKey] = [
            .isDirectoryKey,
            .isRegularFileKey,
            .fileSizeKey
        ]
        
        let contents = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles]
        )
        
        for fileURL in contents {
            let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
            
            // Only include regular files
            if resourceValues.isRegularFile == true {
                files.append(fileURL)
            }
            
            // Recursively process subdirectories
            if resourceValues.isDirectory == true {
                let subFiles = try await collectFilesRecursively(from: fileURL)
                files.append(contentsOf: subFiles)
            }
        }
        
        return files
    }
    
    private func analyzeFile(_ url: URL, methods: Set<DuplicateDetectionMethod>) async throws -> FileAnalysisInfo {
        let resourceValues = try url.resourceValues(forKeys: [
            .fileSizeKey,
            .contentModificationDateKey
        ])
        
        let size = Int64(resourceValues.fileSize ?? 0)
        let modificationDate = resourceValues.contentModificationDate ?? Date()
        
        var contentHash: String?
        
        // Calculate content hash if needed
        if methods.contains(.contentHash) {
            contentHash = try await calculateFileHash(url)
        }
        
        return FileAnalysisInfo(
            url: url,
            size: size,
            modificationDate: modificationDate,
            contentHash: contentHash
        )
    }
    
    private func calculateFileHash(_ url: URL) async throws -> String {
        let data = try Data(contentsOf: url)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    private func findDuplicateGroups(
        from fileInfoMap: [URL: FileAnalysisInfo],
        methods: Set<DuplicateDetectionMethod>
    ) -> [DuplicateGroup] {
        
        var duplicateGroups: [DuplicateGroup] = []
        
        // Group by content hash (exact duplicates)
        if methods.contains(.contentHash) {
            let hashGroups = groupByContentHash(fileInfoMap)
            duplicateGroups.append(contentsOf: hashGroups)
        }
        
        // Group by name and size
        if methods.contains(.nameAndSize) {
            let nameGroups = groupByNameAndSize(fileInfoMap)
            duplicateGroups.append(contentsOf: nameGroups)
        }
        
        // Group by size only
        if methods.contains(.sizeOnly) {
            let sizeGroups = groupBySizeOnly(fileInfoMap)
            duplicateGroups.append(contentsOf: sizeGroups)
        }
        
        // Remove groups with only one file
        return duplicateGroups.filter { $0.files.count > 1 }
    }
    
    private func groupByContentHash(_ fileInfoMap: [URL: FileAnalysisInfo]) -> [DuplicateGroup] {
        var hashGroups: [String: [FileAnalysisInfo]] = [:]
        
        for (_, info) in fileInfoMap {
            guard let hash = info.contentHash else { continue }
            hashGroups[hash, default: []].append(info)
        }
        
        return hashGroups.compactMap { (hash, infos) in
            guard infos.count > 1 else { return nil }
            
            let fileInfos = infos.map { info in
                FileInfo(
                    url: info.url,
                    name: info.url.lastPathComponent,
                    size: info.size,
                    dateModified: info.modificationDate,
                    fileType: info.url.pathExtension,
                    isDirectory: false
                )
            }
            
            return DuplicateGroup(
                files: fileInfos,
                duplicateType: .exactMatch,
                totalSize: infos.reduce(0) { $0 + $1.size },
                potentialSavings: infos.dropFirst().reduce(0) { $0 + $1.size }
            )
        }
    }
    
    private func groupByNameAndSize(_ fileInfoMap: [URL: FileAnalysisInfo]) -> [DuplicateGroup] {
        var nameGroups: [String: [FileAnalysisInfo]] = [:]
        
        for (_, info) in fileInfoMap {
            let key = "\(info.url.lastPathComponent)_\(info.size)"
            nameGroups[key, default: []].append(info)
        }
        
        return nameGroups.compactMap { (key, infos) in
            guard infos.count > 1 else { return nil }
            
            let fileInfos = infos.map { info in
                FileInfo(
                    url: info.url,
                    name: info.url.lastPathComponent,
                    size: info.size,
                    dateModified: info.modificationDate,
                    fileType: info.url.pathExtension,
                    isDirectory: false
                )
            }
            
            return DuplicateGroup(
                files: fileInfos,
                duplicateType: .nameMatch,
                totalSize: infos.reduce(0) { $0 + $1.size },
                potentialSavings: infos.dropFirst().reduce(0) { $0 + $1.size }
            )
        }
    }
    
    private func groupBySizeOnly(_ fileInfoMap: [URL: FileAnalysisInfo]) -> [DuplicateGroup] {
        var sizeGroups: [Int64: [FileAnalysisInfo]] = [:]
        
        for (_, info) in fileInfoMap {
            sizeGroups[info.size, default: []].append(info)
        }
        
        return sizeGroups.compactMap { (size, infos) in
            guard infos.count > 1, size > 0 else { return nil }
            
            let fileInfos = infos.map { info in
                FileInfo(
                    url: info.url,
                    name: info.url.lastPathComponent,
                    size: info.size,
                    dateModified: info.modificationDate,
                    fileType: info.url.pathExtension,
                    isDirectory: false
                )
            }
            
            return DuplicateGroup(
                files: fileInfos,
                duplicateType: .sizeMatch,
                totalSize: infos.reduce(0) { $0 + $1.size },
                potentialSavings: infos.dropFirst().reduce(0) { $0 + $1.size }
            )
        }
    }
    
    private func selectFilesToKeep(from group: DuplicateGroup, strategy: KeepStrategy) -> [FileInfo] {
        switch strategy {
        case .oldest:
            return [group.files.min(by: { $0.dateModified < $1.dateModified })!]
        case .newest:
            return [group.files.max(by: { $0.dateModified < $1.dateModified })!]
        case .shortest:
            return [group.files.min(by: { $0.name.count < $1.name.count })!]
        case .longest:
            return [group.files.max(by: { $0.name.count < $1.name.count })!]
        case .firstFound:
            return [group.files.first!]
        }
    }
}

// MARK: - Supporting Types

/// Methods for detecting duplicates
enum DuplicateDetectionMethod {
    case contentHash    // Compare file content hashes (most accurate)
    case nameAndSize    // Compare filename and size
    case sizeOnly       // Compare size only (fastest, least accurate)
}

/// Strategy for which files to keep when removing duplicates
enum KeepStrategy {
    case oldest         // Keep the oldest file
    case newest         // Keep the newest file
    case shortest       // Keep file with shortest name
    case longest        // Keep file with longest name
    case firstFound     // Keep the first file found
}

/// Internal file analysis information
private struct FileAnalysisInfo {
    let url: URL
    let size: Int64
    let modificationDate: Date
    let contentHash: String?
}

/// Result of duplicate removal operation
struct DuplicateRemovalResult {
    let removedFiles: [URL]
    let spaceSaved: Int64
    let errors: [DuplicateRemovalError]
    
    var formattedSpaceSaved: String {
        ByteCountFormatter.string(fromByteCount: spaceSaved, countStyle: .file)
    }
}

/// Error during duplicate removal
struct DuplicateRemovalError {
    let file: URL
    let error: String
}

/// Errors that can occur during duplicate detection
enum DuplicateDetectionError: LocalizedError {
    case directoryNotAccessible(String)
    case fileNotReadable(String)
    case hashCalculationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .directoryNotAccessible(let path):
            return "Cannot access directory: \(path)"
        case .fileNotReadable(let path):
            return "Cannot read file: \(path)"
        case .hashCalculationFailed(let path):
            return "Failed to calculate hash for: \(path)"
        }
    }
}