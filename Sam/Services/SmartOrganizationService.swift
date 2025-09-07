import Foundation
import UniformTypeIdentifiers

/// Service for smart file organization based on metadata
@MainActor
class SmartOrganizationService: ObservableObject {
    
    // MARK: - Properties
    @Published var isOrganizing = false
    @Published var organizationProgress: Double = 0.0
    @Published var currentOperation: String = ""
    
    private let fileManager = FileManager.default
    private let metadataService = MetadataExtractionService()
    
    // MARK: - Public Methods
    
    /// Organize files using smart metadata-based rules
    func organizeFilesWithMetadata(
        in directory: URL,
        rules: [SmartOrganizationRule],
        createSubfolders: Bool = true,
        progressHandler: @escaping (Double, String) -> Void
    ) async throws -> SmartOrganizationResult {
        
        await MainActor.run {
            isOrganizing = true
            organizationProgress = 0.0
        }
        
        defer {
            Task { @MainActor in
                isOrganizing = false
                organizationProgress = 0.0
                currentOperation = ""
            }
        }
        
        let startTime = Date()
        
        // Step 1: Collect files
        await MainActor.run {
            currentOperation = "Collecting files..."
        }
        progressHandler(0.1, "Collecting files...")
        
        let files = try await collectFiles(from: directory)
        
        // Step 2: Extract metadata for all files
        var fileMetadataMap: [URL: FileMetadata] = [:]
        
        for (index, file) in files.enumerated() {
            let progress = 0.1 + (Double(index) / Double(files.count)) * 0.4
            await MainActor.run {
                organizationProgress = progress
                currentOperation = "Analyzing \(file.lastPathComponent)..."
            }
            progressHandler(progress, "Analyzing \(file.lastPathComponent)...")
            
            do {
                let metadata = try await metadataService.extractMetadata(from: file)
                fileMetadataMap[file] = metadata
            } catch {
                // Continue without metadata for files that can't be analyzed
                print("Failed to extract metadata from \(file.lastPathComponent): \(error)")
            }
        }
        
        // Step 3: Apply organization rules
        await MainActor.run {
            currentOperation = "Applying organization rules..."
        }
        progressHandler(0.5, "Applying organization rules...")
        
        let organizationPlan = createOrganizationPlan(
            files: files,
            metadata: fileMetadataMap,
            rules: rules,
            baseDirectory: directory,
            createSubfolders: createSubfolders
        )
        
        // Step 4: Execute organization plan
        let result = try await executeOrganizationPlan(
            organizationPlan,
            progressHandler: { progress, operation in
                let adjustedProgress = 0.5 + progress * 0.5
                progressHandler(adjustedProgress, operation)
            }
        )
        
        await MainActor.run {
            organizationProgress = 1.0
        }
        progressHandler(1.0, "Organization complete")
        
        return SmartOrganizationResult(
            processedFiles: files.count,
            movedFiles: result.movedFiles,
            createdFolders: result.createdFolders,
            appliedRules: result.appliedRules,
            errors: result.errors,
            executionTime: Date().timeIntervalSince(startTime)
        )
    }
    
    /// Create default smart organization rules
    func createDefaultRules() -> [SmartOrganizationRule] {
        return [
            // Images with GPS data
            SmartOrganizationRule(
                name: "Photos with Location",
                condition: .imageWithGPS,
                targetFolder: "Photos/With Location",
                priority: 10
            ),
            
            // Images by camera
            SmartOrganizationRule(
                name: "iPhone Photos",
                condition: .imageFromCamera("Apple"),
                targetFolder: "Photos/iPhone",
                priority: 9
            ),
            
            // Videos longer than 5 minutes
            SmartOrganizationRule(
                name: "Long Videos",
                condition: .videoLongerThan(300), // 5 minutes
                targetFolder: "Videos/Long Form",
                priority: 8
            ),
            
            // Documents by type
            SmartOrganizationRule(
                name: "PDF Documents",
                condition: .fileType("pdf"),
                targetFolder: "Documents/PDFs",
                priority: 7
            ),
            
            // Audio by artist
            SmartOrganizationRule(
                name: "Music Files",
                condition: .fileType("mp3"),
                targetFolder: "Music",
                priority: 6
            ),
            
            // Large files
            SmartOrganizationRule(
                name: "Large Files",
                condition: .fileLargerThan(100 * 1024 * 1024), // 100MB
                targetFolder: "Large Files",
                priority: 5
            ),
            
            // Old files
            SmartOrganizationRule(
                name: "Archive Old Files",
                condition: .fileOlderThan(Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()),
                targetFolder: "Archive",
                priority: 4
            )
        ]
    }
    
