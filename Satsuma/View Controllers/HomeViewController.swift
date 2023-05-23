//
//  HomeViewController.swift
//  Satsuma
//
//  Created by Peter Denton on 5/8/23.
//

import UIKit
import LocalAuthentication

class HomeViewController: UIViewController, UINavigationControllerDelegate {
    
    @IBOutlet private weak var btcAmountLabel: UILabel!
    @IBOutlet private weak var fiatBalanceOutlet: UILabel!
    
    let spinner = UIActivityIndicatorView(style: .medium)
    var refreshButton = UIBarButtonItem()
    var dataRefresher = UIBarButtonItem()
    var satsumaLabel = UIBarButtonItem()
    var utxosConfirmed = true
    var navigatedToSend = false
    var initialLoad = true

    override func viewDidLoad() {
        super.viewDidLoad()
        if UserDefaults.standard.object(forKey: "torEnabled") == nil {
            UserDefaults.standard.setValue(true, forKey: "torEnabled")
        }
        navigationController?.delegate = self
        satsumaLabel.title = "Satsuma"
        navigationItem.setLeftBarButton(satsumaLabel, animated: true)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        CoreDataService.retrieveEntity(entityName: .wallets) { wallets in
            guard let wallets = wallets else { return }
            
            if wallets.count > 0 {
                WalletTools.shared.addXprv { [weak self] updated in
                    guard let self = self else { return }
                    guard updated else {
                        return
                    }
                    if navigatedToSend || initialLoad {
                        self.fetchBalance()
                        navigatedToSend = false
                        initialLoad = false
                    }
                }
            } else {
                self.promptForPassphrase()
            }
        }
    }
    
