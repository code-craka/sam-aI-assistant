import Foundation
import CoreGraphics
import ImageIO
import AVFoundation
import PDFKit
import UniformTypeIdentifiers

// MARK: - File Operations

/// Represents different types of file operations
enum FileOperation {
    case copy(source: URL, destination: URL)
    case move(source: URL, destination: URL)
    case delete(files: [URL], moveToTrash: Bool)
    case rename(file: URL, newName: String)
    case organize(directory: URL, strategy: OrganizationStrategy)
    case search(criteria: SearchCriteria)
    case extractMetadata(files: [URL])
    case detectDuplicates(directories: [URL], methods: Set<DuplicateDetectionMethod>)
    case removeDuplicates(groups: [DuplicateGroup], keepStrategy: KeepStrategy)
    case smartOrganize(directory: URL, rules: [SmartOrganizationRule])
    
    var description: String {
        switch self {
        case .copy(let source, let destination):
            return "Copy \(source.lastPathComponent) to \(destination.deletingLastPathComponent().lastPathComponent)"
        case .move(let source, let destination):
            return "Move \(source.lastPathComponent) to \(destination.deletingLastPathComponent().lastPathComponent)"
        case .delete(let files, let moveToTrash):
            let action = moveToTrash ? "Move to Trash" : "Delete"
            return "\(action) \(files.count) file(s)"
        case .rename(let file, let newName):
            return "Rename \(file.lastPathComponent) to \(newName)"
        case .organize(let directory, let strategy):
            return "Organize \(directory.lastPathComponent) by \(strategy.description)"
        case .search(let criteria):
            return "Search for '\(criteria.query)'"
        case .extractMetadata(let files):
            return "Extract metadata from \(files.count) file(s)"
        case .detectDuplicates(let directories, _):
            return "Detect duplicates in \(directories.count) director(ies)"
        case .removeDuplicates(let groups, _):
            return "Remove duplicates from \(groups.count) group(s)"
        case .smartOrganize(let directory, _):
            return "Smart organize \(directory.lastPathComponent)"
        }
    }
}

// MARK: - Operation Results

/// Result of a file operation
struct OperationResult {
    let success: Bool
    let processedFiles: [URL]
    let errors: [FileOperationError]
    let summary: String
    let executionTime: TimeInterval
    let undoAction: (() -> Void)?
    
    init(
        success: Bool,
        processedFiles: [URL] = [],
        errors: [FileOperationError] = [],
        summary: String,
        executionTime: TimeInterval = 0,
        undoAction: (() -> Void)? = nil
    ) {
        self.success = success
        self.processedFiles = processedFiles
        self.errors = errors
        self.summary = summary
        self.executionTime = executionTime
        self.undoAction = undoAction
    }
}

/// Result of batch operations
struct BatchOperationResult {
    let totalOperations: Int
    let successfulOperations: Int
    let failedOperations: Int
    let results: [OperationResult]
    let errors: [FileOperationError]
    let summary: String
    
    var successRate: Double {
        guard totalOperations > 0 else { return 0 }
        return Double(successfulOperations) / Double(totalOperations)
    }
}

// MARK: - Search Functionality

/// Search criteria for file search operations
struct SearchCriteria {
    let query: String
    let searchPaths: [URL]
    let fileTypes: [String] // File extensions or UTI types
    let includeSubdirectories: Bool
    let includeDirectories: Bool
    let searchContent: Bool // Search inside file content
    let minSize: Int64?
    let maxSize: Int64?
    let modifiedAfter: Date?
    let modifiedBefore: Date?
    let maxResults: Int?
    let sortBy: SortOption
    
    init(
        query: String = "",
        searchPaths: [URL] = [],
        fileTypes: [String] = [],
        includeSubdirectories: Bool = true,
        includeDirectories: Bool = false,
        searchContent: Bool = false,
        minSize: Int64? = nil,
        maxSize: Int64? = nil,
        modifiedAfter: Date? = nil,
        modifiedBefore: Date? = nil,
        maxResults: Int? = nil,
        sortBy: SortOption = .name
    ) {
        self.query = query
        self.searchPaths = searchPaths
        self.fileTypes = fileTypes
        self.includeSubdirectories = includeSubdirectories
        self.includeDirectories = includeDirectories
        self.searchContent = searchContent
        self.minSize = minSize
        self.maxSize = maxSize
        self.modifiedAfter = modifiedAfter
        self.modifiedBefore = modifiedBefore
        self.maxResults = maxResults
        self.sortBy = sortBy
    }
}

/// Sort options for search results
enum SortOption {
    case name
    case dateModified
    case size
    case type
}

