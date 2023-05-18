//
//  Utxos.swift
//  Satsuma
//
//  Created by Peter Denton on 5/8/23.
//

import Foundation

public struct Utxo_Cache: CustomStringConvertible {
    let id:UUID
    let vout:Double
    let txid:String
    let value:Double
    let confirmed:Bool
    let address:String
    let pubkey:Data
    let derivation:String
    
    init(_ dictionary: [String: Any]) {
        id = dictionary["id"] as! UUID
        vout = dictionary["vout"] as! Double
        txid = dictionary["txid"] as! String
        value = dictionary["value"] as! Double
        confirmed = dictionary["confirmed"] as! Bool
        address = dictionary["address"] as! String
        pubkey = dictionary["pubkey"] as! Data
        derivation = dictionary["derivation"] as! String
    }
    
    public var description: String {
        return "Utxo from Core Data."
    }
}

public struct Utxo_Fetched: CustomStringConvertible {
    let vout:Int
    let txid:String
    let value:Int
    let confirmed:Bool
    
    init(_ dictionary: [String: Any]) {
        vout = dictionary["vout"] as! Int
        txid = dictionary["txid"] as! String
        value = dictionary["value"] as! Int
        let statusDict = dictionary["status"] as! [String:Any]
        confirmed = statusDict["confirmed"] as! Bool
    }
    
    public var description: String {
        return "Utxo from API."
    }
}
