//
//  RecommendedFee.swift
//  Satsuma
//
//  Created by Peter Denton on 5/22/23.
//

import Foundation
// ["fastestFee": 55, "economyFee": 24, "halfHourFee": 49, "hourFee": 44, "minimumFee": 12]

public struct RecommendedFee: CustomStringConvertible {
    let fastest:Int
    let economy:Int
    let hour:Int
    let minimum:Int
    
    init(_ dictionary: [String: Any]) {
        fastest = dictionary["fastestFee"] as! Int
        economy = dictionary["economyFee"] as! Int
        hour = dictionary["hourFee"] as! Int
        minimum = dictionary["minimumFee"] as! Int
    }
    
    public var description: String {
        return "Recommended fee from Mempool Space."
    }
}
