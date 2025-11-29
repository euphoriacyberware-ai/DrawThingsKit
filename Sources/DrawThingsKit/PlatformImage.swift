//
//  PlatformImage.swift
//  DrawThingsKit
//
//  Cross-platform image type abstraction for macOS and iOS.
//

import Foundation
import CoreGraphics

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
    /// - Parameter tensorData: The DTTensor data from Draw Things
    /// - Returns: A platform image
    public static func dtTensorToImage(_ tensorData: Data) throws -> PlatformImage {
        guard tensorData.count >= 68 else {
            throw PlatformImageError.invalidData
        }

        // Read header
        var header = [UInt32](repeating: 0, count: 17)
        tensorData.prefix(68).withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
            let uint32Ptr = ptr.bindMemory(to: UInt32.self)
            for i in 0..<17 {
                header[i] = uint32Ptr[i]
            }
        }

        let compressionFlag = header[0]
        let height = Int(header[6])
        let width = Int(header[7])
        let channels = Int(header[8])

        if compressionFlag == 1012247 {
            throw PlatformImageError.compressionNotSupported
        }

        guard channels == 3 || channels == 4 || channels == 16 else {
            throw PlatformImageError.conversionFailed
        }

        let pixelDataOffset = 68
        let expectedDataSize = pixelDataOffset + (width * height * channels * 2)

        guard tensorData.count >= expectedDataSize else {
            throw PlatformImageError.invalidData
        }

        // Output RGB data
        var rgbData = Data(count: width * height * 3)

        tensorData.withUnsafeBytes { (rawPtr: UnsafeRawBufferPointer) in
            let basePtr = rawPtr.baseAddress!.advanced(by: pixelDataOffset)
            let float16Ptr = basePtr.assumingMemoryBound(to: UInt16.self)

            rgbData.withUnsafeMutableBytes { (outPtr: UnsafeMutableRawBufferPointer) in
                let uint8Ptr = outPtr.baseAddress!.assumingMemoryBound(to: UInt8.self)

                if channels == 16 {
                    // 16-channel latent space to RGB (Flux coefficients)
                    for i in 0..<(width * height) {
                        let v0 = Float(Float16(bitPattern: float16Ptr[i * 16 + 0]))
                        let v1 = Float(Float16(bitPattern: float16Ptr[i * 16 + 1]))
                        let v2 = Float(Float16(bitPattern: float16Ptr[i * 16 + 2]))
                        let v3 = Float(Float16(bitPattern: float16Ptr[i * 16 + 3]))
                        let v4 = Float(Float16(bitPattern: float16Ptr[i * 16 + 4]))
                        let v5 = Float(Float16(bitPattern: float16Ptr[i * 16 + 5]))
                        let v6 = Float(Float16(bitPattern: float16Ptr[i * 16 + 6]))
                        let v7 = Float(Float16(bitPattern: float16Ptr[i * 16 + 7]))
                        let v8 = Float(Float16(bitPattern: float16Ptr[i * 16 + 8]))
                        let v9 = Float(Float16(bitPattern: float16Ptr[i * 16 + 9]))
                        let v10 = Float(Float16(bitPattern: float16Ptr[i * 16 + 10]))
                        let v11 = Float(Float16(bitPattern: float16Ptr[i * 16 + 11]))
                        let v12 = Float(Float16(bitPattern: float16Ptr[i * 16 + 12]))
                        let v13 = Float(Float16(bitPattern: float16Ptr[i * 16 + 13]))
                        let v14 = Float(Float16(bitPattern: float16Ptr[i * 16 + 14]))
                        let v15 = Float(Float16(bitPattern: float16Ptr[i * 16 + 15]))

                        var rVal: Float = -0.0346 * v0 + 0.0034 * v1 + 0.0275 * v2 - 0.0174 * v3
                        rVal += 0.0859 * v4 + 0.0004 * v5 + 0.0405 * v6 - 0.0236 * v7
                        rVal += -0.0245 * v8 + 0.1008 * v9 - 0.0515 * v10 + 0.0428 * v11
                        rVal += 0.0817 * v12 - 0.1264 * v13 - 0.0280 * v14 - 0.1262 * v15 - 0.0329
                        let r = rVal * 127.5 + 127.5

                        var gVal: Float = 0.0244 * v0 + 0.0210 * v1 - 0.0668 * v2 + 0.0160 * v3
                        gVal += 0.0721 * v4 + 0.0383 * v5 + 0.0861 * v6 - 0.0185 * v7
                        gVal += 0.0250 * v8 + 0.0755 * v9 + 0.0201 * v10 - 0.0012 * v11
                        gVal += 0.0765 * v12 - 0.0522 * v13 - 0.0881 * v14 - 0.0982 * v15 - 0.0718
                        let g = gVal * 127.5 + 127.5

                        var bVal: Float = 0.0681 * v0 + 0.0687 * v1 - 0.0433 * v2 + 0.0617 * v3
                        bVal += 0.0329 * v4 + 0.0115 * v5 + 0.0915 * v6 - 0.0259 * v7
                        bVal += 0.1180 * v8 - 0.0421 * v9 + 0.0011 * v10 - 0.0036 * v11
                        bVal += 0.0749 * v12 - 0.1103 * v13 - 0.0499 * v14 - 0.0778 * v15 - 0.0851
                        let b = bVal * 127.5 + 127.5

                        uint8Ptr[i * 3 + 0] = UInt8(clamping: Int(r.isFinite ? r : 0))
                        uint8Ptr[i * 3 + 1] = UInt8(clamping: Int(g.isFinite ? g : 0))
                        uint8Ptr[i * 3 + 2] = UInt8(clamping: Int(b.isFinite ? b : 0))
                    }
                } else if channels == 4 {
                    // 4-channel latent space to RGB (SDXL coefficients)
                    for i in 0..<(width * height) {
                        let v0 = Float(Float16(bitPattern: float16Ptr[i * 4 + 0]))
                        let v1 = Float(Float16(bitPattern: float16Ptr[i * 4 + 1]))
                        let v2 = Float(Float16(bitPattern: float16Ptr[i * 4 + 2]))
                        let v3 = Float(Float16(bitPattern: float16Ptr[i * 4 + 3]))

                        let r = 47.195 * v0 - 29.114 * v1 + 11.883 * v2 - 38.063 * v3 + 141.64
                        let g = 53.237 * v0 - 1.4623 * v1 + 12.991 * v2 - 28.043 * v3 + 127.46
                        let b = 58.182 * v0 + 4.3734 * v1 - 3.3735 * v2 - 26.722 * v3 + 114.5

                        uint8Ptr[i * 3 + 0] = UInt8(clamping: Int(r))
                        uint8Ptr[i * 3 + 1] = UInt8(clamping: Int(g))
                        uint8Ptr[i * 3 + 2] = UInt8(clamping: Int(b))
                    }
                } else {
                    // 3-channel RGB: Convert from [-1, 1] to [0, 255]
                    let pixelCount = width * height * channels
                    for i in 0..<pixelCount {
                        let float16Bits = float16Ptr[i]
                        let float16Value = Float16(bitPattern: float16Bits)
                        let floatValue = Float(float16Value)
                        let uint8Value = UInt8(clamping: Int(floatValue.isFinite ? (floatValue + 1.0) * 127.5 : 127.5))
                        uint8Ptr[i] = uint8Value
                    }
                }
            }
        }

        // Create platform image from RGB data
        return try createImageFromRGBData(rgbData, width: width, height: height)
    }

    /// Create a platform image from raw RGB data
    private static func createImageFromRGBData(_ rgbData: Data, width: Int, height: Int) throws -> PlatformImage {
        let bitsPerComponent = 8
        let bitsPerPixel = 24
        let bytesPerRow = width * 3

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            throw PlatformImageError.conversionFailed
        }

        // Use CFData to ensure the data stays alive for the lifetime of the CGImage
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

        #if os(macOS)
        return NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
        #else
        // On iOS, we need to render the CGImage to a new context to ensure
        // the pixel data is copied and doesn't depend on the original data provider
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        return renderer.image { context in
            context.cgContext.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
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
