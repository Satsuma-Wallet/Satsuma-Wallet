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
        
        var stringValue:String {
            let rootOnionUrl = "http://explorerzydxu5ecjrkwceayqybizmpjjznk5izmitf2modhcusuqlid.onion/testnet/api"
            //"http://mempoolhqx4isw62xs7abwphsq7ldayuidyx2v2oethdhhj6mlo2r6ad.onion/api"
            let rootClearnetUrl = "https://blockstream.info/testnet/api"//"https://mempool.space/api"
            let torEnabled = UserDefaults.standard.object(forKey: "torEnabled") as? Bool ?? false
            
            var rootUrl = rootOnionUrl
            if !torEnabled {
                rootUrl = rootClearnetUrl
            }
            
            switch self {
            case .utxo(let address):
                return "\(rootUrl)/address/\(address)/utxo"
            default:
                return "\(rootUrl)/tx"
            }
        }
    }
}

