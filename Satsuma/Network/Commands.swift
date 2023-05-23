//
//  Commands.swift
//  Satsuma
//
//  Created by Peter Denton on 5/8/23.
//

import Foundation

class Commands {

    public enum Mempool_Rest {
        case utxo(address: String)
        case broadcast(tx: String)
        case fee
        
        var stringValue:String {
            let rootOnionUrl = "http://explorerzydxu5ecjrkwceayqybizmpjjznk5izmitf2modhcusuqlid.onion/testnet/api"
            var mempoolApiRoot = "http://mempoolhqx4isw62xs7abwphsq7ldayuidyx2v2oethdhhj6mlo2r6ad.onion/api/v1"
            let rootClearnetUrl = "https://blockstream.info/testnet/api"//"https://mempool.space/api"
            let mempoolApiRootClear = "https://mempool.space/api/v1"
            var rootUrl = rootOnionUrl
            
            let torEnabled = UserDefaults.standard.object(forKey: "torEnabled") as? Bool ?? false
            
            if !torEnabled {
                rootUrl = rootClearnetUrl
                mempoolApiRoot = mempoolApiRootClear
            }
            
            switch self {
            case .utxo(let address):
                return "\(rootUrl)/address/\(address)/utxo"
            case .broadcast(_):
                return "\(rootUrl)/tx"
            case .fee:
                return "\(mempoolApiRoot)/fees/recommended"
            }
        }
    }
}

