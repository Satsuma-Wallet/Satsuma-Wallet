//
//  Server.swift
//  Satsuma
//
//  Created by Peter Denton on 5/5/23.
//

import Foundation

public struct Server: CustomStringConvertible {
    let id:UUID
    let domain:Data
    //let port:Int
    
    init(_ dictionary: [String: Any]) {
        id = dictionary["id"] as! UUID
        domain = dictionary["domain"] as! Data
        //port = dictionary["port"] as! Int
    }
    
    public var description: String {
        return "Server url. Onion compatible."
    }
    
}
