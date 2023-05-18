//
//  Crypto.swift
//  Satsuma
//
//  Created by Peter Denton on 5/5/23.
//

import Foundation
import CryptoKit

enum Crypto {
    static func decrypt(_ data: Data) -> Data? {
        guard let key = KeyChain.getData("privateKey"),
            let box = try? ChaChaPoly.SealedBox.init(combined: data) else {
                return nil
        }
        
        return try? ChaChaPoly.open(box, using: SymmetricKey(data: key))
    }
    
    static func encrypt(_ data: Data) -> Data? {
        guard let key = KeyChain.getData("privateKey") else {
            if KeyChain.set(Crypto.privateKey(), forKey: "privateKey") {
                return encrypt(data)
            } else {
                return nil
            }
        }
        return try? ChaChaPoly.seal(data, using: SymmetricKey(data: key)).combined
    }
    
    static func privateKey() -> Data {
        return P256.Signing.PrivateKey().rawRepresentation
    }
    
    static func sha256hash(_ text: String) -> String {
        let digest = SHA256.hash(data: text.utf8)
        
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
    
    static func sha256hash(_ data: Data) -> Data {
        let digest = SHA256.hash(data: data)
        
        return Data(digest)
    }
}
