//
//  AmountInputViewController.swift
//  Satsuma
//
//  Created by Peter Denton on 5/11/23.
//

import UIKit

class AmountInputViewController: UIViewController, UITextFieldDelegate {
    
    var address = ""
    var amount = 0.0
    var balance = 0.0
    var rawTx = ""
    var fee = 0
    var buttonConstraint: NSLayoutConstraint!
    @IBOutlet weak var amountInput: UITextField!
    @IBOutlet weak var fiatButtonOutlet: UIButton!
    @IBOutlet weak var balanceOutlet: UILabel!
    @IBOutlet weak var addressOutlet: UILabel!
    @IBOutlet weak var sendOutlet: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        amountInput.delegate = self
        sendOutlet.alpha = 0
        view.addSubview(sendOutlet)
        sendOutlet.translatesAutoresizingMaskIntoConstraints = false
        sendOutlet.addTarget(self, action: #selector(buttonAction), for: .touchUpInside)
        sendOutlet.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 40).isActive = true
        sendOutlet.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -40).isActive = true
        buttonConstraint = sendOutlet.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10)
        buttonConstraint.isActive = true
        sendOutlet.heightAnchor.constraint(equalToConstant: 50).isActive = true
        sendOutlet.isEnabled = false
        amountInput.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        view.layoutIfNeeded()
        subscribeToShowKeyboardNotifications()
        addTapGesture()
        
        amountInput.becomeFirstResponder()        
        
        if amount > 0 {
            amountInput.text = "\(amount)"
        }
        if address != "" {
            addressOutlet.text = address
        }
        getBalance()
    }
    
    @IBAction func useAllFundsAction(_ sender: Any) {
    }
    
    @IBAction func seeFullAddressAction(_ sender: Any) {
    }
    
    private func getBalance() {
        CoreDataService.retrieveEntity(entityName: .utxos) { [weak self] utxos in
            guard let self = self else { return }
            
            guard let utxos = utxos, utxos.count > 0 else { return }
            for utxo in utxos {
                let utxo = Utxo_Cache(utxo)
                if utxo.confirmed {
                    self.balance += utxo.doubleValueSats.btcAmountDouble
                }
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.balanceOutlet.text = "Balance: \(balance) BTC"
            }
            
            if amount > 0, amount < self.balance {
                self.showSendButton()
            }
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.endEditing(true)
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        textField.resignFirstResponder()
        
        guard let text = textField.text, text != "" else {
            return
        }
        
        if text.doubleValue > 0, text.doubleValue < balance {
            amount = text.doubleValue
            showSendButton()
        } else {
            sendOutlet.isEnabled = false
            showAlert(vc: self, title: "", message: "Insufficient funds, try a lower amount.")
        }
    }
    
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

    @objc func keyboardWillHide(_ notification: Notification) {
        buttonConstraint.constant = -10

        let userInfo = notification.userInfo
        let animationDuration = userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as! Double
        UIView.animate(withDuration: animationDuration) {
            self.view.layoutIfNeeded()
        }
    }
    
    func addTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard (_:)))
        tapGesture.numberOfTapsRequired = 1
        self.view.addGestureRecognizer(tapGesture)
    }
    
    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        amountInput.resignFirstResponder()
    }
    
    private func showSendButton() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.sendOutlet.alpha = 1
            self.sendOutlet.isEnabled = true
        }
    }
    
    @objc func buttonAction() {
        amountInput.resignFirstResponder()
        print("build tx now.")
        CoreDataService.retrieveEntity(entityName: .wallets) { wallets in
            guard let wallets = wallets else { return }
            
            let wallet = Wallet(wallets[0])
            
            CoreDataService.retrieveEntity(entityName: .changeAddr) { changeAddresses in
                guard let changeAddresses = changeAddresses else { return }
                
                var changeAddressToUse:Address_Cache?
                
                for (i, changeAddress) in changeAddresses.enumerated() {
                    let changeAddr = Address_Cache(changeAddress)
                    print("changeAddr: \(changeAddr.address)")
                    if changeAddr.index == wallet.changeIndex {
                        changeAddressToUse = changeAddr
                    }
                    
                    if i + 1 == changeAddresses.count {
                        guard let changeAddressToUse = changeAddressToUse else { return }
                        
                        WalletTools.shared.createTx(destinationAddress: self.address, changeAddress: changeAddressToUse, btcAmountToSend: self.amount) { [weak self] (message, rawTx) in
                            guard let self = self else { return }
                            print("message: \(message)")
                            print("rawTx: \(rawTx)")
                            guard let rawTx = rawTx else {
                                print("message: \(message)")
                                return
                            }
                            self.rawTx = rawTx.rawTx
                            self.fee = rawTx.fee
                            DispatchQueue.main.async {
                                self.performSegue(withIdentifier: "segueToSend", sender: self)
                            }
                        }
                    }
                }
            }
        }
    }
    
    @objc func textFieldDidChange() {
        print("textFieldDidChange")
        guard let text = amountInput.text else {
            sendOutlet.isEnabled = false
            return
        }
        
        if text.doubleValue > 0, text.doubleValue < self.balance {
            showSendButton()
        } else {
            sendOutlet.isEnabled = false
        }
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        switch segue.identifier {
        case "segueToSend":
            guard let vc = segue.destination as? SendConfirmationViewController else { return }
            
            vc.rawTx = self.rawTx
            vc.destinationAddress = self.address
            vc.destinationAmount = self.amount
            vc.fee = self.fee

        default:
            break
        }
    }
    

}