    @IBAction func backupAction(_ sender: Any) {
        let context = LAContext()
            var error: NSError?

            if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
                let reason = "Backup your wallet."

                context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) {
                    [weak self] success, authenticationError in
                    guard let self = self else { return }

                    DispatchQueue.main.async {
                        if success {
                            print("Unlocked.")
                        } else {
                            self.showAlert(title: "Authentication failed", message: "You could not be verified; please try again.")
                        }
                    }
                }
            } else {
                // no biometry
                self.showAlert(title: "Biometry unavailable", message: "Your device is not configured for biometric authentication.")
            }
    }
    
    private func promptForPassphrase() {
        CoreDataService.retrieveEntity(entityName: .wallets) { wallets in
            guard let wallets = wallets else { return }
            
            if wallets.count == 0 {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    let alert = UIAlertController(title: "Add a BIP39 passphrase?", message: "You can optionally add a passphrase (25th word) when creating your wallet.", preferredStyle: .alert)
                    
                    alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: { action in
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self else { return }
                            
                            self.performSegue(withIdentifier: "segueToPassphraseInput", sender: self)
                        }
                    }))
                    
                    alert.addAction(UIAlertAction(title: "No", style: .default, handler: { [weak self] action in
                        guard let self = self else { return }
                        WalletTools.shared.create(passphrase: "") { (message, created) in
                            guard created else {
                                self.showAlert(title: "Wallet creation failed.", message: message ?? "Unknown")
                                return
                            }
                                                        
                            self.fetchBalance()
                        }
                    }))
                    alert.popoverPresentationController?.sourceView = self.view
                    self.present(alert, animated: true, completion: nil)
                }
            }
        }
    }
    
    
    func addNavBarSpinner() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.spinner.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
            self.dataRefresher = UIBarButtonItem(customView: self.spinner)
            self.navigationItem.setRightBarButton(self.dataRefresher, animated: true)
            self.spinner.startAnimating()
            self.spinner.alpha = 1
        }
    }
    
    func removeLoader() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.spinner.stopAnimating()
            self.spinner.alpha = 0
            self.refreshButton = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(self.refreshData(_:)))
            self.navigationItem.setRightBarButton(self.refreshButton, animated: true)
        }
    }
    
    @objc func refreshData(_ sender: Any) {
        addNavBarSpinner()
        getBalanceNow()
    }
    
    private func fetchBalance() {
        addNavBarSpinner()
        CoreDataService.retrieveEntity(entityName: .wallets) { [weak self] wallets in
            guard let self = self else { return }
            
            let torEnabled = UserDefaults.standard.bool(forKey: "torEnabled")
            
            if !torEnabled {
                getBalanceNow()
            } else {
                switch TorClient.sharedInstance.state {
                case .none, .stopped:
                    TorClient.sharedInstance.start(delegate: self)
                default:
                    break
                }
            }
        }        
    }
    
    private func getBalanceNow() {
        WalletTools.shared.refillKeypool { [weak self] done in
            guard let self = self else { return }
            
            guard done else {
                self.removeLoader()
                self.showAlert(title: "", message: "Refill keypool failed.")
                return
            }
            
            WalletTools.shared.updateCoreData { [weak self] (message, success) in
                guard let self = self else { return }
                
                guard success else {
                    self.removeLoader()
                    self.showAlert(title: "Updating local data failed.", message: message ?? "Unknown.")
                    return
                }
                
                CoreDataService.retrieveEntity(entityName: .utxos) { utxos in
                    guard let utxos = utxos else { return }
                    
                    var balance = 0.0
                    self.utxosConfirmed = true
                    
                    for utxo in utxos {
                        let utxo = Utxo_Cache(utxo)
                        if !utxo.confirmed {
                            self.utxosConfirmed = false
                        }
                        balance += utxo.doubleValueSats
                    }
                    var textBalance = balance.btcAmountDouble.rounded(toPlaces: 8).avoidNotation
                    if balance == 0 {
                        textBalance = "0.00000000 BTC"
                    }
                    self.showBtcBalance(balance: textBalance)
                    self.getFxRate(balance: balance)
                }
            }
        }
    }
    
    private func showBtcBalance(balance: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.btcAmountLabel.text = balance
        }
    }
    
    private func getFxRate(balance: Double) {
        FiatConverter.sharedInstance.getFxRate { [weak self] fxRate in
            guard let self = self else { return }
            guard let fxRate = fxRate else {
                self.removeLoader()
                self.showAlert(title: "", message: "Unable to fetch the fiat exchange rate.")
                return
            }
            var textBalance = "$\((balance.btcAmountDouble * fxRate).rounded(toPlaces: 2).avoidNotation) USD"
            if balance == 0 {
                textBalance = "0.00 USD"
            }
            if utxosConfirmed {
                showFiatBalance(balance: textBalance)
            } else {
                showFiatBalance(balance: textBalance + "\n(pending confirmation)")
            }
        }
    }
    
    private func showFiatBalance(balance: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.fiatBalanceOutlet.text = balance
            self.removeLoader()
        }
    }
    
    private func delete() {
//        CoreDataService.deleteAllData(entity: .wallets) { deleted in
//            print("deleted: \(deleted)")
//        }
//        CoreDataService.deleteAllData(entity: .receiveAddr) { deleted in
//            print("deleted: \(deleted)")
//        }
//        CoreDataService.deleteAllData(entity: .changeAddr) { deleted in
//            print("deleted: \(deleted)")
//        }
        CoreDataService.deleteAllData(entity: .utxos) { deleted in
            print("utxo deleted: \(deleted)")
        }
        
    }
    

    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        switch segue.identifier {
        case "segueToSend":
            navigatedToSend = true
        default:
            break
        }
    }
    

}

extension HomeViewController: OnionManagerDelegate {
    
    func torConnProgress(_ progress: Int) {
        print("progress: \(progress)")
    }
    
    func torConnFinished() {
        print("tor connnected")
        getBalanceNow()
    }
    
    func torConnDifficulties() {
        print("tor connection difficulties")
        removeLoader()
        self.showAlert(title: "", message: "Tor connection issue...")
    }
}
