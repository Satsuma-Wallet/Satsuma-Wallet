//
//  FiatConverter.swift
//  Satsuma
//
//  Created by Peter Denton on 5/10/23.
//

import Foundation

class FiatConverter {
    
    static let sharedInstance = FiatConverter()
    
    private init() {}
    
    func getFxRate(completion: @escaping ((Double?)) -> Void) {
        let currency = UserDefaults.standard.object(forKey: "fiat") as? String ?? "USD"
        let torClient = TorClient.sharedInstance
        let url = NSURL(string: "https://blockchain.info/ticker")
        let torEnabled = UserDefaults.standard.object(forKey: "torEnabled") as? Bool ?? true
        var session = URLSession(configuration: .default)
        if torEnabled {
            session = torClient.session
        }
        let task = session.dataTask(with: url! as URL) { (data, response, error) -> Void in
            guard let urlContent = data,
                  let json = try? JSONSerialization.jsonObject(with: urlContent, options: [.mutableContainers]) as? [String : Any],
                  let data = json["\(currency)"] as? NSDictionary,
                  let rateCheck = data["15m"] as? Double else {
                completion(nil)
                return
            }
            
            completion(rateCheck)
        }
        task.resume()
    }
    
    func getCurrencies(completion: @escaping (([Fiat_Value]?)) -> Void) {
        let torClient = TorClient.sharedInstance
        let url = NSURL(string: "https://blockchain.info/ticker")
        let torEnabled = UserDefaults.standard.object(forKey: "torEnabled") as? Bool ?? true
        var session = URLSession(configuration: .default)
        if torEnabled {
            session = torClient.session
        }
        let task = session.dataTask(with: url! as URL) { (data, response, error) -> Void in
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