/// Search result containing found files
struct SearchResult {
    let query: String
    let totalFound: Int
    let files: [FileInfo]
    let searchTime: TimeInterval
    let searchPaths: [URL]
}

/// Information about a file
struct FileInfo: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let size: Int64
    let dateModified: Date
    let fileType: String
    let isDirectory: Bool
    let metadata: FileMetadata?
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    var fileExtension: String {
        url.pathExtension
    }
    
    init(url: URL, name: String, size: Int64, dateModified: Date, fileType: String, isDirectory: Bool, metadata: FileMetadata? = nil) {
        self.url = url
        self.name = name
        self.size = size
        self.dateModified = dateModified
        self.fileType = fileType
        self.isDirectory = isDirectory
        self.metadata = metadata
    }
}

// MARK: - File Organization

/// Organization strategies for file management
enum OrganizationStrategy {
    case byType
    case byDate
    case bySize
    case custom([OrganizationRule])
    
    var description: String {
        switch self {
        case .byType:
            return "file type"
        case .byDate:
            return "date"
        case .bySize:
            return "size"
        case .custom:
            return "custom rules"
        }
    }
}

/// Custom organization rule
struct OrganizationRule {
    let name: String
    let criteria: RuleCriteria
    let targetFolder: String
    let priority: Int // Higher priority rules are checked first
}

/// Criteria for organization rules
enum RuleCriteria {
    case nameContains(String)
    case fileExtension(String)
    case contentType(String)
    case sizeRange(min: Int, max: Int)
}

/// Result of organization operation
struct OrganizationResult {
    let strategy: OrganizationStrategy
    let processedFiles: Int
    let movedFiles: [URL]
    let createdFolders: [URL]
    let errors: [FileOperationError]
    let summary: String
}

// MARK: - File Categories

/// Categories for file type organization
enum FileCategory {
    case images
    case videos
    case audio
    case documents
    case archives
    case applications
    case other
    
    var folderName: String {
        switch self {
        case .images:
            return "Images"
        case .videos:
            return "Videos"
        case .audio:
            return "Audio"
        case .documents:
            return "Documents"
        case .archives:
            return "Archives"
        case .applications:
            return "Applications"
        case .other:
            return "Other"
        }
    }
}

/// Size categories for file organization
enum SizeCategory {
    case small  // < 1MB
    case medium // 1MB - 100MB
    case large  // > 100MB
    
    var folderName: String {
        switch self {
        case .small:
            return "Small Files"
        case .medium:
            return "Medium Files"
        case .large:
            return "Large Files"
        }
    }
}

// MARK: - Error Handling

/// File operation errors
enum FileOperationError: LocalizedError {
    case fileNotFound(String)
    case destinationNotFound(String)
    case directoryNotFound(String)
    case insufficientPermissions(String)
    case operationFailed(String)
    case operationCancelled
    case diskSpaceInsufficient
    case fileAlreadyExists(String)
    case invalidFileName(String)
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .destinationNotFound(let path):
            return "Destination not found: \(path)"
        case .directoryNotFound(let path):
            return "Directory not found: \(path)"
        case .insufficientPermissions(let message):
            return "Insufficient permissions: \(message)"
        case .operationFailed(let message):
            return "Operation failed: \(message)"
        case .operationCancelled:
            return "Operation was cancelled"
        case .diskSpaceInsufficient:
            return "Insufficient disk space"
        case .fileAlreadyExists(let path):
            return "File already exists: \(path)"
        case .invalidFileName(let name):
            return "Invalid file name: \(name)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .insufficientPermissions:
            return "Please check file permissions or run with appropriate privileges"
        case .diskSpaceInsufficient:
            return "Free up disk space and try again"
        case .fileAlreadyExists:
            return "Choose a different name or location"
        case .operationCancelled:
            return "The operation can be restarted if needed"
        default:
            return "Please verify the file path and try again"
        }
    }
}

// MARK: - File Metadata

/// Comprehensive file metadata information
struct FileMetadata {
    let basicInfo: BasicMetadata
    let imageInfo: ImageMetadata?
    let videoInfo: VideoMetadata?
    let audioInfo: AudioMetadata?
    let documentInfo: DocumentMetadata?
    let contentHash: String?
    
    init(basicInfo: BasicMetadata, imageInfo: ImageMetadata? = nil, videoInfo: VideoMetadata? = nil, audioInfo: AudioMetadata? = nil, documentInfo: DocumentMetadata? = nil, contentHash: String? = nil) {
        self.basicInfo = basicInfo
        self.imageInfo = imageInfo
        self.videoInfo = videoInfo
        self.audioInfo = audioInfo
        self.documentInfo = documentInfo
        self.contentHash = contentHash
    }
}

