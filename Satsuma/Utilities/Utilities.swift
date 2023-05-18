//
//  Utilities.swift
//  Satsuma
//
//  Created by Peter Denton on 5/5/23.
//

import Foundation
import UIKit

public func randomString(length: Int) -> String {
    let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    return String((0...length-1).map{ _ in letters.randomElement()! })
}

public func showAlert(vc: UIViewController, title: String, message: String) {
    DispatchQueue.main.async {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in }))
        alert.popoverPresentationController?.sourceView = vc.view
        vc.present(alert, animated: true, completion: nil)
    }
}


