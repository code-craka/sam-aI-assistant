import Foundation
import CoreGraphics
import ImageIO
import AVFoundation
import PDFKit
import UniformTypeIdentifiers
import CryptoKit
import AppKit

/// Service for extracting metadata from various file types
@MainActor
class MetadataExtractionService: ObservableObject {
    
    // MARK: - Properties
    private let fileManager = FileManager.default
    
    // MARK: - Public Methods
    
    /// Extract comprehensive metadata from a file
    func extractMetadata(from url: URL) async throws -> FileMetadata {
        let basicInfo = try await extractBasicMetadata(from: url)
        let contentHash = try await calculateContentHash(for: url)
        
        // Determine file type and extract specific metadata
        let contentType = try url.resourceValues(forKeys: [.contentTypeKey]).contentType
        
        var imageInfo: ImageMetadata?
        var videoInfo: VideoMetadata?
        var audioInfo: AudioMetadata?
        var documentInfo: DocumentMetadata?
        
        if let contentType = contentType {
            if contentType.conforms(to: .image) {
                imageInfo = try await extractImageMetadata(from: url)
            } else if contentType.conforms(to: .movie) || contentType.conforms(to: .video) {
                videoInfo = try await extractVideoMetadata(from: url)
            } else if contentType.conforms(to: .audio) {
                audioInfo = try await extractAudioMetadata(from: url)
            } else if contentType.conforms(to: .pdf) || contentType.conforms(to: .text) {
                documentInfo = try await extractDocumentMetadata(from: url)
            }
        }
        
        return FileMetadata(
            basicInfo: basicInfo,
            imageInfo: imageInfo,
            videoInfo: videoInfo,
            audioInfo: audioInfo,
            documentInfo: documentInfo,
            contentHash: contentHash
        )
    }
    
    /// Extract metadata from multiple files with progress tracking
    func extractMetadataFromFiles(_ urls: [URL], progressHandler: @escaping (Int, Int) -> Void) async throws -> [URL: FileMetadata] {
        var results: [URL: FileMetadata] = [:]
        
        for (index, url) in urls.enumerated() {
            do {
                let metadata = try await extractMetadata(from: url)
                results[url] = metadata
                progressHandler(index + 1, urls.count)
            } catch {
                // Log error but continue with other files
                print("Failed to extract metadata from \(url.lastPathComponent): \(error)")
            }
        }
        
        return results
    }
    
    // MARK: - Basic Metadata
    
    private func extractBasicMetadata(from url: URL) async throws -> BasicMetadata {
        let resourceValues = try url.resourceValues(forKeys: [
            .creationDateKey,
            .contentModificationDateKey,
            .contentAccessDateKey,
            .fileSizeKey,
            .isReadableKey,
            .isWritableKey,
            .isExecutableKey,
            .posixPermissionsKey,
            .contentTypeKey,
            .typeIdentifierKey
        ])
        
        let permissions = FilePermissions(
            isReadable: resourceValues.isReadable ?? false,
            isWritable: resourceValues.isWritable ?? false,
            isExecutable: resourceValues.isExecutable ?? false,
            posixPermissions: resourceValues.posixPermissions
        )
        
        return BasicMetadata(
            creationDate: resourceValues.creationDate,
            modificationDate: resourceValues.contentModificationDate ?? Date(),
            accessDate: resourceValues.contentAccessDate,
            fileSize: Int64(resourceValues.fileSize ?? 0),
            permissions: permissions,
            contentType: resourceValues.contentType?.description,
            uniformTypeIdentifier: resourceValues.typeIdentifier
        )
    }
    
    // MARK: - Image Metadata (EXIF)
    
    private func extractImageMetadata(from url: URL) async throws -> ImageMetadata {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw MetadataExtractionError.unsupportedFormat
        }
        
        guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            throw MetadataExtractionError.metadataNotFound
        }
        
        // Extract basic image properties
        let pixelWidth = properties[kCGImagePropertyPixelWidth as String] as? CGFloat
        let pixelHeight = properties[kCGImagePropertyPixelHeight as String] as? CGFloat
        let dimensions = (pixelWidth != nil && pixelHeight != nil) ? CGSize(width: pixelWidth!, height: pixelHeight!) : nil
        
        let colorModel = properties[kCGImagePropertyColorModel as String] as? String
        let hasAlpha = properties[kCGImagePropertyHasAlpha as String] as? Bool
        
        // Extract DPI information
        var dpi: (x: Double, y: Double)?
        if let dpiX = properties[kCGImagePropertyDPIWidth as String] as? Double,
           let dpiY = properties[kCGImagePropertyDPIHeight as String] as? Double {
            dpi = (x: dpiX, y: dpiY)
        }
        
        // Extract EXIF data
        var cameraInfo: CameraInfo?
        var gpsInfo: GPSInfo?
        var orientation: ImageOrientation?
        
        if let exifDict = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            cameraInfo = extractCameraInfo(from: exifDict, tiffDict: properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any])
        }
        
        if let gpsDict = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any] {
            gpsInfo = extractGPSInfo(from: gpsDict)
        }
        
        if let orientationValue = properties[kCGImagePropertyOrientation as String] as? Int {
            orientation = ImageOrientation(rawValue: orientationValue)
        }
        
        return ImageMetadata(
            dimensions: dimensions,
            colorSpace: colorModel,
            dpi: dpi,
            cameraInfo: cameraInfo,
            gpsInfo: gpsInfo,
            orientation: orientation,
            hasAlpha: hasAlpha
        )
    }
    
    private func extractCameraInfo(from exifDict: [String: Any], tiffDict: [String: Any]?) -> CameraInfo {
        let make = tiffDict?[kCGImagePropertyTIFFMake as String] as? String
        let model = tiffDict?[kCGImagePropertyTIFFModel as String] as? String
        let lensModel = exifDict[kCGImagePropertyExifLensModel as String] as? String
        
        let focalLength = exifDict[kCGImagePropertyExifFocalLength as String] as? Double
        let aperture = exifDict[kCGImagePropertyExifFNumber as String] as? Double
        let shutterSpeed = exifDict[kCGImagePropertyExifExposureTime as String] as? String
        let iso = exifDict[kCGImagePropertyExifISOSpeedRatings as String] as? Int
        let flash = exifDict[kCGImagePropertyExifFlash as String] as? Bool
        
        var dateTaken: Date?
        if let dateString = exifDict[kCGImagePropertyExifDateTimeOriginal as String] as? String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
            dateTaken = formatter.date(from: dateString)
        }
        
        return CameraInfo(
            make: make,
            model: model,
            lensModel: lensModel,
            focalLength: focalLength,
            aperture: aperture,
            shutterSpeed: shutterSpeed,
            iso: iso,
            flash: flash,
            dateTaken: dateTaken
        )
    }
    
    private func extractGPSInfo(from gpsDict: [String: Any]) -> GPSInfo? {
        guard let latitudeRef = gpsDict[kCGImagePropertyGPSLatitudeRef as String] as? String,
              let latitude = gpsDict[kCGImagePropertyGPSLatitude as String] as? Double,
              let longitudeRef = gpsDict[kCGImagePropertyGPSLongitudeRef as String] as? String,
              let longitude = gpsDict[kCGImagePropertyGPSLongitude as String] as? Double else {
            return nil
        }
        
        let finalLatitude = latitudeRef == "S" ? -latitude : latitude
        let finalLongitude = longitudeRef == "W" ? -longitude : longitude
        
        let altitude = gpsDict[kCGImagePropertyGPSAltitude as String] as? Double
        
        var timestamp: Date?
        if let dateString = gpsDict[kCGImagePropertyGPSDateStamp as String] as? String,
           let timeString = gpsDict[kCGImagePropertyGPSTimeStamp as String] as? String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
            timestamp = formatter.date(from: "\(dateString) \(timeString)")
        }
        
        return GPSInfo(
            latitude: finalLatitude,
            longitude: finalLongitude,
            altitude: altitude,
            timestamp: timestamp
        )
    }
    
    // MARK: - Video Metadata
    
    private func extractVideoMetadata(from url: URL) async throws -> VideoMetadata {
        let asset = AVAsset(url: url)
        
        // Load metadata asynchronously
        let duration = try await asset.load(.duration)
        let tracks = try await asset.load(.tracks)
        
        var dimensions: CGSize?
        var frameRate: Double?
        var bitRate: Int?
        var codec: String?
        var hasAudio = false
        
        // Find video track
        if let videoTrack = tracks.first(where: { $0.mediaType == .video }) {
            let naturalSize = try await videoTrack.load(.naturalSize)
            dimensions = naturalSize
            
            let nominalFrameRate = try await videoTrack.load(.nominalFrameRate)
            frameRate = Double(nominalFrameRate)
            
            let estimatedDataRate = try await videoTrack.load(.estimatedDataRate)
            bitRate = Int(estimatedDataRate)
            
            // Get codec information
            let formatDescriptions = try await videoTrack.load(.formatDescriptions)
            if let formatDescription = formatDescriptions.first {
                let codecType = CMFormatDescriptionGetMediaSubType(formatDescription)
                codec = String(describing: codecType)
            }
        }
        
        // Check for audio track
        hasAudio = tracks.contains { $0.mediaType == .audio }
        
        // Get creation date from metadata
        var creationDate: Date?
        let metadata = try await asset.load(.metadata)
        for item in metadata {
            if let key = item.commonKey, key == .commonKeyCreationDate {
                creationDate = try await item.load(.dateValue)
                break
            }
        }
        
        return VideoMetadata(
            duration: duration.seconds,
            dimensions: dimensions,
            frameRate: frameRate,
            bitRate: bitRate,
            codec: codec,
            hasAudio: hasAudio,
            creationDate: creationDate
        )
    }
    
    // MARK: - Audio Metadata
    
    private func extractAudioMetadata(from url: URL) async throws -> AudioMetadata {
        let asset = AVAsset(url: url)
        
        let duration = try await asset.load(.duration)
        let tracks = try await asset.load(.tracks)
        
        var bitRate: Int?
        var sampleRate: Int?
        var channels: Int?
        var codec: String?
        
        // Find audio track
        if let audioTrack = tracks.first(where: { $0.mediaType == .audio }) {
            let estimatedDataRate = try await audioTrack.load(.estimatedDataRate)
            bitRate = Int(estimatedDataRate)
            
            // Get format descriptions for sample rate and channels
            let formatDescriptions = try await audioTrack.load(.formatDescriptions)
            if let formatDescription = formatDescriptions.first {
                let audioStreamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)
                if let asbd = audioStreamBasicDescription {
                    sampleRate = Int(asbd.pointee.mSampleRate)
                    channels = Int(asbd.pointee.mChannelsPerFrame)
                }
                
                let codecType = CMFormatDescriptionGetMediaSubType(formatDescription)
                codec = String(describing: codecType)
            }
        }
        
        // Extract metadata tags
        let metadata = try await asset.load(.metadata)
        var title: String?
        var artist: String?
        var album: String?
        var genre: String?
        var year: Int?
        var trackNumber: Int?
        
        for item in metadata {
            guard let key = item.commonKey else { continue }
            
            switch key {
            case .commonKeyTitle:
                title = try await item.load(.stringValue)
            case .commonKeyArtist:
                artist = try await item.load(.stringValue)
            case .commonKeyAlbumName:
                album = try await item.load(.stringValue)
            case .commonKeyType:
                genre = try await item.load(.stringValue)
            case .commonKeyCreationDate:
                if let dateString = try await item.load(.stringValue) {
                    year = Int(String(dateString.prefix(4)))
                }
            default:
                break
            }
        }
        
        return AudioMetadata(
            duration: duration.seconds,
            bitRate: bitRate,
            sampleRate: sampleRate,
            channels: channels,
            codec: codec,
            title: title,
            artist: artist,
            album: album,
            genre: genre,
            year: year,
            trackNumber: trackNumber
        )
    }
    
    // MARK: - Document Metadata
    
    private func extractDocumentMetadata(from url: URL) async throws -> DocumentMetadata {
        let pathExtension = url.pathExtension.lowercased()
        
        switch pathExtension {
        case "pdf":
            return try extractPDFMetadata(from: url)
        case "txt", "md", "rtf":
            return try extractTextMetadata(from: url)
        default:
            // Try to extract basic text properties
            return try extractTextMetadata(from: url)
        }
    }
    
    private func extractPDFMetadata(from url: URL) throws -> DocumentMetadata {
        guard let pdfDocument = PDFDocument(url: url) else {
            throw MetadataExtractionError.unsupportedFormat
        }
        
        let attributes = pdfDocument.documentAttributes
        
        let title = attributes?[PDFDocumentAttribute.titleAttribute] as? String
        let author = attributes?[PDFDocumentAttribute.authorAttribute] as? String
        let subject = attributes?[PDFDocumentAttribute.subjectAttribute] as? String
        let creator = attributes?[PDFDocumentAttribute.creatorAttribute] as? String
        let producer = attributes?[PDFDocumentAttribute.producerAttribute] as? String
        let creationDate = attributes?[PDFDocumentAttribute.creationDateAttribute] as? Date
        let modificationDate = attributes?[PDFDocumentAttribute.modificationDateAttribute] as? Date
        
        let keywordsString = attributes?[PDFDocumentAttribute.keywordsAttribute] as? String
        let keywords = keywordsString?.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        
        let pageCount = pdfDocument.pageCount
        
        return DocumentMetadata(
            title: title,
            author: author,
            subject: subject,
            keywords: keywords,
            creator: creator,
            producer: producer,
            creationDate: creationDate,
            modificationDate: modificationDate,
            pageCount: pageCount,
            wordCount: nil,
            characterCount: nil,
            language: nil
        )
    }
    
    private func extractTextMetadata(from url: URL) throws -> DocumentMetadata {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            throw MetadataExtractionError.unsupportedFormat
        }
        
        let wordCount = content.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
        let characterCount = content.count
        
        // Try to detect language
        let language = NSLinguisticTagger.dominantLanguage(for: content)
        
        return DocumentMetadata(
            title: url.deletingPathExtension().lastPathComponent,
            author: nil,
            subject: nil,
            keywords: nil,
            creator: nil,
            producer: nil,
            creationDate: nil,
            modificationDate: nil,
            pageCount: nil,
            wordCount: wordCount,
            characterCount: characterCount,
            language: language
        )
    }
    
    // MARK: - Content Hash Calculation
    
    private func calculateContentHash(for url: URL) async throws -> String {
        let data = try Data(contentsOf: url)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Metadata Extraction Errors

enum MetadataExtractionError: LocalizedError {
    case unsupportedFormat
    case metadataNotFound
    case fileNotAccessible
    case corruptedFile
    
    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return "Unsupported file format for metadata extraction"
        case .metadataNotFound:
            return "No metadata found in file"
        case .fileNotAccessible:
            return "File is not accessible for metadata extraction"
        case .corruptedFile:
            return "File appears to be corrupted"
        }
    }
}