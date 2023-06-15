//
//  BlockExplorerTableViewController.swift
//  Satsuma
//
//  Created by Peter Denton on 6/8/23.
//

import UIKit

class BlockExplorerTableViewController: UITableViewController, UITextFieldDelegate {
    
    var urls:[[String:String]] = []
    var customUrls:[String] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        
        urls = [
            [
                "mempool.space": "https://mempool.space/testnet/api"
            ],
            [
                "blockstream.info": "https://blockstream.info/testnet/api"
            ]
        ]
        
        let torEnabled = UserDefaults.standard.object(forKey: "torEnabled") as! Bool
        
        if let network = UserDefaults.standard.object(forKey: "blockchain") as? String {
            if network == "Testnet" {
                if torEnabled {
                    urls = [
                        [
                            "blockstream.info (via tor)": "http://explorerzydxu5ecjrkwceayqybizmpjjznk5izmitf2modhcusuqlid.onion/testnet/api"
                        ],
                        [
                            "mempool.space (via tor)": "http://mempoolhqx4isw62xs7abwphsq7ldayuidyx2v2oethdhhj6mlo2r6ad.onion/testnet/api"
                        ]
                    ]
                }
            } else {
                if torEnabled {
                    urls = [
                        [
                            "blockstream.info (via tor)": "http://explorerzydxu5ecjrkwceayqybizmpjjznk5izmitf2modhcusuqlid.onion/api"
                        ],
                        [
                            "mempool.space (via tor)": "http://mempoolhqx4isw62xs7abwphsq7ldayuidyx2v2oethdhhj6mlo2r6ad.onion/api"
                        ]
                    ]
                } else {
                    urls = [
                        [
                            "mempool.space": "https://mempool.space/api"
                        ],
                        [
                            "blockstream.info": "https://blockstream.info/api"
                        ]
                    ]
                }
            }
        }
        
        let customUrl = UserDefaults.standard.object(forKey: "customUrl") as? String ?? ""
        customUrls.append(customUrl)
    }

    // MARK: - Table view data source
    
    private enum Section: Int {
        case standard
        case custom
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        switch section {
        case 0:
            return urls.count
        case 1:
            return 1
        default:
            return 0
        }
        
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            let urlCell = tableView.dequeueReusableCell(withIdentifier: "urlCell", for: indexPath)
            let selectedUrl = UserDefaults.standard.object(forKey: "url") as? String ?? urls[2]["blockstream.info"]
            let url = urls[indexPath.row]
            
            for (key, value) in url {
                urlCell.textLabel!.text = key
                
                if value == selectedUrl {
                    urlCell.setSelected(true, animated: true)
                    urlCell.textLabel!.alpha = 1
                    urlCell.accessoryType = .checkmark
                } else {
                    urlCell.setSelected(false, animated: true)
                    urlCell.textLabel!.alpha = 0.2
                    urlCell.accessoryType = .none
                }
            }
            
            return urlCell
            
        case 1:
            let customUrlCell = tableView.dequeueReusableCell(withIdentifier: "customUrlCell", for: indexPath)
            let customUrl = customUrls[0]
            let textField = customUrlCell.viewWithTag(1) as! UITextField
            textField.text = customUrl
            let selectedUrl = UserDefaults.standard.object(forKey: "url") as? String ?? urls[2]["blockstream.info"]
            
            if customUrl == selectedUrl {
                customUrlCell.setSelected(true, animated: true)
                customUrlCell.textLabel!.alpha = 1
                customUrlCell.accessoryType = .checkmark
            } else {
                customUrlCell.setSelected(false, animated: true)
                customUrlCell.textLabel!.alpha = 0.2
                customUrlCell.accessoryType = .none
            }
            
            return customUrlCell
            
        default:
            return blankCell()
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.section {
        case 0:
            let url = urls[indexPath.row]
            for (_, value) in url {
                UserDefaults.standard.set(value, forKey: "url")
            }
            
        case 1:
            if customUrls[0] != "" {
                UserDefaults.standard.set(customUrls[0], forKey: "customUrl")
                UserDefaults.standard.set(customUrls[0], forKey: "url")
            }
            
        default:
            break
        }
        
        tableView.reloadData()
    }
    
    override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        switch indexPath.section {
        case 1:
            let cell = tableView.cellForRow(at: indexPath)!
            cell.setSelected(false, animated: true)
            cell.textLabel!.alpha = 0.2
            cell.accessoryType = .none
            
        default:
            break
        }
        
        tableView.reloadData()
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 50
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
    
    private func headerName(for section: Section) -> String {
        switch section {
        case .standard:
            return "Public servers"
        case .custom:
            return "Private server"
        }
    } 
    
    private func blankCell() -> UITableViewCell {
        let cell = UITableViewCell()
        cell.selectionStyle = .none
        cell.backgroundColor = #colorLiteral(red: 0.05172085258, green: 0.05855310153, blue: 0.06978280196, alpha: 1)
        return cell
    }

}
