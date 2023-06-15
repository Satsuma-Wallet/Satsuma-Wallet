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
            
            var rootUrl = UserDefaults.standard.object(forKey: "url") as? String ?? "https://blockstream.info"
            
            var mempoolApiRoot = "http://mempoolhqx4isw62xs7abwphsq7ldayuidyx2v2oethdhhj6mlo2r6ad.onion/api/v1"
            let mempoolApiRootClear = "https://mempool.space/api/v1"
            
            let torEnabled = UserDefaults.standard.object(forKey: "torEnabled") as? Bool ?? false
            if !torEnabled {
                mempoolApiRoot = mempoolApiRootClear
            }
            
            if let customUrl = UserDefaults.standard.object(forKey: "customUrl") as? String, customUrl != "" {
                rootUrl = customUrl
            }
            
            // https://mempool.space/testnet/api/v1/address/tb1q2l2w6mpmr7psm
            // https://blockstream.info/testnet/api/address/tb1qz9q0cpglp3xvuhkzsjffklyf46le889vwlujgq/utxo
            // https://mempool.space/testnet/api/address/tb1q4kgratttzjvkxfmgd95z54qcq7y6hekdm3w56u/utxo
            
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

