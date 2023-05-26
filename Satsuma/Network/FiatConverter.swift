//
//  FiatConverter.swift
//  Satsuma
//
//  Created by Peter Denton on 5/10/23.
//

import Foundation

class FiatConverter {
    // Allows us to resuse this class without recreating it everytime.
    static let sharedInstance = FiatConverter()
    
    // The url where we fetch our fiat exchange rates.
    let url:URL = URL(string: "https://blockchain.info/ticker")!
    
    private init() {}
    
    // Returns a url session depending on whether Tor is enabled or not.
    private func urlSession() -> URLSession {
        let torEnabled = UserDefaults.standard.object(forKey: "torEnabled") as? Bool ?? true
        var session = URLSession(configuration: .default)
        if torEnabled {
            session = TorClient.sharedInstance.session
        }
        return session
    }
    
    // Returns the 15m average exchange rate based upon the provided currency code.
    func getFxRate(currency: String, completion: @escaping ((Double?)) -> Void) {
        self.getCurrencies { fiatValues in
            guard let fiatValues = fiatValues else {
                completion(nil)
                return
            }
            
            for fiatValue in fiatValues {
                if fiatValue.symbol == currency {
                    completion((fiatValue.price))
                    return
                }
            }
        }
    }
    
    // Returns all fiat currencies as a Fiat_Value array in alphabetic order.
    func getCurrencies(completion: @escaping (([Fiat_Value]?)) -> Void) {
        let task = urlSession().dataTask(with: url) { (data, response, error) -> Void in
            guard let urlContent = data,
                  let json = try? JSONSerialization.jsonObject(with: urlContent, options: [.mutableContainers]) as? [String : Any] else {
                completion(nil)
                return
            }
            
            let fiatOptions = Fiat_Options(json)
            var currencies = fiatOptions.currencies
            currencies = currencies.sorted { $0.symbol < $1.symbol }
            completion(currencies)
        }
        
        task.resume()
    }
}