    /// Organize photos by date and camera
    func organizePhotosByMetadata(
        in directory: URL,
        groupBy: PhotoOrganizationMethod = .dateAndCamera
    ) async throws -> SmartOrganizationResult {
        
        let rules = createPhotoOrganizationRules(method: groupBy)
        return try await organizeFilesWithMetadata(
            in: directory,
            rules: rules,
            createSubfolders: true
        ) { progress, operation in
            // Progress handled internally
        }
    }
    
    // MARK: - Private Methods
    
    private func collectFiles(from directory: URL) async throws -> [URL] {
        let resourceKeys: [URLResourceKey] = [
            .isDirectoryKey,
            .isRegularFileKey
        ]
        
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles]
        ) else {
            throw SmartOrganizationError.directoryNotAccessible(directory.path)
        }
        
        var files: [URL] = []
        
        for case let fileURL as URL in enumerator {
            let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
            
            if resourceValues.isRegularFile == true {
                files.append(fileURL)
            }
        }
        
        return files
    }
    
    private func createOrganizationPlan(
        files: [URL],
        metadata: [URL: FileMetadata],
        rules: [SmartOrganizationRule],
        baseDirectory: URL,
        createSubfolders: Bool
    ) -> OrganizationPlan {
        
        var plan = OrganizationPlan()
        let sortedRules = rules.sorted { $0.priority > $1.priority }
        
        for file in files {
            let fileMetadata = metadata[file]
            var matched = false
            
            // Try to match against rules in priority order
            for rule in sortedRules {
                if evaluateCondition(rule.condition, file: file, metadata: fileMetadata) {
                    let targetFolder = baseDirectory.appendingPathComponent(rule.targetFolder)
                    plan.addMove(from: file, to: targetFolder, rule: rule.name)
                    matched = true
                    break
                }
            }
            
            // If no rule matched, use default organization
            if !matched && createSubfolders {
                let defaultFolder = determineDefaultFolder(for: file, metadata: fileMetadata, baseDirectory: baseDirectory)
                plan.addMove(from: file, to: defaultFolder, rule: "Default Organization")
            }
        }
        
        return plan
    }
    
    private func evaluateCondition(
        _ condition: MetadataCondition,
        file: URL,
        metadata: FileMetadata?
    ) -> Bool {
        
        switch condition {
        case .imageWithGPS:
            return metadata?.imageInfo?.gpsInfo != nil
            
        case .imageFromCamera(let make):
            return metadata?.imageInfo?.cameraInfo?.make?.lowercased().contains(make.lowercased()) == true
            
        case .videoLongerThan(let duration):
            return (metadata?.videoInfo?.duration ?? 0) > duration
            
        case .documentByAuthor(let author):
            return metadata?.documentInfo?.author?.lowercased().contains(author.lowercased()) == true
            
        case .audioByArtist(let artist):
            return metadata?.audioInfo?.artist?.lowercased().contains(artist.lowercased()) == true
            
        case .fileOlderThan(let date):
            return metadata?.basicInfo.modificationDate ?? Date() < date
            
        case .fileLargerThan(let size):
            return metadata?.basicInfo.fileSize ?? 0 > size
            
        case .fileType(let type):
            return file.pathExtension.lowercased() == type.lowercased()
            
        case .hasKeywords(let keywords):
            guard let docKeywords = metadata?.documentInfo?.keywords else { return false }
            return keywords.contains { keyword in
                docKeywords.contains { $0.lowercased().contains(keyword.lowercased()) }
            }
        }
    }
    
    private func determineDefaultFolder(
        for file: URL,
        metadata: FileMetadata?,
        baseDirectory: URL
    ) -> URL {
        
        let pathExtension = file.pathExtension.lowercased()
        
        // Determine category based on file type
        let category: String
        
        if let contentType = metadata?.basicInfo.uniformTypeIdentifier,
           let utType = UTType(contentType) {
            
            if utType.conforms(to: .image) {
                category = "Images"
            } else if utType.conforms(to: .video) {
                category = "Videos"
            } else if utType.conforms(to: .audio) {
                category = "Audio"
            } else if utType.conforms(to: .pdf) || utType.conforms(to: .text) {
                category = "Documents"
            } else if utType.conforms(to: .archive) {
                category = "Archives"
            } else if utType.conforms(to: .application) {
                category = "Applications"
            } else {
                category = "Other"
            }
        } else {
            // Fallback to extension-based categorization
            switch pathExtension {
            case "jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic":
                category = "Images"
            case "mp4", "mov", "avi", "mkv", "wmv":
                category = "Videos"
            case "mp3", "wav", "aac", "flac", "m4a":
                category = "Audio"
            case "pdf", "doc", "docx", "txt", "rtf", "pages":
                category = "Documents"
            case "zip", "rar", "7z", "tar", "gz":
                category = "Archives"
            case "app", "dmg", "pkg":
                category = "Applications"
            default:
                category = "Other"
            }
        }
        
        return baseDirectory.appendingPathComponent(category)
    }
    
    private func executeOrganizationPlan(
        _ plan: OrganizationPlan,
        progressHandler: @escaping (Double, String) -> Void
    ) async throws -> OrganizationExecutionResult {
        
        var movedFiles: [URL] = []
        var createdFolders: Set<URL> = []
        var appliedRules: [String: Int] = [:]
        var errors: [SmartOrganizationError] = []
        
        let moves = plan.moves
        
        for (index, move) in moves.enumerated() {
            let progress = Double(index) / Double(moves.count)
            await MainActor.run {
                organizationProgress = progress
                currentOperation = "Moving \(move.source.lastPathComponent)..."
            }
            progressHandler(progress, "Moving \(move.source.lastPathComponent)...")
            
            do {
                // Create target directory if it doesn't exist
                if !fileManager.fileExists(atPath: move.targetFolder.path) {
                    try fileManager.createDirectory(
                        at: move.targetFolder,
                        withIntermediateDirectories: true
                    )
                    createdFolders.insert(move.targetFolder)
                }
                
                // Generate unique filename if file already exists
                let targetFile = generateUniqueFilename(
                    in: move.targetFolder,
                    for: move.source.lastPathComponent
                )
                
                // Move the file
                try fileManager.moveItem(at: move.source, to: targetFile)
                movedFiles.append(targetFile)
                
                // Track rule usage
                appliedRules[move.ruleName, default: 0] += 1
                
            } catch {
                errors.append(SmartOrganizationError.fileMoveError(
                    source: move.source.path,
                    target: move.targetFolder.path,
                    error: error.localizedDescription
                ))
            }
        }
        
        return OrganizationExecutionResult(
            movedFiles: movedFiles,
            createdFolders: Array(createdFolders),
            appliedRules: appliedRules,
            errors: errors
        )
    }
    
    private func generateUniqueFilename(in directory: URL, for filename: String) -> URL {
        let baseURL = directory.appendingPathComponent(filename)
        
        if !fileManager.fileExists(atPath: baseURL.path) {
            return baseURL
        }
        
        let nameWithoutExtension = baseURL.deletingPathExtension().lastPathComponent
        let pathExtension = baseURL.pathExtension
        
        var counter = 1
        var uniqueURL: URL
        
        repeat {
            let uniqueName = pathExtension.isEmpty ?
                "\(nameWithoutExtension) (\(counter))" :
                "\(nameWithoutExtension) (\(counter)).\(pathExtension)"
            uniqueURL = directory.appendingPathComponent(uniqueName)
            counter += 1
        } while fileManager.fileExists(atPath: uniqueURL.path)
        
        return uniqueURL
    }
    
    private func createPhotoOrganizationRules(method: PhotoOrganizationMethod) -> [SmartOrganizationRule] {
        switch method {
        case .dateAndCamera:
            return [
                SmartOrganizationRule(
                    name: "iPhone Photos by Date",
                    condition: .imageFromCamera("Apple"),
                    targetFolder: "Photos/iPhone/By Date",
                    priority: 10
                ),
                SmartOrganizationRule(
                    name: "Canon Photos by Date",
                    condition: .imageFromCamera("Canon"),
                    targetFolder: "Photos/Canon/By Date",
                    priority: 9
                ),
                SmartOrganizationRule(
                    name: "Other Photos by Date",
                    condition: .fileType("jpg"),
                    targetFolder: "Photos/Other/By Date",
                    priority: 8
                )
            ]
            
        case .location:
            return [
                SmartOrganizationRule(
                    name: "Photos with GPS",
                    condition: .imageWithGPS,
                    targetFolder: "Photos/By Location",
                    priority: 10
                ),
                SmartOrganizationRule(
                    name: "Photos without GPS",
                    condition: .fileType("jpg"),
                    targetFolder: "Photos/No Location",
                    priority: 5
                )
            ]
            
        case .camera:
            return [
                SmartOrganizationRule(
                    name: "iPhone Photos",
                    condition: .imageFromCamera("Apple"),
                    targetFolder: "Photos/iPhone",
                    priority: 10
                ),
                SmartOrganizationRule(
                    name: "Canon Photos",
                    condition: .imageFromCamera("Canon"),
                    targetFolder: "Photos/Canon",
                    priority: 9
                ),
                SmartOrganizationRule(
                    name: "Nikon Photos",
                    condition: .imageFromCamera("Nikon"),
                    targetFolder: "Photos/Nikon",
                    priority: 8
                )
            ]
        }
    }
}

