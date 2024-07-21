//
//  Extensions.swift
//  BWColorizer
//
//  Created by Sharan Thakur on 20/07/24.
//

import SwiftUI
import CoreML

/// To Make Sharing an ``UIImage`` easier using ``ShareLink``
struct Photo: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(exporting: \.image)
    }
    
    /// - Parameters:
    ///   - image: ``UIImage`` to share 
    ///   - caption: soemthing about the image
    init(image: UIImage, caption: String) {
        self.image = Image(uiImage: image)
        self.caption = caption
    }
    
    let image: Image
    let caption: String
}

/// Localized Error to use in app
struct AppError: LocalizedError {
    let message: String
    
    init(_ message: String) {
        self.message = message
    }
    
    var errorDescription: String? {
        message
    }
}

extension UIImage {
    ///  A method to resize the UIImage to 
    /// - Parameters:
    ///   - size: ``CGSize`` to be resized to
    ///   - isOpaque: flag to tell is the image is transparent, default false
    /// - Returns: the resized ``UIImage``
    func resized(to size: CGSize, isOpaque: Bool = false) -> UIImage {
        let canvas = size
        let format = self.imageRendererFormat
        format.opaque = isOpaque
        
        let resizedImage = UIGraphicsImageRenderer(size: canvas, format: format).image { (context: UIGraphicsImageRendererContext) in
            draw(in: CGRect(origin: .zero, size: canvas))
        }
        
        return resizedImage
    }
    
    ///  Converts the image to Lab Color Space
    /// - Returns: A tuple of ``MLShapedArray<Float32>`` if CGImage is not null else `nil`
    func toL() -> (MLShapedArray<Float32>, MLShapedArray<Float32>)? {
        guard let cgImage = self.cgImage else { return nil }
        
        let resizedImage = self.resized(to: CGSize(width: 512, height: 512))
        guard let resizedCGImage = resizedImage.cgImage else { return nil }
        
        let originalL = rgbToL(cgImage: cgImage)
        let resizedL = rgbToL(cgImage: resizedCGImage)
        
        return (originalL, resizedL)
    }
    
    ///  Method to convert `RGB` ``CGImage`` to Lab's LChannel array
    /// - Parameter cgImage: RGB Image
    /// - Returns: ``MLShapedArray<Float32>`` of LChannle
    private func rgbToL(cgImage: CGImage) -> MLShapedArray<Float32> {
        let width = cgImage.width
        let height = cgImage.height
        
        var bitmap = [UInt8](repeating: 0, count: width * height * 4)
        let context = CGContext(data: &bitmap,
                                width: width,
                                height: height,
                                bitsPerComponent: 8,
                                bytesPerRow: width * 4,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        
        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        var lChannel = [Float32](repeating: 0, count: width * height)
        
        for i in 0..<width*height {
            let r = Float32(bitmap[i*4]) / 255.0
            let g = Float32(bitmap[i*4+1]) / 255.0
            let b = Float32(bitmap[i*4+2]) / 255.0
            
            // Convert RGB to L using the formula from color.rgb2lab
            let l = 0.412453 * r + 0.357580 * g + 0.180423 * b
            lChannel[i] = (l > 0.008856) ? (116.0 * pow(l, 1.0/3.0) - 16.0) : (903.3 * l)
        }
        
        return MLShapedArray(scalars: lChannel, shape: [1, 1, height, width])
    }
}

/// Colorizer enum containing methods for postprocess business logic
enum Colorizer {
    ///  Postprocessing tensor back to ``UIImage``
    /// - Parameters:
    ///   - originalL: tensor of original image's LChannel
    ///   - resizedL: tensor of resized images's LChannel
    ///   - abOutput: tensor output of predicted abChannels from model
    /// - Returns: ``UIImage`` of final combined output
    public static func processColorizer(
        originalL: MLShapedArray<Float32>,
        resizedL: MLShapedArray<Float32>,
        abOutput: MLShapedArray<Float>
    ) -> UIImage? {
        
        let originalHeight = originalL.shape[2]
        let originalWidth = originalL.shape[3]
        let outputHeight = abOutput.shape[2]
        let outputWidth = abOutput.shape[3]
        
        let resizedAB: MLShapedArray<Float32>
        if originalHeight != outputHeight || originalWidth != outputWidth {
            print("Resizing AB channels from \(outputWidth)x\(outputHeight) to \(originalWidth)x\(originalHeight)")
            resizedAB = resizeAB(abOutput, toSize: [originalHeight, originalWidth])
        } else {
            resizedAB = abOutput
        }
        
        var labArray = [Float32](repeating: 0, count: originalHeight * originalWidth * 3)
        
        // Determine the range of the model output
        let aMin = resizedAB[0, 0].scalars.min()!
        let aMax = resizedAB[0, 0].scalars.max()!
        let bMin = resizedAB[0, 1].scalars.min()!
        let bMax = resizedAB[0, 1].scalars.max()!
        
        print("A range: \(aMin) to \(aMax)")
        print("B range: \(bMin) to \(bMax)")
        
        for y in 0..<originalHeight {
            for x in 0..<originalWidth {
                let index = y * originalWidth + x
                labArray[index * 3] = originalL[0, 0, y, x].scalar!
                labArray[index * 3 + 1] = resizedAB[0, 0, y, x].scalar!
                labArray[index * 3 + 2] = resizedAB[0, 1, y, x].scalar!
            }
        }
        
        return labToRGBImage(labArray: labArray, width: originalWidth, height: originalHeight)
    }


