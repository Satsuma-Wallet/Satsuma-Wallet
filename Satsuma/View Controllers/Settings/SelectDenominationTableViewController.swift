//
//  SelectDenominationTableViewController.swift
//  Satsuma
//
//  Created by Peter Denton on 5/25/23.
//

import UIKit

class SelectDenominationTableViewController: UITableViewController {
    
    // Need separate arrays as the denomination setting can be either btc/sat/fiat. Whereas we show fiat and btc concurrently in most views.
    var btcDenominations:[Fiat_Value] = []
    var fiatCurrencies:[Fiat_Value] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Construct our btc denomination array.
        let btc:[String:Any] = ["symbol": "BTC", "15m": 1.0]
        let sats:[String:Any] = ["symbol": "SAT", "15m": 100000000.0]
        btcDenominations.append(Fiat_Value(btc))
        btcDenominations.append(Fiat_Value(sats))
        
        // Construct our fiat denomination array.
        FiatConverter.sharedInstance.getCurrencies { [weak self] fiatValues in
            guard let self = self else { return }
            
            guard let fiatValues = fiatValues else { return }

            for fiatValue in fiatValues {
                self.fiatCurrencies.append(fiatValue)
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.tableView.reloadData()
            }
        }
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return btcDenominations.count
        case 1:
            return fiatCurrencies.count
        default:
            return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "currencyCell", for: indexPath)
        let denomination = UserDefaults.standard.object(forKey: "denomination") as? String ?? "BTC"
        cell.selectionStyle = .none
        
        switch indexPath.section {
        case 0:
            cell.textLabel!.text = btcDenominations[indexPath.row].symbol
            if denomination == btcDenominations[indexPath.row].symbol {
                cell.isSelected = true
                cell.accessoryType = .checkmark
            } else {
                cell.isSelected = false
                cell.accessoryType = .none
            }
        case 1:
            cell.textLabel!.text = fiatCurrencies[indexPath.row].symbol
            if denomination == fiatCurrencies[indexPath.row].symbol {
                cell.isSelected = true
                cell.accessoryType = .checkmark
            } else {
                cell.isSelected = false
                cell.accessoryType = .none
            }
        default:
            break
        }

        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.section {
        case 0:
            UserDefaults.standard.set(btcDenominations[indexPath.row].symbol, forKey: "denomination")
        case 1:
            // If user selects a fiat currecny we automatically set it for the entire app fiat setting.
            UserDefaults.standard.set(fiatCurrencies[indexPath.row].symbol, forKey: "denomination")
            UserDefaults.standard.set(fiatCurrencies[indexPath.row].symbol, forKey: "fiat")
        default:
            break
        }
        
        tableView.reloadData()
    }
    
    private enum Section: Int {
        case btcDenomination
        case fiatCurrency
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = UIView()
        header.backgroundColor = UIColor.clear
        header.frame = CGRect(x: 0, y: 0, width: view.frame.size.width - 32, height: 50)

        let textLabel = UILabel()
        textLabel.textAlignment = .left
        textLabel.font = UIFont.systemFont(ofSize: 17, weight: .regular)
        textLabel.frame = CGRect(x: 16, y: 0, width: 300, height: 50)

        if let section = Section(rawValue: section) {
            textLabel.text = headerName(for: section)
        }

        header.addSubview(textLabel)
        return header
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 50
    }
    
    private func headerName(for section: Section) -> String {
        switch section {
        case .btcDenomination:
            return "Bitcoin denominations"
        case .fiatCurrency:
            return "Fiat currency"
        }
    }
}
