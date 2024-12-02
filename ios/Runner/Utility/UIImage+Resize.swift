// UIImage+Resize.m
// Created by Trevor Harmon on 8/5/09.
// Free for personal or commercial use, with or without modification.
// No warranty is expressed or implied.

import UIKit

extension UIImage {
    
    // Returns a copy of this image that is cropped to the given bounds.
    // The bounds will be adjusted using CGRectIntegral.
    // This method ignores the image's imageOrientation setting.
    func croppedImage(_ bounds: CGRect) -> UIImage {
        let imageRef: CGImage = (self.cgImage)!.cropping(to: bounds)!
        return UIImage(cgImage: imageRef)
    }
    
    // Returns a rescaled copy of the image, taking into account its orientation
    // The image will be scaled disproportionately if necessary to fit the bounds specified by the parameter
    func resizedImage(_ newSize: CGSize, interpolationQuality quality: CGInterpolationQuality) -> UIImage {
        var drawTransposed: Bool
        
        switch(self.imageOrientation) {
        case .left, .leftMirrored, .right, .rightMirrored:
            drawTransposed = true
        default:
            drawTransposed = false
        }
        
        return self.resizedImage(
            newSize,
            transform: self.transformForOrientation(newSize),
            drawTransposed: drawTransposed,
            interpolationQuality: quality
        )
    }
    
    func resizedImageNoEnlarge(_ contentMode: UIView.ContentMode, bounds: CGSize, interpolationQuality: CGInterpolationQuality = CGInterpolationQuality.default) -> UIImage {
        let horizontalRatio = bounds.width / self.size.width
        let verticalRatio = bounds.height / self.size.height
        var ratio: CGFloat = 1
        
        switch(contentMode) {
        case .scaleAspectFill:
            ratio = max(horizontalRatio, verticalRatio)
        case .scaleAspectFit:
            ratio = min(horizontalRatio, verticalRatio)
        default:
            fatalError("Unsupported content mode \(contentMode)")
        }
        
        if ratio >= 1.0 {
            ratio = 1.0
        }
        
        let newSize: CGSize = CGSize(width: self.size.width * ratio, height: self.size.height * ratio)
        return self.resizedImage(newSize, interpolationQuality: interpolationQuality)
    }
    
    func resizedImageWithContentMode(_ contentMode: UIView.ContentMode, bounds: CGSize, interpolationQuality quality: CGInterpolationQuality) -> UIImage {
        let horizontalRatio = bounds.width / self.size.width
        let verticalRatio = bounds.height / self.size.height
        var ratio: CGFloat = 1
        
        switch(contentMode) {
        case .scaleAspectFill:
            ratio = max(horizontalRatio, verticalRatio)
        case .scaleAspectFit:
            ratio = min(horizontalRatio, verticalRatio)
        default:
            fatalError("Unsupported content mode \(contentMode)")
        }
        
        let newSize: CGSize = CGSize(width: self.size.width * ratio, height: self.size.height * ratio)
        return self.resizedImage(newSize, interpolationQuality: quality)
    }
    
    fileprivate func resizedImage(_ newSize: CGSize, transform: CGAffineTransform, drawTransposed transpose: Bool, interpolationQuality quality: CGInterpolationQuality) -> UIImage {
        let imageRef: CGImage = self.cgImage!
        let scale = max(1, scale)
        let newRect = CGRect(x: 0, y: 0, width: newSize.width * scale, height: newSize.height * scale).integral
        let transposedRect = CGRect(x: 0, y: 0, width: newRect.size.height, height: newRect.size.width)
     
        // Fix for a colorspace / transparency issue that affects some types of
        // images. See here: http://vocaro.com/trevor/blog/2009/10/12/resize-a-uiimage-the-right-way/comment-page-2/#comment-39951
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmap = CGContext(data: nil, width: Int(newRect.size.width), height: Int(newRect.size.height), bitsPerComponent: 8, bytesPerRow: Int(newRect.size.width) * 4, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        
        // Rotate and/or flip the image if required by its orientation
        bitmap.concatenate(transform)
        
        // Set the quality level to use when rescaling
        bitmap.interpolationQuality = quality
        
        // Draw into the context; this scales the image
        bitmap.draw(imageRef, in: transpose ? transposedRect: newRect)
        
        // Get the resized image from the context and a UIImage
        let newImageRef: CGImage = bitmap.makeImage()!
        return UIImage(cgImage: newImageRef)
    }
    
    fileprivate func transformForOrientation(_ newSize: CGSize) -> CGAffineTransform {
        var transform: CGAffineTransform = CGAffineTransform.identity
        
        switch (self.imageOrientation) {
        case .down, .downMirrored:
            // EXIF = 3 / 4
            transform = transform.translatedBy(x: newSize.width, y: newSize.height)
            transform = transform.rotated(by: .pi)
        case .left, .leftMirrored:
            // EXIF = 6 / 5
            transform = transform.translatedBy(x: newSize.width, y: 0)
            transform = transform.rotated(by: .pi / 2)
        case .right, .rightMirrored:
            // EXIF = 8 / 7
            transform = transform.translatedBy(x: 0, y: newSize.height)
            transform = transform.rotated(by: -.pi / 2)
        default:
            break
        }
        
        switch(self.imageOrientation) {
        case .upMirrored, .downMirrored:
            // EXIF = 2 / 4
            transform = transform.translatedBy(x: newSize.width, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        case .leftMirrored, .rightMirrored:
            // EXIF = 5 / 7
            transform = transform.translatedBy(x: newSize.height, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        default:
            break
        }
        
        return transform
    }
    
    func rotate(radians: Float) -> UIImage? {
        var newSize = CGRect(origin: CGPoint.zero, size: self.size).applying(CGAffineTransform(rotationAngle: CGFloat(radians))).size
        // Trim off the extremely small float value to prevent core graphics from rounding it up
        newSize.width = floor(newSize.width)
        newSize.height = floor(newSize.height)

        UIGraphicsBeginImageContextWithOptions(newSize, false, self.scale)
        let context = UIGraphicsGetCurrentContext()!

        // Move origin to middle
        context.translateBy(x: newSize.width/2, y: newSize.height/2)
        // Rotate around middle
        context.rotate(by: CGFloat(radians))
        // Draw the image at its center
        self.draw(in: CGRect(x: -self.size.width/2, y: -self.size.height/2, width: self.size.width, height: self.size.height))

        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage
    }
}
