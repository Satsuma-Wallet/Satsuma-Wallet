//
//  AmountInputViewController.swift
//  Satsuma
//
//  Created by Peter Denton on 5/11/23.
//

import UIKit

class AmountInputViewController: UIViewController, UITextFieldDelegate {
    
    var address = ""
    var btcAmountToSend = 0.0
    var fiatBalance = 0.0
    var btcBalance = 0.0
    var satsBalance = 0.0
    var fxRate = 0.0
    var rawTx = ""
    var fee = 0
    var buttonConstraint: NSLayoutConstraint!
    var denomination = UserDefaults.standard.object(forKey: "denomination") as? String ?? "BTC"
    var fiat = UserDefaults.standard.object(forKey: "fiat") as? String ?? "USD"
    
    @IBOutlet weak var amountInput: UITextField!
    @IBOutlet weak var fiatButtonOutlet: UIButton!
    @IBOutlet weak var balanceOutlet: UILabel!
    @IBOutlet weak var addressOutlet: UILabel!
    @IBOutlet weak var sendOutlet: UIButton!
    @IBOutlet weak var addressView: AddressView!
    @IBOutlet weak var denominationOutlet: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        configureViews()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        // Displays the keyboard.
        amountInput.becomeFirstResponder()
        
        // Refreshes our values incase the user tapped the denomination button and changed the setting.
        denomination = UserDefaults.standard.object(forKey: "denomination") as? String ?? "BTC"
        fiat = UserDefaults.standard.object(forKey: "fiat") as? String ?? "USD"
        
        // Ensure values do not double everytime user taps the denomination button and navigates back.
        fiatBalance = 0.0
        btcBalance = 0.0
        satsBalance = 0.0
        fxRate = 0.0
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Updates the denomation value on the denomination button.
            self.denominationOutlet.setTitle(denomination, for: .normal)
            
