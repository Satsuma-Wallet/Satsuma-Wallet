//
//  RecommendedFee.swift
//  Satsuma
//
//  Created by Peter Denton on 5/22/23.
//

import Foundation
// ["fastestFee": 55, "economyFee": 24, "halfHourFee": 49, "hourFee": 44, "minimumFee": 12]

public struct RecommendedFee: CustomStringConvertible {
    let fastestFee:Int
    let economyFee:Int
    
    init(_ dictionary: [String: Any]) {
        fastestFee = dictionary["fastestFee"] as! Int
        economyFee = dictionary["economyFee"] as! Int
    }
    
    public var description: String {
        return "Recommended fee from Mempool Space."
    }
}
