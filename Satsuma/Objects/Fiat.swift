//
//  Fiat.swift
//  Satsuma
//
//  Created by Peter Denton on 5/24/23.
//

import Foundation

public struct Fiat_Options: CustomStringConvertible {
    var currencies:[Fiat_Value] = []
    
    init(_ dictionary: [String: Any]) {
        for (_, value) in dictionary {
            guard let value = value as? [String:Any] else { return }
            currencies.append(Fiat_Value(value))
        }
    }
    
    public var description: String {
        return "Fiat options."
    }
}

public struct Fiat_Value: CustomStringConvertible {
    let symbol:String
    let price:Double
    
    init(_ dictionary: [String: Any]) {
        symbol = dictionary["symbol"] as! String
        price = dictionary["15m"] as! Double
        
    }
    
    public var description: String {
        return "Fiat ."
    }
}

/*
 {
   "ARS": {
     "15m": 1.259683929E7,
     "last": 1.259683929E7,
     "buy": 1.259683929E7,
     "sell": 1.259683929E7,
     "symbol": "ARS"
   },
   "AUD": {
     "15m": 40089.6,
     "last": 40089.6,
     "buy": 40089.6,
     "sell": 40089.6,
     "symbol": "AUD"
   },
   "BRL": {
     "15m": 130966.92,
     "last": 130966.92,
     "buy": 130966.92,
     "sell": 130966.92,
     "symbol": "BRL"
   },
   "CAD": {
     "15m": 35665.68,
     "last": 35665.68,
     "buy": 35665.68,
     "sell": 35665.68,
     "symbol": "CAD"
   },
   "CHF": {
     "15m": 23820.05,
     "last": 23820.05,
     "buy": 23820.05,
     "sell": 23820.05,
     "symbol": "CHF"
   },
   "CLP": {
     "15m": 2.130712132E7,
     "last": 2.130712132E7,
     "buy": 2.130712132E7,
     "sell": 2.130712132E7,
     "symbol": "CLP"
   },
   "CNY": {
     "15m": 172417.78,
     "last": 172417.78,
     "buy": 172417.78,
     "sell": 172417.78,
     "symbol": "CNY"
   },
   "CZK": {
     "15m": 581438.02,
     "last": 581438.02,
     "buy": 581438.02,
     "sell": 581438.02,
     "symbol": "CZK"
   },
   "DKK": {
     "15m": 120491.92,
     "last": 120491.92,
     "buy": 120491.92,
     "sell": 120491.92,
     "symbol": "DKK"
   },
   "EUR": {
     "15m": 24426.4,
     "last": 24426.4,
     "buy": 24426.4,
     "sell": 24426.4,
     "symbol": "EUR"
   },
   "GBP": {
     "15m": 21264.36,
     "last": 21264.36,
     "buy": 21264.36,
     "sell": 21264.36,
     "symbol": "GBP"
   },
   "HKD": {
     "15m": 206730.41,
     "last": 206730.41,
     "buy": 206730.41,
     "sell": 206730.41,
     "symbol": "HKD"
   },
   "HRK": {
     "15m": 122677.04,
     "last": 122677.04,
     "buy": 122677.04,
     "sell": 122677.04,
     "symbol": "HRK"
   },
   "HUF": {
     "15m": 8263944.7,
     "last": 8263944.7,
     "buy": 8263944.7,
     "sell": 8263944.7,
     "symbol": "HUF"
   },
   "INR": {
     "15m": 1991377.83,
     "last": 1991377.83,
     "buy": 1991377.83,
     "sell": 1991377.83,
     "symbol": "INR"
   },
   "ISK": {
     "15m": 3476969.9,
     "last": 3476969.9,
     "buy": 3476969.9,
     "sell": 3476969.9,
     "symbol": "ISK"
   },
   "JPY": {
     "15m": 3663663.97,
     "last": 3663663.97,
     "buy": 3663663.97,
     "sell": 3663663.97,
     "symbol": "JPY"
   },
   "KRW": {
     "15m": 3.536495078E7,
     "last": 3.536495078E7,
     "buy": 3.536495078E7,
     "sell": 3.536495078E7,
     "symbol": "KRW"
   },
   "NZD": {
     "15m": 43008.91,
     "last": 43008.91,
     "buy": 43008.91,
     "sell": 43008.91,
     "symbol": "NZD"
   },
   "PLN": {
     "15m": 110503.92,
     "last": 110503.92,
     "buy": 110503.92,
     "sell": 110503.92,
     "symbol": "PLN"
   },
   "RON": {
     "15m": 97501.31,
     "last": 97501.31,
     "buy": 97501.31,
     "sell": 97501.31,
     "symbol": "RON"
   },
   "RUB": {
     "15m": 2118652.07,
     "last": 2118652.07,
     "buy": 2118652.07,
     "sell": 2118652.07,
     "symbol": "RUB"
   },
   "SEK": {
     "15m": 201782.9,
     "last": 201782.9,
     "buy": 201782.9,
     "sell": 201782.9,
     "symbol": "SEK"
   },
   "SGD": {
     "15m": 35140.03,
     "last": 35140.03,
     "buy": 35140.03,
     "sell": 35140.03,
     "symbol": "SGD"
   },
   "THB": {
     "15m": 907017.53,
     "last": 907017.53,
     "buy": 907017.53,
     "sell": 907017.53,
     "symbol": "THB"
   },
   "TRY": {
     "15m": 554565.92,
     "last": 554565.92,
     "buy": 554565.92,
     "sell": 554565.92,
     "symbol": "TRY"
   },
   "TWD": {
     "15m": 598294.37,
     "last": 598294.37,
     "buy": 598294.37,
     "sell": 598294.37,
     "symbol": "TWD"
   },
   "USD": {
     "15m": 26282.74,
     "last": 26282.74,
     "buy": 26282.74,
     "sell": 26282.74,
     "symbol": "USD"
   }
 }
 */