            // Gets our total balance.
            self.getBalance()
        }
    }
    
    // "Use all funds" button action.
    @IBAction func useAllFundsAction(_ sender: Any) {
        // Dismisses the keyboard.
        amountInput.resignFirstResponder()
        
        // Shows the spinner.
        self.addSpinnerView(description: "fetching recommended fee...")
        
        // Creates a sweep transaction to the specified address.
        WalletTools.shared.sweepWallet(destinationAddress: address) { [weak self] (message, rawTx) in
            guard let self = self else { return }
            guard let rawTx = rawTx else {
                self.showAlert(title: "", message: message ?? "Uknown.")
                return
            }
            self.removeSpinnerView()
            
            // Set our variables here so we can pass them to the "confirm" view controller.
            // MARK: TODO - Add fee rate.
            self.rawTx = rawTx.rawTx /// The raw tx in hex. Used for broadcasting.
            self.fee = rawTx.fee /// The tx fee in sats.
            self.btcAmountToSend = rawTx.amount /// The destination amount in btc.
            
            // Navigates us to the "confirm" view.
            DispatchQueue.main.async {
                self.performSegue(withIdentifier: "segueToSend", sender: self)
            }
        }
    }
    
    // Shows the address detail view. The "eye" button action.
    @IBAction func seeFullAddressAction(_ sender: Any) {
        addressView.alpha = 1
    }
    
    // Configures all of our views before the view dislays.
    private func configureViews() {
        configureAmountInput()
        configureSendButton()
        confirgureAddressLabel()
        view.layoutIfNeeded()
        subscribeToShowKeyboardNotifications()
        addTapGesture()
        denominationOutlet.setTitle(denomination, for: .normal)
    }
    
    // Configure the text input for the amount.
    private func configureAmountInput() {
        amountInput.delegate = self
        
        // Allows us to check the value of the input everytime it changes. So we can show the "confirm" button when suitable.
        amountInput.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        
        // If a bip21 invoice was scanned we automatically fill the amount in so the user can confirm it.
        if btcAmountToSend > 0 {
            amountInput.text = "\(btcAmountToSend)"
        }
    }
    
    // Confirgures the address detail view and the address label.
    private func confirgureAddressLabel() {
        addressView.alpha = 0
        addressView.address.text = address
        addressView.derivation.alpha = 0
        addressView.balance.alpha = 0
        
        if address != "" {
            addressOutlet.text = address
        }
    }
    
    // Configures the send button so that it appears just above the keyboard.
    private func configureSendButton() {
        sendOutlet.translatesAutoresizingMaskIntoConstraints = false
        sendOutlet.addTarget(self, action: #selector(buttonAction), for: .touchUpInside)
        sendOutlet.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 40).isActive = true
        sendOutlet.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -40).isActive = true
        sendOutlet.heightAnchor.constraint(equalToConstant: 50).isActive = true
        sendOutlet.isEnabled = false
        sendOutlet.alpha = 0
        buttonConstraint = sendOutlet.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10)
        buttonConstraint.isActive = true
        view.addSubview(sendOutlet)
    }
    
    // Gets our total balance from our local database to display it.
    private func getBalance() {
        CoreDataService.retrieveEntity(entityName: .utxos) { [weak self] utxos in
            guard let self = self else { return }
            
            guard let utxos = utxos, utxos.count > 0 else { return }
            for utxo in utxos {
                let utxo = Utxo_Cache(utxo)
                
                // Ensures only confirmed utxos are included in this balance as we can not spend unconfirmed utxos.
                if utxo.confirmed {
                    // To show our total balance in sats.
                    self.satsBalance += utxo.doubleValueSats
                    
                    // To show our total balnce in btc.
                    self.btcBalance += utxo.doubleValueSats.btcAmountDouble
                }
            }
            
            var balanceText = ""
            
            // Checks the denomination the user selected or the default.
            switch denomination {
            case "BTC":
                // Shows balance in btc.
                balanceText = satsBalance.btcBalance
                self.showBalance(balance: balanceText)
                
            case "SAT":
                // Shows balance in sats.
                balanceText = satsBalance.avoidNotation
                self.showBalance(balance: balanceText)
                
            default:
                // Shows the balance in fiat depending on the user selection in settings.
                FiatConverter.sharedInstance.getFxRate(currency: fiat) { [weak self] fxRate in
                    guard let self = self else { return }
                    
                    guard let fxRate = fxRate else {
                        self.showAlert(title: "", message: "Unable to fetch the exchange rate.")
                        return
                    }
                    
                    self.fxRate = fxRate
                    self.fiatBalance = btcBalance * fxRate
                    balanceText = self.btcBalance.fiatBalance(fxRate: fxRate)
                    self.showBalance(balance: balanceText)
                }
            }
            
            // If an amount exists whe check if we should show the send button.
            if btcAmountToSend > 0, btcAmountToSend < self.btcBalance {
                self.showSendButton()
            }
        }
    }
    
    // Updates the UI to show the balance.
    private func showBalance(balance: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.balanceOutlet.text = "Balance: \(balance)"
        }
    }
    
    // Calls textFieldDidEndEditing when the return/done button is tapped on the keyboard.
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.endEditing(true)
        return true
    }
    
    // User tapped return or done on the keyboard, check if the amount is less then the available funds.
    func textFieldDidEndEditing(_ textField: UITextField) {
        // Dismisses the keyboard.
        textField.resignFirstResponder()
        
        // Ensures something was input.
        guard let text = textField.text, text != "" else {
            return
        }
        
        // Checks which denomination we are working with and converts it to btc to build the tx.
        switch denomination {
        case "BTC":
            // Checks if the btc amount entered is less then the total balance.
            if text.doubleValue > 0, text.doubleValue < btcBalance {
                btcAmountToSend = text.doubleValue
                showSendButton()
            } else {
                sendOutlet.isEnabled = false
                self.showAlert(title: "", message: "Insufficient funds, try a lower amount.")
            }
            
        case "SAT":
            // Checks if the sat amount entered is less then the total balance.
            if text.doubleValue > 0, text.doubleValue < satsBalance {
                btcAmountToSend = text.doubleValue.btcAmountDouble
                showSendButton()
            } else {
                sendOutlet.isEnabled = false
                self.showAlert(title: "", message: "Insufficient funds, try a lower amount.")
            }
            
        default:
            // Checks if the fiat amount entered is less then the total balance.
            if text.doubleValue > 0, text.doubleValue < fiatBalance {
                btcAmountToSend = text.doubleValue / self.fxRate
                showSendButton()
            } else {
                sendOutlet.isEnabled = false
                self.showAlert(title: "", message: "Insufficient funds, try a lower amount.")
            }
        }
    }
    
    // So we know where to put the send button depending on whether the keyboard is showing or not.
    func subscribeToShowKeyboardNotifications() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardWillShow(_:)),
                                               name: UIResponder.keyboardWillShowNotification,
                                               object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardWillHide(_:)),
                                               name: UIResponder.keyboardWillHideNotification,
                                               object: nil)
    }
    
    // To set the specific location of the send button via the "buttonConstraint" variable when the keyboard shows.
    @objc func keyboardWillShow(_ notification: Notification) {
        let userInfo = notification.userInfo
        let keyboardSize = userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as! NSValue
        let keyboardHeight = keyboardSize.cgRectValue.height - 80
        buttonConstraint.constant = -10 - keyboardHeight

        let animationDuration = userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as! Double
        UIView.animate(withDuration: animationDuration) {
            self.view.layoutIfNeeded()
        }
    }
    
    // To set the specific location of the send button via the "buttonConstraint" variable when the keyboard hides.
    @objc func keyboardWillHide(_ notification: Notification) {
        buttonConstraint.constant = -10

        let userInfo = notification.userInfo
        let animationDuration = userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as! Double
        UIView.animate(withDuration: animationDuration) {
            self.view.layoutIfNeeded()
        }
    }
    
    // Added so the keyboard dismisses when a user taps the screen.
    func addTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard (_:)))
        tapGesture.numberOfTapsRequired = 1
        self.view.addGestureRecognizer(tapGesture)
    }
    
    // Dismisses the keyboard.
    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        amountInput.resignFirstResponder()
    }
    
    // Shows the send button.
    private func showSendButton() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.sendOutlet.alpha = 1
            self.sendOutlet.isEnabled = true
        }
    }
    
    // The send button action.
    @objc func buttonAction() {
        amountInput.resignFirstResponder()
        createTx()
    }
    
    // Creates the transaction.
    private func createTx() {
        // Dismisses the keyboard.
        amountInput.resignFirstResponder()
        
        // Adds spinner.
        self.addSpinnerView(description: "fetching recommended fee...")
        
        // Fetches our wallet.
        CoreDataService.retrieveEntity(entityName: .wallets) { wallets in
            guard let wallets = wallets else { return }
            
            // Our wallet.
            let wallet = Wallet(wallets[0])
            
            // Fetches a change address as this is not a sweep.
            CoreDataService.retrieveEntity(entityName: .changeAddr) { [weak self] changeAddresses in
                guard let self = self else { return }
                
                guard let changeAddresses = changeAddresses else {
                    self.removeSpinnerView()
                    self.showAlert(title: "", message: "No change addresses available.")
                    return
                }
                
                var changeAddressToUse:Address_Cache?
                
                // Loops through our change addresses to fetch one that matches our wallets change index.
                for (i, changeAddress) in changeAddresses.enumerated() {
                    let changeAddr = Address_Cache(changeAddress)
                    if changeAddr.index == wallet.changeIndex {
                        // This is the address we want to use as it matches our wallet change index.
                        changeAddressToUse = changeAddr
                    }
                    
                    // The loop has finished.
                    if i + 1 == changeAddresses.count {
                        
                        // Ensures we actually have a change address that matches our wallet change index.
                        guard let changeAddressToUse = changeAddressToUse else {
                            self.removeSpinnerView()
                            self.showAlert(title: "", message: "No available change address at index \(wallet.changeIndex).")
                            return
                        }
                        
                        // Fetches the recommended fee from mempool api.
                        MempoolRequest.sharedInstance.command(method: .fee) { (response, errorDesc) in
                            guard let response = response as? [String:Any] else {
                                self.removeSpinnerView()
                                self.showAlert(title: "Failed fetching fee target.", message: errorDesc ?? "Unknown.")
                                return
                            }
                            
                            // Gets our fee target based on our settings.
                            let feeTarget = RecommendedFee(response).target
                            
                            // Now we have all the info needed to create our transaction.
                            WalletTools.shared.createTx(destinationAddress: self.address,
                                                        changeAddress: changeAddressToUse,
                                                        btcAmountToSend: self.btcAmountToSend,
                                                        feeTarget: feeTarget) { [weak self] (message, rawTx) in
                                
                                guard let self = self else { return }
                                
                                // Ensures a raw tx was successfully created.
                                guard let rawTx = rawTx else {
                                    self.removeSpinnerView()
                                    self.showAlert(title: "", message: message ?? "Uknown.")
                                    return
                                }
                                
                                // Tx was created, remove the spinner.
                                self.removeSpinnerView()
                                
                                // Set our variables so they can be passed to the "confirm" view.
                                // MARK: TODO - Add fee rate.
                                self.rawTx = rawTx.rawTx
                                self.fee = rawTx.fee
                                
                                // Navigates to the "confirm" view.
                                DispatchQueue.main.async {
                                    self.performSegue(withIdentifier: "segueToSend", sender: self)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Gets called everytime the user types something on the keyboard so we can show the spend button when appropriate.
    @objc func textFieldDidChange() {
        // Ensures text exists.
        guard let text = amountInput.text else {
            sendOutlet.isEnabled = false
            return
        }
        
        // Checks the amount input as per the denomination, if we have enough funds for that amount we enable the send button.
        switch denomination {
        case "BTC":
            if text.doubleValue > 0, text.doubleValue < btcBalance {
                showSendButton()
            } else {
                sendOutlet.isEnabled = false
            }
        case "SAT":
            if text.doubleValue > 0, text.doubleValue < satsBalance {
                showSendButton()
            } else {
                sendOutlet.isEnabled = false
            }
        default:
            if text.doubleValue > 0, text.doubleValue < fiatBalance {
                showSendButton()
            } else {
                sendOutlet.isEnabled = false
            }
        }
    }
    
    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Passes our variables to the "confirm" view.
        switch segue.identifier {
        case "segueToSend":
            guard let vc = segue.destination as? SendConfirmationViewController else { return }
            
            // MARK: - TODO Add fee rate.
            vc.rawTx = self.rawTx
            vc.destinationAddress = self.address
            vc.destinationAmount = self.btcAmountToSend
            vc.fee = self.fee

        default:
            break
        }
    }
}
