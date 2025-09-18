//
//  CaptureFlow.swift
//  KnowYourBites
//
//  Created by Medhiko Biraja on 16/09/25.
//

import Foundation

final class CaptureFlow {
    var completed: Set<CaptureStep> = []
    
    func nextStep() -> CaptureStep? {
        for step in CaptureStep.allCases {
            if !completed.contains(step) {
                return step
            }
        }
        return nil
    }
    
    func complete(_ step: CaptureStep) {
        completed.insert(step)
    }
    
    func reset() {
        completed.removeAll()
    }
    
}
