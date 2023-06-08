//
//  HomeViewController.swift
//  Satsuma
//
//  Created by Peter Denton on 5/8/23.
//

import UIKit

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
    var hasUnlocked = false

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setDefaults()
        navigationController?.delegate = self
        satsumaLabel.title = "Satsuma"
        navigationItem.setLeftBarButton(satsumaLabel, animated: true)
        view.alpha = 0
    }
    
    override func viewDidAppear(_ animated: Bool) {
        CoreDataService.retrieveEntity(entityName: .pin) { [weak self] pins in
            guard let self = self else { return }
            
            guard let pins = pins else { return }
            
            if pins.count == 0 {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    hasUnlocked = true
                    performSegue(withIdentifier: "segueToPinCreation", sender: self)
                }
            } else if !self.hasUnlocked {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    performSegue(withIdentifier: "segueToUnlock", sender: self)
                }
            } else {
                view.alpha = 1
                // When the view appears we check if any wallets exist.
                CoreDataService.retrieveEntity(entityName: .wallets) { [weak self] wallets in
                    guard let self = self else { return }
                    
                    guard let wallets = wallets else { return }
                    
                    if wallets.count > 0 {
                        // A wallet exists.
                        // If the user navigated back from the send flow or it is the initial load we check for new/consumed utxos and update the balance.
                        if self.navigatedToSend || self.initialLoad {
                            self.fetchBalance()
                            self.navigatedToSend = false
                            self.initialLoad = false
                        }
                    } else {
                        // No wallet exists so we first ask if a BIP39 passphrase is to be used.
                        self.promptForPassphrase()
                    }
                }
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        NotificationCenter.default.addObserver(self, selector: #selector(walletRecovered(_:)), name: Notification.Name(rawValue: "walletRecovered"), object: nil)
    }
    
    @objc func walletRecovered(_ notification: Notification) {
        showBalanceFromCache()
    }
    
    // The "Wallet backup" button action. It does not do anything yet except for a biometry authentication.
    @IBAction func backupAction(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.performSegue(withIdentifier: "segueToBackup", sender: self)
        }
    }
    
    // Sets the defaults.
    private func setDefaults() {
        if UserDefaults.standard.object(forKey: "torEnabled") == nil {
            UserDefaults.standard.setValue(false, forKey: "torEnabled")
        }
        if UserDefaults.standard.object(forKey: "feePriority") == nil {
            UserDefaults.standard.setValue("standard", forKey: "feePriority")
        }
        if UserDefaults.standard.object(forKey: "fiat") == nil {
            UserDefaults.standard.setValue("USD", forKey: "fiat")
        }
        if UserDefaults.standard.object(forKey: "denomination") == nil {
            UserDefaults.standard.setValue("BTC", forKey: "denomination")
        }
        if UserDefaults.standard.object(forKey: "url") == nil {
            UserDefaults.standard.setValue("https://blockstream.info/testnet/api", forKey: "url")
        }
    }
    
    // Initiates wallet creation.
    private func promptForPassphrase() {
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
                // Creates a wallet without a passphrase.
        
                WalletTools.shared.create(passphrase: "") { (message, created) in
                    guard created else {
                        self.showAlert(title: "Wallet creation failed.", message: message ?? "Unknown")
                        return
                    }
                    // Once the wallet is created we update our utxo database.
                    self.fetchBalance()
                }
            }))
            
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    // Shows the spinner in top right whenever the app is doing something.
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
    
    // Removes the spinner.
    func removeLoader() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.spinner.stopAnimating()
            self.spinner.alpha = 0
            self.refreshButton = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(self.refreshData(_:)))
            self.navigationItem.setRightBarButton(self.refreshButton, animated: true)
        }
    }
    
    // The refresh button action.
    @objc func refreshData(_ sender: Any) {
        addNavBarSpinner()
        fetchBalance()
    }
    
    // Fetches the wallets balance.
    private func fetchBalance() {
        // Firts we display the balance from our cache.
        showBalanceFromCache()
        addNavBarSpinner()
        
        let torEnabled = UserDefaults.standard.bool(forKey: "torEnabled")
        
        if !torEnabled {
            // Tor is off so we fetch utxos over clearnet.
            getBalanceNow()
        } else {
            // Tor is enabled so we need to check if it is actually running yet, if not we start Tor.
            switch TorClient.sharedInstance.state {
            case .none, .stopped:
                // See the delegate methods at the bottom of this file.
                TorClient.sharedInstance.start(delegate: self)
            case .connected:
                getBalanceNow()
            default:
                break
            }
        }
    }
    
    // Starts the process of fetching our updated balance.
    private func getBalanceNow() {
        // Need to start the process off by checking to see if the keypool needs more keys, if it does we refill the keypool before querying addresses for utxos.
        WalletTools.shared.refillKeypool { [weak self] done in
            guard let self = self else { return }
            
            guard done else {
                self.removeLoader()
                self.showAlert(title: "", message: "Refill keypool failed.")
                return
            }
            
            // Keypool refill check completed, now we can check for utxos.
            WalletTools.shared.updateCoreData { [weak self] (message, success) in
                guard let self = self else { return }
                
                guard success else {
                    self.removeLoader()
                    self.showAlert(title: "Updating local data failed.", message: message ?? "Unknown.")
                    return
                }
                
                // Our local database of utxos has been updated, now we can display our balance.
                CoreDataService.retrieveEntity(entityName: .utxos) { utxos in
                    guard let utxos = utxos else { return }
                    
                    var balance = 0.0
                    self.utxosConfirmed = true
                    
                    // Loop through each utxo and tally up our balance, checking the confirmed status for each.
                    for utxo in utxos {
                        let utxo = Utxo_Cache(utxo)
                        if !utxo.confirmed {
                            self.utxosConfirmed = false
                        }
                        balance += utxo.doubleValueSats
                    }
                    
                    // Displays our balance.
                    self.showBtcBalance(balance: balance.btcBalance)
                    
                    // Fetches the exchange rate.
                    self.getFxRate(balance: balance)
                }
            }
        }
    }
    
    // Displays our balance from local memory.
    private func showBalanceFromCache() {
        CoreDataService.retrieveEntity(entityName: .utxos) { [weak self] utxos in
            guard let self = self, let utxos = utxos else { return }
            
            var balance = 0.0
            self.utxosConfirmed = true
            
            for utxo in utxos {
                let utxo = Utxo_Cache(utxo)
                if !utxo.confirmed {
                    self.utxosConfirmed = false
                }
                balance += utxo.doubleValueSats
            }
            
            self.showBtcBalance(balance: balance.btcBalance)
        }
    }
    
    // Updates the UI to show the balance.
    private func showBtcBalance(balance: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.btcAmountLabel.text = balance
        }
    }
    
    // Fetches the exchange rate based on the currency code the user selected in settings.
    private func getFxRate(balance: Double) {
        let fiat = UserDefaults.standard.object(forKey: "fiat") as? String ?? "USD"
        
        FiatConverter.sharedInstance.getFxRate(currency: fiat) { [weak self] fxRate in
            guard let self = self else { return }
            guard let fxRate = fxRate else {
                self.removeLoader()
                self.showAlert(title: "", message: "Unable to fetch the fiat exchange rate.")
                return
            }
            
            // Converts the exchange rate to the string used to display the fiat balance.
            let fiatBalance = balance.btcAmountDouble.fiatBalance(fxRate: fxRate)
            
            if utxosConfirmed {
                showFiatBalance(balance: fiatBalance)
            } else {
                showFiatBalance(balance: fiatBalance + "\n(pending confirmation)")
            }
        }
    }
    
    // Updates the UI to display the fiat balance.
    private func showFiatBalance(balance: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.fiatBalanceOutlet.text = balance
            self.removeLoader()
        }
    }
    
    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // So we know if the user navigated to the send view to update our balance automatically in case they actually sent btc.
        switch segue.identifier {
        case "segueToSend":
            navigatedToSend = true
            
        case "segueToUnlock":
            guard let vc = segue.destination as? PinEntryViewController else { fallthrough }
            
            vc.onDoneBlock = { [weak self] _ in
                guard let self = self else { return }
                
                self.hasUnlocked = true
            }
        default:
            break
        }
    }
}

// This connects our ViewController to the Tor Manager and lets us know when Tor has finished bootstrapping, or not.
extension HomeViewController: OnionManagerDelegate {
    
    // Gets the bootstrapping progress, we can display this in the UI.
    func torConnProgress(_ progress: Int) {
        print("progress: \(progress)")
    }
    
    // Tor connected successfully, we can fetch our utxos now.
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
