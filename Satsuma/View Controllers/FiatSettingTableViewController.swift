//
//  FiatSettingTableViewController.swift
//  Satsuma
//
//  Created by Peter Denton on 5/24/23.
//

import UIKit

class FiatSettingTableViewController: UITableViewController {
    
    var fiatValues:[Fiat_Value] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        let currency = UserDefaults.standard.object(forKey: "fiat") as? String ?? "USD"
        for (i, item) in fiatValues.enumerated() {
            if item.symbol == currency {
                fiatValues.swapAt(i, 0)
            }
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fiatValues.count
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "fiatCell", for: indexPath)

        cell.textLabel!.text = fiatValues[indexPath.row].symbol
        
        let currency = UserDefaults.standard.object(forKey: "fiat") as? String ?? "USD"
        cell.selectionStyle = .none
        
        if currency == fiatValues[indexPath.row].symbol {
            cell.isSelected = true
            cell.accessoryType = .checkmark
            cell.textLabel!.alpha = 1.0
        } else {
            cell.isSelected = false
            cell.accessoryType = .none
            cell.textLabel!.alpha = 0.2
        }

        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        UserDefaults.standard.set(fiatValues[indexPath.row].symbol, forKey: "fiat")
        tableView.reloadData()
    }
}
