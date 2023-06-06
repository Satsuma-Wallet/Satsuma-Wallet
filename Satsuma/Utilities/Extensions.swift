//
//  Extensions.swift
//  Satsuma
//
//  Created by Peter Denton on 5/5/23.
//

import Foundation
import UIKit

// A place for convenience and cleaner code, do dirty work here.

public extension UIView {
    func shake() {
        let animation = CABasicAnimation(keyPath: "position")
        animation.duration = 0.07
        animation.repeatCount = 4
        animation.autoreverses = true
        animation.fromValue = NSValue(cgPoint: CGPoint(x: self.center.x - 10, y: self.center.y))
        animation.toValue = NSValue(cgPoint: CGPoint(x: self.center.x + 10, y: self.center.y))
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.layer.add(animation, forKey: "position")
        }
    }
}

public extension UIViewController {
    func showAlert(title: String, message: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    static let blurView = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffect.Style.dark))
    static let label = UILabel()
    static let activityIndicator = UIActivityIndicatorView()
    
    func addSpinnerView(description: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            UIViewController.blurView.frame = CGRect(x: 0, y: -20, width: self.view.frame.width, height: self.view.frame.height + 20)
            self.view.addSubview(UIViewController.blurView)
            
            UIViewController.activityIndicator.frame = CGRect(x: UIViewController.blurView.center.x - 25,
                                             y: (UIViewController.blurView.center.y - 25) - 20,
                                             width: 50,
                                             height: 50)
            
            UIViewController.activityIndicator.hidesWhenStopped = true
            UIViewController.activityIndicator.style = .large
            UIViewController.activityIndicator.alpha = 0
            UIViewController.blurView.contentView.addSubview(UIViewController.activityIndicator)
            UIViewController.activityIndicator.startAnimating()
            
            UIViewController.label.frame = CGRect(x: (UIViewController.blurView.frame.maxX - 250) / 2,
                                 y: UIViewController.activityIndicator.frame.maxY,
                                 width: 250,
                                 height: 60)
            
            UIViewController.label.text = description.lowercased()
            UIViewController.label.textColor = UIColor.white
            UIViewController.label.font = UIFont.systemFont(ofSize: 12)
            UIViewController.label.textAlignment = .center
            UIViewController.label.alpha = 0
            UIViewController.label.numberOfLines = 0
            UIViewController.blurView.contentView.addSubview(UIViewController.label)
            
            UIView.animate(withDuration: 0.5) {
                UIViewController.blurView.alpha = 1
                UIViewController.activityIndicator.alpha = 1
                UIViewController.label.alpha = 1
            }
        }
    }
    
    func removeSpinnerView() {
        DispatchQueue.main.async {
            UIView.animate(withDuration: 0.5, animations: {
                UIViewController.blurView.alpha = 0
            }) { _ in
                UIViewController.blurView.removeFromSuperview()
                UIViewController.label.removeFromSuperview()
                UIViewController.activityIndicator.stopAnimating()
                UIViewController.activityIndicator.removeFromSuperview()
            }
        }
    }
}

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
    
    func random(length: Int) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0...length-1).map{ _ in letters.randomElement()! })
    }
    
    var currencySymbolFromCode: String {
        let locale = NSLocale(localeIdentifier: self)
        if locale.displayName(forKey: .currencySymbol, value: self) == self {
            let newlocale = NSLocale(localeIdentifier: self.dropLast() + "_en")
            return newlocale.displayName(forKey: .currencySymbol, value: self)!
        }
        return locale.displayName(forKey: .currencySymbol, value: self)!
    }
    
    func condenseWhitespace() -> String {
        let components = self.components(separatedBy: .whitespacesAndNewlines)
        return components.filter { !$0.isEmpty }.joined(separator: " ")
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
    
    func fiatBalance(fxRate: Double) -> String {
        // self is the btc amount as a double
        let currencyCode = UserDefaults.standard.object(forKey: "fiat") as? String ?? "USD"
        var currencySymbol = currencyCode.currencySymbolFromCode
        if currencyCode == currencySymbol {
            currencySymbol = ""
        }
        var textBalance = "\(currencySymbol)\((self * fxRate).rounded(toPlaces: 2).avoidNotation) \(currencyCode)"
        if self == 0 {
            textBalance = "\(currencySymbol)0.00 \(currencyCode)"
        }
        return textBalance
    }
    
    var btcBalance: String {
        var btcBalance = self.btcAmountDouble.rounded(toPlaces: 8).avoidNotation + " BTC"
        if self == 0 {
            btcBalance = "0.00000000 BTC"
        }
        return btcBalance
    }
}

public extension RecommendedFee {
    var target: Int {
        let priority = UserDefaults.standard.object(forKey: "feePriority") as? String ?? "high"
        switch priority {
        case "high":
            return self.fastest
        case "standard":
            return self.hour
        case "low":
            return self.economy
        case "minimum":
            return self.minimum
        default:
            return self.hour
        }
    }
    
}
