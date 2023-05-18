//
//  Wallets.swift
//  Satsuma
//
//  Created by Peter Denton on 5/8/23.
//

import Foundation

public struct Wallet: CustomStringConvertible {
    let id:UUID
    let receiveIndex:Double
    let changeIndex:Double
    let mnemonic:Data
    
    init(_ dictionary: [String: Any]) {
        id = dictionary["id"] as! UUID
        receiveIndex = dictionary["receiveIndex"] as! Double
        changeIndex = dictionary["changeIndex"] as! Double
        mnemonic = dictionary["mnemonic"] as! Data
    }
    
    public var description: String {
        return "Wallet data."
    }
    
}
