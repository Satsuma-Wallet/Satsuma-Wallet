//
//  Extensions.swift
//  Satsuma
//
//  Created by Peter Denton on 5/5/23.
//

import Foundation
import UIKit

public extension Data {
    var utf8String:String? {
        return String(bytes: self, encoding: .utf8)
    }
    
    var jsonDict: [String:Any]? {
        return try? JSONSerialization.jsonObject(with: self, options: []) as? [String:Any]
    }
    
    var hex: String {
        return map { String(format: "%02x", $0) }.joined()
    }
}

public extension Data {
    private static let hexRegex = try! NSRegularExpression(pattern: "^([a-fA-F0-9][a-fA-F0-9])*$", options: [])

    init?(hexString: String) {
        if Data.hexRegex.matches(in: hexString, range: NSMakeRange(0, hexString.count)).isEmpty {
            return nil // does not look like a hexadecimal string
        }

        let chars = Array(hexString)

        let bytes: [UInt8] =
            stride(from: 0, to: chars.count, by: 2)
                .map {UInt8(String([chars[$0], chars[$0+1]]), radix: 16)}
                .compactMap{$0}

        self = Data(bytes)
    }

    var hexString: String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
}

public extension String {
    var utf8: Data {
        return data(using: .utf8)!
    }
    
    static let numberFormatter = NumberFormatter()
    
    var doubleValue: Double {
        
        String.numberFormatter.decimalSeparator = "."
        
        if let result =  String.numberFormatter.number(from: self) {
            return result.doubleValue
        } else {
            String.numberFormatter.decimalSeparator = ","
            
            if let result = String.numberFormatter.number(from: self) {
                return result.doubleValue
            }
        }
        
        return 0
    }
    
    var hex: Data? {
        var data = Data(capacity: count / 2)
        
        let regex = try! NSRegularExpression(pattern: "[0-9a-f]{1,2}", options: .caseInsensitive)
        regex.enumerateMatches(in: self, range: NSRange(startIndex..., in: self)) { match, _, _ in
            let byteString = (self as NSString).substring(with: match!.range)
            let num = UInt8(byteString, radix: 16)!
            data.append(num)
        }
        
        guard data.count > 0 else { return nil }
        
        return data
    }
}

public extension [String:Any] {
    var jsonData: Data? {
        return try? JSONSerialization.data(withJSONObject: self, options: .prettyPrinted)
    }
}

public extension Utxo_Cache {
    var stringBtcAmount: String {
        return "\(Double(self.value).btcAmountDouble.avoidNotation) BTC"
    }
    
    var doubleValueSats: Double {
        return Double(self.value)
    }
    
    var outpoint: String {
        return self.txid + ":" + "\(Int(self.vout))"
    }
}

public extension Utxo_Fetched {
    var stringBtcAmount: String {
        return "\(Double(self.value).btcAmountDouble.avoidNotation) BTC"
    }
    
    var doubleValueSats: Double {
        return Double(self.value)
    }
    
    var outpoint: String {
        return self.txid + ":" + "\(Int(self.vout))"
    }
}

public extension Double {
    var avoidNotation: String {
        let numberFormatter = NumberFormatter()
        numberFormatter.maximumFractionDigits = 8
        numberFormatter.numberStyle = .decimal
        return numberFormatter.string(for: self) ?? ""
    }
    
    var stringBtcAmount: String {
        return "\(self.btcAmountDouble.avoidNotation) BTC"
    }
    
    var btcAmountDouble: Double {
        return self / 100000000.0
    }
    
    func rounded(toPlaces places:Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
    
    var stringAmount: String {
        return "\(self.avoidNotation) BTC"
    }
    
    var satsAmount: Int {
        return Int(self * 100000000.0)
    }
}
