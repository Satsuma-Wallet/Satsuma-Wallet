//
//  Addresses.swift
//  Satsuma
//
//  Created by Peter Denton on 5/9/23.
//

import Foundation

public struct Address_Cache: CustomStringConvertible {
    let id:UUID
    let address:String
    let index:Double
    let pubkey:Data
    let derivation:String
    
    init(_ dictionary: [String: Any]) {
        id = dictionary["id"] as! UUID
        address = dictionary["address"] as! String
        index = dictionary["index"] as! Double
        pubkey = dictionary["pubkey"] as! Data
        derivation = dictionary["derivation"] as! String
    }
    
    public var description: String {
        return "Address data."
    }
}
