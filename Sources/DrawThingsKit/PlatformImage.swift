//
//  PlatformImage.swift
//  DrawThingsKit
//
//  Cross-platform image type abstraction for macOS and iOS.
//

import Foundation
import CoreGraphics
import DrawThingsClient

#if os(macOS)
import AppKit
public typealias PlatformImage = NSImage
#else
import UIKit
public typealias PlatformImage = UIImage
#endif

// MARK: - Cross-Platform Image Extensions

extension PlatformImage {
    /// Create a platform image from Data
    public static func fromData(_ data: Data) -> PlatformImage? {
        #if os(macOS)
        return NSImage(data: data)
        #else
        return UIImage(data: data)
        #endif
    }

    #if os(macOS)
    /// Convert to PNG data
    public func pngData() -> Data? {
        guard let tiffData = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }
    #endif
    // Note: On iOS, UIImage already has pngData() built-in, so no extension needed

    /// Get the image dimensions
    public var pixelWidth: Int {
        #if os(macOS)
        guard let rep = representations.first else { return 0 }
        return rep.pixelsWide
        #else
        return Int(size.width * scale)
        #endif
    }

    public var pixelHeight: Int {
        #if os(macOS)
        guard let rep = representations.first else { return 0 }
        return rep.pixelsHigh
        #else
        return Int(size.height * scale)
        #endif
    }

    /// Get CGImage representation
    public var cgImageRepresentation: CGImage? {
        #if os(macOS)
        return cgImage(forProposedRect: nil, context: nil, hints: nil)
        #else
        return cgImage
        #endif
    }
}

// MARK: - Cross-Platform DTTensor Conversion

/// Cross-platform image helpers for DTTensor conversion
public struct PlatformImageHelpers {

    /// Convert a platform image to DTTensor format for Draw Things
    /// - Parameters:
    ///   - image: The source image
    ///   - forceRGB: If true, always output 3 channels (RGB) even if image has transparency
    /// - Returns: DTTensor data
    public static func imageToDTTensor(_ image: PlatformImage, forceRGB: Bool = false) throws -> Data {
        guard let cgImage = image.cgImageRepresentation else {
            throw PlatformImageError.invalidImage
        }

        let width = cgImage.width
        let height = cgImage.height

        // Create RGBA bitmap context
        let bytesPerRow = width * 4
        var pixelData = [UInt8](repeating: 0, count: height * bytesPerRow)

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: &pixelData,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
              ) else {
            throw PlatformImageError.conversionFailed
        }

        // Draw the image into our buffer (RGBA format)
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Check if image has any transparency
        var hasTransparency = false
        if !forceRGB {
            outerLoop: for y in 0..<height {
                for x in 0..<width {
                    let pixelIndex = y * bytesPerRow + x * 4
                    let alpha = pixelData[pixelIndex + 3] // Alpha is last in RGBA
                    if alpha < 255 {
                        hasTransparency = true
                        break outerLoop
                    }
                }
            }
        }

        let channels = (hasTransparency && !forceRGB) ? 4 : 3

        // DTTensor format constants
        let CCV_TENSOR_CPU_MEMORY: UInt32 = 0x1
        let CCV_TENSOR_FORMAT_NHWC: UInt32 = 0x02
        let CCV_16F: UInt32 = 0x20000

        // Create header (17 uint32 values = 68 bytes)
        var header = [UInt32](repeating: 0, count: 17)
        header[0] = 0  // No compression
        header[1] = CCV_TENSOR_CPU_MEMORY
        header[2] = CCV_TENSOR_FORMAT_NHWC
        header[3] = CCV_16F
        header[4] = 0
        header[5] = 1  // N dimension
        header[6] = UInt32(height)
        header[7] = UInt32(width)
        header[8] = UInt32(channels)

        var tensorData = Data(count: 68 + width * height * channels * 2)

        // Write header
        tensorData.withUnsafeMutableBytes { (ptr: UnsafeMutableRawBufferPointer) in
            let uint32Ptr = ptr.baseAddress!.assumingMemoryBound(to: UInt32.self)
            for i in 0..<9 {
                uint32Ptr[i] = header[i]
            }
        }

