//
//  GlareDetector.swift
//  KnowYourBites
//
//  Created by Medhiko Biraja on 17/09/25.
//

import Foundation
import UIKit

struct GlareDetector {
    private let glareThreshold: Double = 0.1
    
    func isGlare(_ image: UIImage) -> Bool {
        guard let cgImage = image.cgImage else { return false }
        let CIImage = CIImage(cgImage: cgImage)
        
        let extent = CIImage.extent // ambil bounding box dari CIImage
        let context = CIContext()
        var bitmap = [UInt8](repeating: 0, count: 4) // bikin array 4 elemen (RGBA) bertipe UInt8 (0-256)
        
        var glarePixels = 0
        var totalSamples = 500
        
        for _ in 0..<totalSamples {
            let x = Int.random(in: Int(extent.minX)..<Int(extent.maxX))
            let y = Int.random(in: Int(extent.minY)..<Int(extent.maxY))
            
            context.render(
                CIImage,
                toBitmap: &bitmap,
                rowBytes: 4,
                bounds: CGRect(x: x, y: y, width: 1, height: 1),
                format: .RGBA8,
                colorSpace: CGColorSpaceCreateDeviceRGB()
            )
            
            let r = Double(bitmap[0]) / 255.0
            let g = Double(bitmap[1]) / 255.0
            let b = Double(bitmap[2]) / 255.0
            
            let value = max(r, max(g, b))
            
            let minValue = min(r, min(g, b))
            let saturation = value == 0 ? 0 : (value - minValue) / value
            
            if value > 0.9 && saturation < 0.2 {
                glarePixels += 1
            }
        }
        let ratio = Double(glarePixels) / Double(totalSamples)
        
        return ratio > glareThreshold
    }
}
