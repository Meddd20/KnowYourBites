//
//  ValidateResult.swift
//  KnowYourBites
//
//  Created by Medhiko Biraja on 17/09/25.
//

import Foundation
import SwiftUI

struct ValidateResult: Codable {
    var nutrition: Nutrition?
    var composition: Composition?
}

struct Nutrition: Codable {
    var items: [NutritionItem]
    var metaInfoProduct: MetaInfoProduct
}

struct NutritionItem: Codable {
    var name: String
    var value: Double?
    var unit: String?
    var rawLines: String
    
    enum CodingKeys: String, CodingKey {
        case name, value, unit
        case rawLines = "raw_line"
    }
}

struct MetaInfoProduct: Codable {
    var servingSize: String?
    var servingPerContainer: String?
    var calories: Int?
    
    enum CodingKeys: String, CodingKey {
        case servingSize = "serving_size"
        case servingPerContainer = "servings_per_container"
        case calories
    }
}

struct Composition: Codable {
    var ingredients: [String]?
    var containAllergens: [String]?
    var mayContain: [String]?
    var claims: [String]?
    
    enum CodingKeys: String, CodingKey {
        case ingredients, claims
        case containAllergens = "contain_allergens"
        case mayContain = "may_contain"
    }
}
