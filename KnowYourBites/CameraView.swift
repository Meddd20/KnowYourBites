//
//  CameraView.swift
//  KnowYourBites
//
//  Created by Medhiko Biraja on 10/09/25.
//

import Foundation
import SwiftUI

struct CameraView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> CaptureViewController {
//        SummaryViewController()
        CaptureViewController()
    }
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
        
    }
}
