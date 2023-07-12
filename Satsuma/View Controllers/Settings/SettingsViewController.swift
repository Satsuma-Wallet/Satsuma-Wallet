//
//  SettingsViewController.swift
//  Satsuma
//
//  Created by Peter Denton on 5/8/23.
//

import UIKit
import StoreKit

class SettingsViewController: UIViewController, UINavigationControllerDelegate {
    
    var highFeeRate = 0
    var lowFeeRate = 0
    var standardFeeRate = 0
    var minimumFeeRate = 0
    let spinner = UIActivityIndicatorView(style: .medium)
    var fiatValues:[Fiat_Value] = []
    
    @IBOutlet weak var settingsTable: UITableView!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        settingsTable.delegate = self
        settingsTable.dataSource = self
        navigationController?.delegate = self
        navigationItem.title = "Settings"
    }
    
    override func viewDidAppear(_ animated: Bool) {
        spinner.startAnimating()
        MempoolRequest.sharedInstance.command(method: .fee) { [weak self] (response, errorDesc) in
            guard let self = self else { return }
            
            guard let response = response as? [String:Any] else { return }
            
            let recommendedFees = RecommendedFee(response)
            self.highFeeRate = recommendedFees.fastest
            self.standardFeeRate = recommendedFees.hour
            self.lowFeeRate = recommendedFees.economy
            self.minimumFeeRate = recommendedFees.minimum
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.spinner.stopAnimating()
                self.settingsTable.reloadData()
            }
        }
        
        FiatConverter.sharedInstance.getCurrencies { fiatValues in
            guard let fiatValues = fiatValues else { return }

            self.fiatValues = fiatValues
        }
    }
    
    private enum Section: Int {
        case network
        case fee
        case fiat
        case walletTools
        case links
    }
    
    func blankCell() -> UITableViewCell {
        let cell = UITableViewCell()
        cell.selectionStyle = .none
        cell.backgroundColor = #colorLiteral(red: 0.05172085258, green: 0.05855310153, blue: 0.06978280196, alpha: 1)
        return cell
    }
    
    private func torCell(_ indexPath: IndexPath) -> UITableViewCell {
        let torCell = settingsTable.dequeueReusableCell(withIdentifier: "torCell", for: indexPath)
        let torToggle = torCell.viewWithTag(1) as! UISwitch
        let torEnabled = UserDefaults.standard.object(forKey: "torEnabled") as? Bool ?? false
        torToggle.setOn(torEnabled, animated: false)
        torToggle.addTarget(self, action: #selector(toggleTor(_:)), for: .valueChanged)
        torCell.selectionStyle = .none
        return torCell
    }
    
    private func fiatCell(_ indexPath: IndexPath) -> UITableViewCell {
        let fiatCell = settingsTable.dequeueReusableCell(withIdentifier: "fiatCell", for: indexPath)
        let fiatLabel = fiatCell.viewWithTag(1) as! UILabel
        fiatLabel.text = UserDefaults.standard.object(forKey: "fiat") as? String ?? "USD"
        fiatCell.selectionStyle = .none
        return fiatCell
    }
    
    private func feeCell(_ indexPath: IndexPath) -> UITableViewCell {
        let feeCell = settingsTable.dequeueReusableCell(withIdentifier: "feeCell", for: indexPath)
        let feeLabel = feeCell.viewWithTag(1) as! UILabel
        let feePriority = UserDefaults.standard.object(forKey: "feePriority") as? String ?? "standard"
                
        switch feePriority {
        case "high":
            feeLabel.text = "High priority"
            if highFeeRate > 0 {
                feeLabel.text = "High priority ~\(highFeeRate) s/vB"
            }
            
        case "standard":
            feeLabel.text = "Standard priority"
            if standardFeeRate > 0 {
                feeLabel.text = "Standard priority ~\(standardFeeRate) s/vB"
            }
            
        case "low":
            feeLabel.text = "Low priority"
            if lowFeeRate > 0 {
                feeLabel.text = "Low priority ~\(lowFeeRate) s/vB"
            }
            
        case "minimum":
            feeLabel.text = "Minimum priority"
            if minimumFeeRate > 0 {
                feeLabel.text = "Minimum priority ~\(minimumFeeRate) s/vB"
            }
            
        default:
            break
        }
        
        feeCell.selectionStyle = .none
        
        return feeCell
    }
    
    private func recoveryCell(_ indexPath: IndexPath) -> UITableViewCell {
        let recoveryCell = settingsTable.dequeueReusableCell(withIdentifier: "recoveryCell", for: indexPath)
        let label = recoveryCell.viewWithTag(1) as! UILabel
        label.text = "Recover"
        recoveryCell.selectionStyle = .none
        return recoveryCell
    }
    
    private func blockExplorerCell(_ indexPath: IndexPath) -> UITableViewCell {
        let blockExplorerCell = settingsTable.dequeueReusableCell(withIdentifier: "blockExplorerCell", for: indexPath)
        let label = blockExplorerCell.viewWithTag(1) as! UILabel
        label.text = "Block explorer"
        blockExplorerCell.selectionStyle = .none
        return blockExplorerCell
    }
    
    private func blockchainCell(_ indexPath: IndexPath) -> UITableViewCell {
        let blockchainCell = settingsTable.dequeueReusableCell(withIdentifier: "blockchainCell", for: indexPath)
        let label = blockchainCell.viewWithTag(1) as! UILabel
        label.text = "Blockchain network"
        blockchainCell.selectionStyle = .none
        return blockchainCell
    }
    
    private func linkCell(_ indexPath: IndexPath) -> UITableViewCell {
        let linkCell = settingsTable.dequeueReusableCell(withIdentifier: "linkCell", for: indexPath)
        let label = linkCell.viewWithTag(1) as! UILabel
        let imageView = linkCell.viewWithTag(2) as! UIImageView
        imageView.layer.cornerRadius = 8
        linkCell.selectionStyle = .none
        
        switch indexPath.row {
        case 0:
            label.text = "Buy Bitcoin"
            imageView.image = .init(systemName: "bitcoinsign.circle")
            //imageView.tintColor = .systemOrange
        case 1:
            label.text = "Shop"
            imageView.image = .init(systemName: "cart.circle")
            //imageView.tintColor = .systemPurple
        case 2:
            label.text = "Send Feedback"
            imageView.image = .init(systemName: "envelope.circle")
            //imageView.tintColor = .systemGreen
        case 3:
            label.text = "Rate this app"
            imageView.image = .init(systemName: "heart.circle")
            //imageView.tintColor = .systemPink
        case 4:
            label.text = "Follow us on Twitter"
            imageView.image = #imageLiteral(resourceName: "twitter.png")
            //imageView.image = .init(systemName: "bird")
        case 5:
            label.text = "News"
            imageView.image = .init(systemName: "globe")
            //imageView.tintColor = .systemIndigo
        default:
            break
        }
        
        return linkCell
    }
    
    @objc func toggleTor(_ sender: UISwitch) {
        UserDefaults.standard.setValue(sender.isOn, forKey: "torEnabled")
        if !sender.isOn {
            TorClient.sharedInstance.resign()
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        switch segue.identifier {
        case "segueToFiatSetting":
            guard let vc = segue.destination as? FiatSettingTableViewController else { fallthrough }
            
            vc.fiatValues = fiatValues
            
        case "segueToFeeSetting":
            guard let vc = segue.destination as? FeeSettingTableViewController else { fallthrough }
            
            vc.highFeeRate = highFeeRate
            vc.lowFeeRate = lowFeeRate
            vc.standardFeeRate = standardFeeRate
            vc.minimumFeeRate = minimumFeeRate
            
        default:
            break
        }
    }
}

extension SettingsViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section) {
            
