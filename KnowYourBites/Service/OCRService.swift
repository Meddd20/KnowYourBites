//
//  OCRService.swift
//  KnowYourBites
//
//  Created by Medhiko Biraja on 11/09/25.
//

import Vision
import UIKit

final class OCRService: UIViewController {
    func recognizeText(
        cgImage: CGImage,
        orientation: CGImagePropertyOrientation,
        language: [String],
        fast: Bool,
        completion: @escaping (_ text: String, _ observation: [VNRecognizedTextObservation]) -> Void
    ) {
        let request = VNRecognizeTextRequest { request, error in
            guard error == nil, let results = request.results as? [VNRecognizedTextObservation] else {
                DispatchQueue.main.async {
                    completion("", [])
                }
                return
            }
            
            let lines = results.compactMap { $0.topCandidates(1).first?.string }
            let text = lines.joined(separator: "\n")
            
            DispatchQueue.main.async {
                completion(text, results)
            }
        }
        
        request.recognitionLevel = fast ? .fast : .accurate
        request.usesLanguageCorrection = true
        request.customWords = ["protein","serat","lemak","karbohidrat","kalori","vitamin","mineral"]
        request.recognitionLanguages = language
        
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async {
                    self.showPictureIssueAllert(message: "No text detected, please retake")
                    return
                }
            }
        }
    }
    
    private func extractTokens(from observations: [VNRecognizedTextObservation], imageSize: CGSize) -> [Token] {
        var tokens: [Token] = []
        
        for obs in observations {
            guard let top = obs.topCandidates(1).first else { continue } // objek VNRecognizedText dengan confidence tertinggi
            let line = top.string
            
            let words = line.split(whereSeparator: { $0.isWhitespace} )
            
            // fallback semisal array wordsnya nil, tetap disimpan tokennya dengan teks "" dan rect nya untuk menjaga layout
            if words.isEmpty {
                let boundingBox = obs.boundingBox
                let rect = CGRect(x: boundingBox.minX * imageSize.width, y: boundingBox.minY * imageSize.height, width: boundingBox.width * imageSize.width, height: boundingBox.height * imageSize.height)
                tokens.append(Token(text: line, rect: rect))
                continue
            }
            
            var cursor = line.startIndex
            for word in words {
                // mencari word berada pada range index berapa pada line
                if let range = line.range(of: String(word), range: cursor..<line.endIndex) {
                    // mencari VNRectangleObservation dari range index word
                    if let box = try? top.boundingBox(for: range) {
                        let rect = CGRect(x: box.boundingBox.minX * imageSize.width, y: box.boundingBox.minY * imageSize.height, width: box.boundingBox.width * imageSize.width, height: box.boundingBox.height * imageSize.height) // harus dikali karena boundingbox berbentuk persentase 0..1
                        tokens.append(Token(text: String(word), rect: rect))
                    }
                    cursor = range.upperBound // beralih ke range setelahnya
                }
            }
        }
        
        return tokens
    }
    
    private func groupTokensIntoLines(_ tokens: [Token]) -> [[Token]] {
        guard !tokens.isEmpty else { return []}
        
        // urutkan tokens berdasarkan midY, semakin besar, semakin atas, dimulai dari kiri bawah
        let sorted = tokens.sorted { $0.midY > $1.midY }
        
        let heights = sorted.map { $0.height }.sorted() // ambil height kemudian sort asc
        let medianHeight = heights[heights.count / 2 ] // ambil median dari array heights
        // toleransi tinggi huruf y masih dianggap sebaris
        let yThreshold = max(4, medianHeight * 0.6) // 4 adalah batas bawah agar tdk terlalu sensitif
        
        var lines: [[Token]] = []
        for token in sorted {
            // mencari apakah token tersebut sebaris berdasarkan ythresholdnya
            // anchor adalah token pertama di baris tersebut, digunakan sebagai patokan tinggi y
            if var last = lines.last, let anchor = last.first {
                // tinggi token kurang dari sama dengan threshold, maka append sebagai satu baris yang sama
                if abs(anchor.midY - token.midY) <= yThreshold {
                    last.append(token)
                    lines[lines.count - 1] = last
                } else {
                    // append sebagai array baru
                    lines.append([token])
                }
            } else {
                lines.append([token])
            }
        }
        
        return lines.map { $0.sorted { $0.minX < $1.minX }} // mengurutkan token berdasarkan posisi paling kiri
    }
    
    // ambil textnya saja, kemudian di gabungkan dengan seperator " "
    private func joinLines(_ lines: [[Token]]) -> [String] {
        return lines.map { line in
            line.map(\.text).joined(separator: " ")
        }
    }

    func makeJoinedLines(from observations: [VNRecognizedTextObservation], imageSize: CGSize) -> [String] {
        let tokens = extractTokens(from: observations, imageSize: imageSize)
        let lines = groupTokensIntoLines(tokens)
        return joinLines(lines)
    }
     
}

private struct Token {
    let text: String
    let rect: CGRect // kotak posisi kata dalam pixel
    var midY: CGFloat { rect.midY }
    var minX: CGFloat { rect.minX }
    var height: CGFloat { rect.height }
}

extension CGImagePropertyOrientation {
    init(from ui: UIImage.Orientation) {
        switch ui {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