// MARK: - Supporting Types

/// Photo organization methods
enum PhotoOrganizationMethod {
    case dateAndCamera
    case location
    case camera
}

/// Organization plan containing all planned moves
private struct OrganizationPlan {
    private(set) var moves: [FileMove] = []
    
    mutating func addMove(from source: URL, to targetFolder: URL, rule: String) {
        moves.append(FileMove(
            source: source,
            targetFolder: targetFolder,
            ruleName: rule
        ))
    }
}

/// Individual file move operation
private struct FileMove {
    let source: URL
    let targetFolder: URL
    let ruleName: String
}

/// Result of organization execution
private struct OrganizationExecutionResult {
    let movedFiles: [URL]
    let createdFolders: [URL]
    let appliedRules: [String: Int]
    let errors: [SmartOrganizationError]
}

/// Result of smart organization operation
struct SmartOrganizationResult {
    let processedFiles: Int
    let movedFiles: [URL]
    let createdFolders: [URL]
    let appliedRules: [String: Int]
    let errors: [SmartOrganizationError]
    let executionTime: TimeInterval
    
    var successRate: Double {
        guard processedFiles > 0 else { return 0 }
        return Double(movedFiles.count) / Double(processedFiles)
    }
    
    var summary: String {
        let movedCount = movedFiles.count
        let folderCount = createdFolders.count
        let errorCount = errors.count
        
        var summary = "Organized \(movedCount) files into \(folderCount) folders"
        if errorCount > 0 {
            summary += " with \(errorCount) errors"
        }
        return summary
    }
}

/// Errors that can occur during smart organization
enum SmartOrganizationError: LocalizedError {
    case directoryNotAccessible(String)
    case fileMoveError(source: String, target: String, error: String)
    case folderCreationError(String)
    case metadataExtractionError(String)
    
    var errorDescription: String? {
        switch self {
        case .directoryNotAccessible(let path):
            return "Cannot access directory: \(path)"
        case .fileMoveError(let source, let target, let error):
            return "Failed to move \(URL(fileURLWithPath: source).lastPathComponent) to \(URL(fileURLWithPath: target).lastPathComponent): \(error)"
        case .folderCreationError(let path):
            return "Failed to create folder: \(path)"
        case .metadataExtractionError(let error):
            return "Metadata extraction failed: \(error)"
        }
    }
}