//
//  BlockExplorerTableViewController.swift
//  Satsuma
//
//  Created by Peter Denton on 6/8/23.
//

import UIKit

class BlockExplorerTableViewController: UITableViewController, UITextFieldDelegate {
    
    let urls:[[String:String]] = [
        [
            "Blockstream Testnet - Tor": "http://explorerzydxu5ecjrkwceayqybizmpjjznk5izmitf2modhcusuqlid.onion/testnet/api"
        ],
        [
            "Mempool Space - Tor": "http://mempoolhqx4isw62xs7abwphsq7ldayuidyx2v2oethdhhj6mlo2r6ad.onion/api/v1"
        ],
        [
            "Blockstream Testnet - Clearnet": "https://blockstream.info/testnet/api"
        ],
        [
            "Mempool Space - Clearnet": "https://mempool.space/api/v1"
        ],
        [
            "Custom": UserDefaults.standard.object(forKey: "customUrl") as? String ?? ""
        ]
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return urls.count
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let urlCell = tableView.dequeueReusableCell(withIdentifier: "urlCell", for: indexPath)
        let url = UserDefaults.standard.object(forKey: "url") as? String ?? urls[2]["Blockstream Testnet - Clearnet"]
        
        let customUrlCell = tableView.dequeueReusableCell(withIdentifier: "customUrlCell", for: indexPath)
        let customUrl = UserDefaults.standard.object(forKey: "customUrl") as? String ?? ""
                
        switch indexPath.row {
        case 0:
            let textField = customUrlCell.viewWithTag(1) as! UITextField
            let label = customUrlCell.viewWithTag(2) as! UILabel
            textField.delegate = self
            textField.text = customUrl
            label.text = "Custom"
            
            if customUrl == url {
                customUrlCell.setSelected(true, animated: true)
                label.alpha = 1
                customUrlCell.accessoryType = .checkmark
            } else {
                customUrlCell.setSelected(false, animated: true)
                label.alpha = 0.2
                customUrlCell.accessoryType = .none
            }
            
            return customUrlCell
            
        case 1:
            urlCell.textLabel!.text = "Blockstream Testnet - Tor"
            
            if urls[0]["Blockstream Testnet - Tor"] == url {
                urlCell.setSelected(true, animated: true)
                urlCell.textLabel!.alpha = 1
                urlCell.accessoryType = .checkmark
            } else {
                urlCell.setSelected(false, animated: true)
                urlCell.textLabel!.alpha = 0.2
                urlCell.accessoryType = .none
            }
            
            return urlCell
            
        case 2:
            urlCell.textLabel!.text = "Mempool Space - Tor"
            
            if urls[1]["Mempool Space - Tor"] == url {
                urlCell.setSelected(true, animated: true)
                urlCell.textLabel!.alpha = 1
                urlCell.accessoryType = .checkmark
            } else {
                urlCell.setSelected(false, animated: true)
                urlCell.textLabel!.alpha = 0.2
                urlCell.accessoryType = .none
            }
            
            return urlCell
            
        case 3:
            urlCell.textLabel!.text = "Blockstream Testnet - Clearnet"
            
            if urls[2]["Blockstream Testnet - Clearnet"] == url {
                urlCell.setSelected(true, animated: true)
                urlCell.textLabel!.alpha = 1
                urlCell.accessoryType = .checkmark
            } else {
                urlCell.setSelected(false, animated: true)
                urlCell.textLabel!.alpha = 0.2
                urlCell.accessoryType = .none
            }
            
            return urlCell
            
        case 4:
            urlCell.textLabel!.text = "Mempool Space - Clearnet"
            
            if urls[3]["Mempool Space - Clearnet"] == url {
                urlCell.setSelected(true, animated: true)
                urlCell.textLabel!.alpha = 1
                urlCell.accessoryType = .checkmark
            } else {
                urlCell.setSelected(false, animated: true)
                urlCell.textLabel!.alpha = 0.2
                urlCell.accessoryType = .none
            }
            
            return urlCell
            
        default:
            return blankCell()
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.row {
        case 0:
            UserDefaults.standard.set(urls[4]["Custom"], forKey: "url")
            
        case 1:
            UserDefaults.standard.set(urls[0]["Blockstream Testnet - Tor"], forKey: "url")
            
        case 2:
            UserDefaults.standard.set(urls[1]["Mempool Space - Tor"], forKey: "url")
            
        case 3:
            UserDefaults.standard.set(urls[2]["Blockstream Testnet - Clearnet"], forKey: "url")
            
        case 4:
            UserDefaults.standard.set(urls[3]["Mempool Space - Clearnet"], forKey: "url")
            
        default:
            break
        }
        
        tableView.reloadData()
    }
    
    private func blankCell() -> UITableViewCell {
        let cell = UITableViewCell()
        cell.selectionStyle = .none
        cell.backgroundColor = #colorLiteral(red: 0.05172085258, green: 0.05855310153, blue: 0.06978280196, alpha: 1)
        return cell
    }

}