        // Convert RGBA pixel data to float16 tensor data in range [-1, 1]
        tensorData.withUnsafeMutableBytes { (outPtr: UnsafeMutableRawBufferPointer) in
            let tensorPixelPtr = outPtr.baseAddress!.advanced(by: 68)

            for y in 0..<height {
                for x in 0..<width {
                    let rgbaIndex = y * bytesPerRow + x * 4

                    for c in 0..<channels {
                        let uint8Value = pixelData[rgbaIndex + c]
                        let floatValue = (Float(uint8Value) / 255.0 * 2.0) - 1.0
                        let float16Value = Float16(floatValue)

                        let byteOffset = (y * width + x) * channels * 2 + c * 2
                        let bitPattern = float16Value.bitPattern
                        tensorPixelPtr.storeBytes(of: UInt8(bitPattern & 0xFF), toByteOffset: byteOffset, as: UInt8.self)
                        tensorPixelPtr.storeBytes(of: UInt8((bitPattern >> 8) & 0xFF), toByteOffset: byteOffset + 1, as: UInt8.self)
                    }
                }
            }
        }

        return tensorData
    }

    /// Convert DTTensor data to a platform image
    /// - Parameters:
    ///   - tensorData: The DTTensor data from Draw Things
    ///   - modelFamily: Optional model family for correct latent-to-RGB conversion (defaults to .flux for 16-channel)
    /// - Returns: A platform image
    ///
    /// Different model architectures use different latent space representations. For accurate preview colors,
    /// pass the appropriate model family. Detect automatically using:
    /// ```swift
    /// let family = LatentModelFamily.detect(from: modelName)
    /// let image = try PlatformImageHelpers.dtTensorToImage(tensorData, modelFamily: family)
    /// ```
    public static func dtTensorToImage(_ tensorData: Data, modelFamily: LatentModelFamily? = nil) throws -> PlatformImage {
        // Delegate to DrawThingsClient's implementation which has all model-specific coefficients
        do {
            return try ImageHelpers.dtTensorToImage(tensorData, modelFamily: modelFamily)
        } catch let error as ImageError {
            switch error {
            case .invalidData:
                throw PlatformImageError.invalidData
            case .compressionNotSupported:
                throw PlatformImageError.compressionNotSupported
            case .conversionFailed:
                throw PlatformImageError.conversionFailed
            default:
                throw PlatformImageError.conversionFailed
            }
        } catch {
            throw PlatformImageError.conversionFailed
        }
    }

    /// Create a platform image from raw RGB data
    private static func createImageFromRGBData(_ rgbData: Data, width: Int, height: Int) throws -> PlatformImage {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            throw PlatformImageError.conversionFailed
        }

        #if os(macOS)
        // macOS: Create CGImage directly from RGB data
        let bitsPerComponent = 8
        let bitsPerPixel = 24
        let bytesPerRow = width * 3
        let cfData = rgbData as CFData

        guard let provider = CGDataProvider(data: cfData),
              let cgImage = CGImage(
                width: width,
                height: height,
                bitsPerComponent: bitsPerComponent,
                bitsPerPixel: bitsPerPixel,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
              ) else {
            throw PlatformImageError.conversionFailed
        }
        return NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
        #else
        // iOS: Convert RGB to RGBA since iOS handles RGBA better
        // Add alpha channel (fully opaque) to the RGB data
        var rgbaData = Data(capacity: width * height * 4)
        for i in 0..<(width * height) {
            let rgbOffset = i * 3
            rgbaData.append(rgbData[rgbOffset])     // R
            rgbaData.append(rgbData[rgbOffset + 1]) // G
            rgbaData.append(rgbData[rgbOffset + 2]) // B
            rgbaData.append(255)                     // A (fully opaque)
        }

        let bitsPerComponent = 8
        let bitsPerPixel = 32
        let bytesPerRow = width * 4
        let cfData = rgbaData as CFData

        guard let provider = CGDataProvider(data: cfData),
              let cgImage = CGImage(
                width: width,
                height: height,
                bitsPerComponent: bitsPerComponent,
                bitsPerPixel: bitsPerPixel,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
              ) else {
            throw PlatformImageError.conversionFailed
        }
        return UIImage(cgImage: cgImage, scale: 1.0, orientation: .up)
        #endif
    }
}

// MARK: - Platform Image Errors

public enum PlatformImageError: Error, LocalizedError {
    case invalidImage
    case invalidData
    case conversionFailed
    case compressionNotSupported

    public var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Invalid image format or corrupted image"
        case .invalidData:
            return "Invalid image data"
        case .conversionFailed:
            return "Failed to convert image"
        case .compressionNotSupported:
            return "Compressed image format not supported. Disable compression in Draw Things server settings."
        }
    }
}
