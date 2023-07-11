//
//  BlockchainTableViewController.swift
//  Satsuma
//
//  Created by Peter Denton on 6/9/23.
//

import UIKit

class BlockchainTableViewController: UITableViewController, UINavigationControllerDelegate {

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
        return 2
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let blockchainCell = tableView.dequeueReusableCell(withIdentifier: "blockchainCell", for: indexPath)
        let label = blockchainCell.viewWithTag(1) as! UILabel
        let blockchain = UserDefaults.standard.object(forKey: "blockchain") as? String ?? "Mainnet"
        blockchainCell.selectionStyle = .none
        
        switch indexPath.row {
        case 0:
            label.text = "Testnet"
            if blockchain == "Testnet" {
                blockchainCell.setSelected(true, animated: true)
                blockchainCell.accessoryType = .checkmark
            } else {
                blockchainCell.setSelected(false, animated: true)
                blockchainCell.accessoryType = .none
            }
        case 1:
            label.text = "Mainnet"
            if blockchain == "Mainnet" {
                blockchainCell.setSelected(true, animated: true)
                blockchainCell.accessoryType = .checkmark
            } else {
                blockchainCell.setSelected(false, animated: true)
                blockchainCell.accessoryType = .none
            }
            
        default:
            return blankCell()
        }
        
        return blockchainCell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.row {
        case 0:
            promptToChangeNetwork(network: "Testnet")
        case 1:
            promptToChangeNetwork(network: "Mainnet")
        default:
            break
        }
    }
    
    private func promptToChangeNetwork(network: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let alert = UIAlertController(title: "Create a new \(network) wallet?", message: "This will delete your existing wallet!", preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "Create \(network) wallet", style: .destructive, handler: { action in
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    UserDefaults.standard.set(network, forKey: "blockchain")
                    
                    let server = UserDefaults.standard.value(forKey: "url") as? String ?? ""
                    let customServer = UserDefaults.standard.value(forKey: "customUrl") as? String ?? ""
                    let torEnabled = UserDefaults.standard.object(forKey: "torEnabled") as? Bool ?? false
                    var url = ""
                    
                    if customServer == server {
                        showAlert(title: "You are using a custom server.", message: "Ensure your server is running on the same network otherwise you will get an error.")
                    } else {
                        if network == "Testnet" {
                            if torEnabled {
                                url = "http://mempoolhqx4isw62xs7abwphsq7ldayuidyx2v2oethdhhj6mlo2r6ad.onion/testnet/api"
                            } else {
                                url = "https://mempool.space/testnet/api"
                            }
                        } else {
                            if torEnabled {
                                url = "http://mempoolhqx4isw62xs7abwphsq7ldayuidyx2v2oethdhhj6mlo2r6ad.onion/api"
                            } else {
                                url = "https://mempool.space/api"
                            }
                        }
                    }
                    
                    UserDefaults.standard.set(url, forKey: "url")
                    
                    CoreDataService.deleteAllData(entity: .wallets) { walletsDeleted in
                        guard walletsDeleted else { return }
                        
                        CoreDataService.deleteAllData(entity: .utxos) { utxosDeleted in
                            guard utxosDeleted else { return }
                            
                            CoreDataService.deleteAllData(entity: .receiveAddr) { recKeypoolDeleted in
                                guard recKeypoolDeleted else { return }
                                
                                CoreDataService.deleteAllData(entity: .changeAddr) { [weak self] changeKeypoolDeleted in
                                    guard let self = self else { return }
                                    guard changeKeypoolDeleted else { return }
                                    self.navigationController?.popToRootViewController(animated: true)
                                    self.tabBarController?.selectedIndex = 0
                                }
                            }
                        }                        
                    }
                }
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in }))
            
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func blankCell() -> UITableViewCell {
        let cell = UITableViewCell()
        cell.selectionStyle = .none
        cell.backgroundColor = #colorLiteral(red: 0.05172085258, green: 0.05855310153, blue: 0.06978280196, alpha: 1)
        return cell
    }

}
