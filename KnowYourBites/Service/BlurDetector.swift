//
//  BlurDetector.swift
//  KnowYourBites
//
//  Created by Medhiko Biraja on 16/09/25.
//

import Foundation
import UIKit
import CoreImage

final class BlurDetector {
    private let varianceThreshold: Double = 120
    private let downScaleToWidth: CGFloat = 640
    private let context = CIContext(options: [.useSoftwareRenderer: false])
    
    /// UI Image itu digunakan di UI, CGImage (Core Graphics Image) digunakan untuk baca byte, CIImage (Core Image) digunakan untuk apply filter
    func isBlurry(_ image: UIImage) -> Bool {
        guard let cgImage = image.cgImage else { return false } // core graphic image
        var coreImage = CIImage(cgImage: cgImage) // diconvert ke core image
        
        // semisal width gambar lebih besar dari nilai downscale, maka gambar akan di downscale
        if coreImage.extent.width > downScaleToWidth {
            let scale = downScaleToWidth / coreImage.extent.width
            coreImage = coreImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        }
        
        coreImage = coreImage.applyingFilter("CIPhotoEffectMono") // apply grayscale filter
        
        // gambar dibagi menjadi kotak kecil (3x3 kernel)
        // buat ngitung seberapa beda pusat dengan tetangga di gambar yang sudah dikotak-kotakkan
        // semisal bedanya besar, maka ada tajam, sementara kalau kecil atau mendekati 0, berarti tengah mirip dengan tetangganya, maka blur
        // 4 digunakan karena sudut tengah bakal digunakan untuk dibandingkan dengan tetangganya, 4 sisi sehingga "dikuatkan"
        // -1 digunakan agar terjadi pengurangan, agar tetangganya bisa dibandingkan dengan bagian tengah
        // sisi sudut tidak digunakan dan tidak berpengaruh, sehingga diberi nilai 0
        let kernel: [CGFloat] = [0, -1, 0,
                                 -1, 4, -1,
                                 0, -1, 0]
        coreImage = coreImage.applyingFilter("CIConvolution3X3", parameters: [
            "inputWeights": CIVector(values: kernel, count: 9),
            "inputBias": 0
        ])
        
        guard let outCGImage = context.createCGImage(coreImage, from: coreImage.extent),
              let data = outCGImage.dataProvider?.data, // mengambil byte gambar berdasarkan RGBA
                let pointer = CFDataGetBytePtr(data) // pointer byte raw mentah di memory
        else {
            return false
        }
        
        let length = CFDataGetLength(data) // berapa banyak byte total (width * height * 4)
        var sum: Double = 0
        var sumSquare: Double = 0
        var count = 0 // jumlah piksel yang dihitung
        
        // kenapa 4, supaya hanya ambil nilai red saja, karena sudah grayscale
        for i in stride(from: 0, to: length, by: 4) {
            let v = Double(pointer[i])
            sum += v
            sumSquare += v * v
            count += 1
        }
        
        /// Rumus Variance sumSquare / N (jumlah) - (mean)^2
        let mean = sum / Double(count)
        let variance = max(0, (sumSquare / Double(count)) - (mean * mean))
        
        print("Laplacian variance =", variance)
        
        return variance < varianceThreshold
    }
}