    ///  Internal method to resize predicted ab Channels tensor to orignal shape
    /// - Parameters:
    ///   - ab: predicted tensor from model
    ///   - size: Shape of original image
    /// - Returns: resized tensor
    private static func resizeAB(
        _ ab: MLShapedArray<Float32>,
        toSize size: [Int]
    ) -> MLShapedArray<Float32> {
        let srcHeight = ab.shape[2]
        let srcWidth = ab.shape[3]
        let dstHeight = size[0]
        let dstWidth = size[1]
        
        var resized = MLShapedArray<Float32>(repeating: 0, shape: [1, 2, dstHeight, dstWidth])
        
        let scaleY = Float(srcHeight - 1) / Float(dstHeight - 1)
        let scaleX = Float(srcWidth - 1) / Float(dstWidth - 1)
        
        for y in 0..<dstHeight {
            for x in 0..<dstWidth {
                let srcY = Float(y) * scaleY
                let srcX = Float(x) * scaleX
                
                let y1 = Int(floor(srcY))
                let y2 = min(y1 + 1, srcHeight - 1)
                let x1 = Int(floor(srcX))
                let x2 = min(x1 + 1, srcWidth - 1)
                
                let wy2 = srcY - Float(y1)
                let wy1 = 1.0 - wy2
                let wx2 = srcX - Float(x1)
                let wx1 = 1.0 - wx2
                
                for c in 0..<2 {  // 2 channels: A and B
                    let q11 = ab[0, c, y1, x1].scalar!
                    let q12 = ab[0, c, y1, x2].scalar!
                    let q21 = ab[0, c, y2, x1].scalar!
                    let q22 = ab[0, c, y2, x2].scalar!
                    
                    let interpolated = wy1 * (wx1 * q11 + wx2 * q12) + wy2 * (wx1 * q21 + wx2 * q22)
                    resized[0, c, y, x] = MLShapedArraySlice(converting: MLShapedArray<Float32>(scalar: interpolated))
                }
            }
        }
        
        return resized
    }

    ///  Internal Method to convert Lab to RGB Image tensor
    /// - Parameters:
    ///   - labArray: flat array of tensor values
    ///   - width: of the image
    ///   - height: of the image
    /// - Returns: ``UIImage`` if CGDataProvider is not null else `nil`
    private static func labToRGBImage(
        labArray: [Float32],
        width: Int,
        height: Int
    ) -> UIImage? {
        var rgbArray = [UInt8](repeating: 0, count: width * height * 4)
        
        for i in 0..<width*height {
            let l = labArray[i * 3]
            let a = labArray[i * 3 + 1]
            let b = labArray[i * 3 + 2]
            
            // LAB to XYZ
            let y = (l + 16) / 116
            let x = a / 500 + y
            let z = y - b / 200
            
            let xr = 0.95047 * ((x * x * x > 0.008856) ? x * x * x : (x - 16/116) / 7.787)
            let yr = 1.00000 * ((y * y * y > 0.008856) ? y * y * y : (y - 16/116) / 7.787)
            let zr = 1.08883 * ((z * z * z > 0.008856) ? z * z * z : (z - 16/116) / 7.787)
            
            // XYZ to RGB (sRGB D65)
            var r =  3.2404542 * xr - 1.5371385 * yr - 0.4985314 * zr
            var g = -0.9692660 * xr + 1.8760108 * yr + 0.0415560 * zr
            var blue =  0.0556434 * xr - 0.2040259 * yr + 1.0572252 * zr
            
            // Gamma correction
            r = (r > 0.0031308) ? (1.055 * pow(r, 1/2.4) - 0.055) : (12.92 * r)
            g = (g > 0.0031308) ? (1.055 * pow(g, 1/2.4) - 0.055) : (12.92 * g)
            blue = (blue > 0.0031308) ? (1.055 * pow(blue, 1/2.4) - 0.055) : (12.92 * blue)
            
            rgbArray[i * 4] = UInt8(max(0, min(255, r * 255)))
            rgbArray[i * 4 + 1] = UInt8(max(0, min(255, g * 255)))
            rgbArray[i * 4 + 2] = UInt8(max(0, min(255, blue * 255)))
            rgbArray[i * 4 + 3] = 255 // Alpha channel
        }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let provider = CGDataProvider(data: Data(bytes: rgbArray, count: rgbArray.count) as CFData) else { return nil }
        guard let cgImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ) else { return nil }
        
        return UIImage(cgImage: cgImage)
    }
}
