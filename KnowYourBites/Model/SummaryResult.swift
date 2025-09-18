//
//  SummaryResult.swift
//  KnowYourBites
//
//  Created by Medhiko Biraja on 18/09/25.
//

import Foundation

struct SummaryResult: Codable {
    var validProductImage: Bool
    var meta: MetaInfoProduct?
    var nutrition: [NutritionSummary]?
    var composition: [CompositionDetails]?
    var labels: ProductLabel?
    var roast: String?
    
    enum CodingKeys: String, CodingKey {
        case validProductImage = "valid_product_image"
        case meta, nutrition, composition, labels, roast
    }
}

struct NutritionSummary: Codable {
    var item: ItemDetails
    var explanation: ItemExplanation
}

struct ItemDetails: Codable {
    var name: String
    var value: Double?
    var unit: String?
    var rawLine: String
    
    enum CodingKeys: String, CodingKey {
        case name, value, unit
        case rawLine = "raw_line"
    }
}

struct ItemExplanation: Codable {
    var whatItMeans: String
    var healthNote: String?
    
    enum CodingKeys: String, CodingKey {
        case whatItMeans = "what_it_means"
        case healthNote = "health_note"
    }
}

struct CompositionDetails: Codable {
    var ingredient: String
    var explanation: CompositionExplanation
}

struct CompositionExplanation: Codable {
    var role: String?
    var caution: String?
}

struct ProductLabel: Codable {
    var allergens: Allergens?
    var claims: [String]?
    var halal: IsHalalProduct
}

struct Allergens: Codable {
    var contains: [String]?
    var mayContain: [String]?
}

struct IsHalalProduct: Codable {
    var present: Bool
    var source: [String]?
}

