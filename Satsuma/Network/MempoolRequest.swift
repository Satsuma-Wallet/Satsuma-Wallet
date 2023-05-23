//
//  MempoolRequest.swift
//  Satsuma
//
//  Created by Peter Denton on 5/8/23.
//

import Foundation

class MempoolRequest {
    
    static let sharedInstance = MempoolRequest()
    static let torClient = TorClient.sharedInstance
    static var attempts = 0
    
    private init() {}
    
    func command(method: Commands.Mempool_Rest,
                 completion: @escaping ((response: Any?, errorDesc: String?)) -> Void) {
        
        var sesh = URLSession(configuration: .default)
        let torEnabled = UserDefaults.standard.bool(forKey: "torEnabled")
        if torEnabled {
            sesh = MempoolRequest.torClient.session
        }                
        guard let url = URL(string: method.stringValue) else {
            completion((nil, "url error"))
            return
        }
                
        var request = URLRequest(url: url)
        switch method {
        case .broadcast(let tx):
            request.httpMethod = "POST"
            request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
            request.httpBody = tx.data(using: .utf8)
        default:
            request.httpMethod = "GET"
        }
        
        #if DEBUG
        print("url = \(url)")
        #endif
        
        let task = sesh.dataTask(with: request as URLRequest) { (data, response, error) in
            guard error == nil else {
                #if DEBUG
                print("error: \(error!.localizedDescription)")
                #endif
                
                completion((nil, error!.localizedDescription))
                return
            }
            
            guard let urlContent = data else {
                completion((nil, "Tor client session data is nil"))
                return
            }
            
            if let jsonResult = try? JSONSerialization.jsonObject(with: urlContent, options: .mutableLeaves) as? NSArray {
                #if DEBUG
                print("jsonResult: \(jsonResult)")
                #endif
                completion((jsonResult, nil))
                
            } else if let jsonResult = try? JSONSerialization.jsonObject(with: urlContent, options: .mutableLeaves) as? [String:Any] {
                #if DEBUG
                print("jsonResult: \(jsonResult)")
                #endif
                completion((jsonResult, nil))
                
            } else if let text = urlContent.utf8String {
                #if DEBUG
                print("text result: \(text)")
                #endif
                completion((text, nil))
                
            } else {
                completion((nil, "Error serializing response."))
            }
                                    
//            guard let jsonResult = try? JSONSerialization.jsonObject(with: urlContent, options: .mutableLeaves) as? NSArray else {
//                if let text = urlContent.utf8String {
//                    completion((text, nil))
//                    return
//                } else {
//                    completion((nil, "Error serializing."))
//                    return
//                }
//            }
            
            
            
        }
        task.resume()
    }
    
}