/// Basic metadata available for all files
struct BasicMetadata {
    let creationDate: Date?
    let modificationDate: Date
    let accessDate: Date?
    let fileSize: Int64
    let permissions: FilePermissions
    let contentType: String?
    let uniformTypeIdentifier: String?
}

/// File permissions information
struct FilePermissions {
    let isReadable: Bool
    let isWritable: Bool
    let isExecutable: Bool
    let posixPermissions: Int16?
}

/// Image-specific metadata (EXIF data)
struct ImageMetadata {
    let dimensions: CGSize?
    let colorSpace: String?
    let dpi: (x: Double, y: Double)?
    let cameraInfo: CameraInfo?
    let gpsInfo: GPSInfo?
    let orientation: ImageOrientation?
    let hasAlpha: Bool?
}

/// Camera information from EXIF
struct CameraInfo {
    let make: String?
    let model: String?
    let lensModel: String?
    let focalLength: Double?
    let aperture: Double?
    let shutterSpeed: String?
    let iso: Int?
    let flash: Bool?
    let dateTaken: Date?
}

/// GPS information from EXIF
struct GPSInfo {
    let latitude: Double
    let longitude: Double
    let altitude: Double?
    let timestamp: Date?
}

/// Image orientation
enum ImageOrientation: Int {
    case up = 1
    case down = 3
    case left = 6
    case right = 8
    case upMirrored = 2
    case downMirrored = 4
    case leftMirrored = 5
    case rightMirrored = 7
}

/// Video-specific metadata
struct VideoMetadata {
    let duration: TimeInterval?
    let dimensions: CGSize?
    let frameRate: Double?
    let bitRate: Int?
    let codec: String?
    let hasAudio: Bool?
    let creationDate: Date?
}

/// Audio-specific metadata
struct AudioMetadata {
    let duration: TimeInterval?
    let bitRate: Int?
    let sampleRate: Int?
    let channels: Int?
    let codec: String?
    let title: String?
    let artist: String?
    let album: String?
    let genre: String?
    let year: Int?
    let trackNumber: Int?
}

/// Document-specific metadata
struct DocumentMetadata {
    let title: String?
    let author: String?
    let subject: String?
    let keywords: [String]?
    let creator: String?
    let producer: String?
    let creationDate: Date?
    let modificationDate: Date?
    let pageCount: Int?
    let wordCount: Int?
    let characterCount: Int?
    let language: String?
}

// MARK: - Duplicate Detection

/// Duplicate file information
struct DuplicateGroup {
    let id = UUID()
    let files: [FileInfo]
    let duplicateType: DuplicateType
    let totalSize: Int64
    let potentialSavings: Int64
    
    var originalFile: FileInfo? {
        // Return the oldest file as the original
        files.min(by: { $0.dateModified < $1.dateModified })
    }
    
    var duplicateFiles: [FileInfo] {
        guard let original = originalFile else { return files }
        return files.filter { $0.id != original.id }
    }
}

/// Types of duplicate detection
enum DuplicateType {
    case exactMatch      // Same content hash
    case nameMatch       // Same filename
    case sizeMatch       // Same size
    case similarContent  // Similar but not identical
}

/// Duplicate detection result
struct DuplicateDetectionResult {
    let duplicateGroups: [DuplicateGroup]
    let totalDuplicates: Int
    let potentialSpaceSavings: Int64
    let scanTime: TimeInterval
    let scannedFiles: Int
    
    var formattedSavings: String {
        ByteCountFormatter.string(fromByteCount: potentialSpaceSavings, countStyle: .file)
    }
}

/// Smart organization based on metadata
struct SmartOrganizationRule {
    let name: String
    let condition: MetadataCondition
    let targetFolder: String
    let priority: Int
}

/// Conditions based on metadata
enum MetadataCondition {
    case imageWithGPS
    case imageFromCamera(String)  // Camera make/model
    case videoLongerThan(TimeInterval)
    case documentByAuthor(String)
    case audioByArtist(String)
    case fileOlderThan(Date)
    case fileLargerThan(Int64)
    case fileType(String)
    case hasKeywords([String])
}

// MARK: - Progress Tracking

/// Progress information for long-running operations
struct OperationProgress {
    let currentFile: String
    let filesProcessed: Int
    let totalFiles: Int
    let bytesProcessed: Int64
    let totalBytes: Int64
    let estimatedTimeRemaining: TimeInterval?
    
    var fileProgress: Double {
        guard totalFiles > 0 else { return 0 }
        return Double(filesProcessed) / Double(totalFiles)
    }
    
    var byteProgress: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(bytesProcessed) / Double(totalBytes)
    }
}