        case .network:
            return torCell(indexPath)
            
        case .fee:
            return feeCell(indexPath)
            
        case .fiat:
            return fiatCell(indexPath)
            
        case .walletTools:
            switch indexPath.row {
            case 0:
                return recoveryCell(indexPath)
            case 1:
                return blockExplorerCell(indexPath)
            case 2:
                return blockchainCell(indexPath)
            default:
                return blankCell()
            }
        
        case .links:
            return linkCell(indexPath)
            
        default:
            return blankCell()
        }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = UIView()
        header.backgroundColor = UIColor.clear
        header.frame = CGRect(x: 0, y: 0, width: view.frame.size.width - 32, height: 50)

        let textLabel = UILabel()
        textLabel.textAlignment = .left
        textLabel.font = UIFont.systemFont(ofSize: 17, weight: .regular)
        textLabel.frame = CGRect(x: 0, y: 0, width: 300, height: 50)

        if let section = Section(rawValue: section) {
            textLabel.text = headerName(for: section)
        }
        
        if section == 1 {
            spinner.frame = CGRect(x: tableView.frame.maxX - 65, y: 0, width: 44, height: 44)
            header.addSubview(spinner)
        }

        header.addSubview(textLabel)
        return header
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 50
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 54
    }
    
    private func headerName(for section: Section) -> String {
        switch section {
        case .network:
            return "Network"
        case .fee:
            return "Transaction fee"
        case .fiat:
            return "Fiat currency"
        case .walletTools:
            return "Wallet tools"
        case .links:
            return "Links"
        }
    } 
}

extension SettingsViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 5
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 3:
            return 3
        case 4:
            return 6
        default:
            return 1
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.section {
        case 4:
            switch indexPath.row {
            case 0:
                guard let url = URL(string: "https://satsumawallet.com/buy") else { return }
                UIApplication.shared.open(url)
                
            case 1:
                guard let url = URL(string: "https://satsumawallet.com/shop") else { return }
                UIApplication.shared.open(url)
                
            case 2:
                guard let url = URL(string: "https://satsumawallet.com/contact") else { return }
                UIApplication.shared.open(url)
                
            case 3:
                    if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                        DispatchQueue.main.async {
                            if #available(iOS 14.0, *) {
                                SKStoreReviewController.requestReview(in: scene)
                            } else {
                                SKStoreReviewController.requestReview()
                            }
                        }
                    }
                
            case 4:
                guard let url = URL(string: "https://twitter.com/SatsumaWallet") else { return }
                UIApplication.shared.open(url)
                
            case 5:
                guard let url = URL(string: "https://satsumawallet.com/blog") else { return }
                UIApplication.shared.open(url)
                
            default:
                break
            }
        default:
            break
        }
    }
}
