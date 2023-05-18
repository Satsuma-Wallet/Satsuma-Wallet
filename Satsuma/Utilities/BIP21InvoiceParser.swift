//
//  BIP21InvoiceParser.swift
//  Satsuma
//
//  Created by Peter Denton on 5/16/23.
//

import Foundation

class BIP21InvoiceParser {
    
    static let shared = BIP21InvoiceParser()
    var addressToReturn:String?
    var amountToReturn:Double?
    var labelToReturn:String?
    var message:String?
    
    private init() {}
    
    func parseInvoice(url: String) -> (address: String?, amount: Double?, label: String?, message: String?) {
        var processedUrl = url
        processedUrl = processedUrl.replacingOccurrences(of: "bitcoin:", with: "")
        processedUrl = processedUrl.replacingOccurrences(of: "BITCOIN:", with: "")
        
        guard processedUrl.contains("?") || processedUrl.contains("=") else {
            return (address: processedAddress(processedUrl), amount: amountToReturn, label: labelToReturn, message: message)
        }
        
        if processedUrl.hasPrefix(" ") {
            processedUrl = processedUrl.replacingOccurrences(of: " ", with: "")
        }
        
        guard processedUrl.contains("?") else {
            return (address: processedAddress(processedUrl), amount: amountToReturn, label: labelToReturn, message: message)
        }
        
        let split = processedUrl.split(separator: "?")
        
        guard split.count >= 1 else {
            return (address: processedAddress(processedUrl), amount: amountToReturn, label: labelToReturn, message: message)
        }
        
        let urlParts = split[1].split(separator: "&")
        
        addressToReturn = processedAddress("\(split[0])".replacingOccurrences(of: "bitcoin:", with: ""))
        addressToReturn = processedAddress("\(split[0])".replacingOccurrences(of: "BITCOIN:", with: ""))
        
        guard urlParts.count > 0 else {
            return (address: addressToReturn, amount: amountToReturn, label: labelToReturn, message: message)
        }
        
        for item in urlParts {
            let string = "\(item)"
            switch string {
            case _ where string.contains("amount"):
                if string.contains("&") {
                    let array = string.split(separator: "&")
                    let amount = array[0].replacingOccurrences(of: "amount=", with: "")
                    amountToReturn = amount.doubleValue
                } else {
                    let amount = string.replacingOccurrences(of: "amount=", with: "")
                    amountToReturn = amount.doubleValue
                }
                
            case _ where string.contains("label="):
                labelToReturn = (string.replacingOccurrences(of: "label=", with: "")).replacingOccurrences(of: "%20", with: " ")
                
            case _ where string.contains("message="):
                message = (string.replacingOccurrences(of: "message=", with: "")).replacingOccurrences(of: "%20", with: " ")
                
            default:
                break
            }
        }
        
        return (address: addressToReturn, amount: amountToReturn, label: labelToReturn, message: message)
    }
    
    private func processedAddress(_ processed: String) -> String? {
        var address = processed.replacingOccurrences(of: "bitcoin:", with: "")
        address = address.replacingOccurrences(of: "BITCOIN:", with: "")
        if WalletTools.shared.validAddress(string: address) {
            return address
        } else {
            return nil
        }
    }
}
