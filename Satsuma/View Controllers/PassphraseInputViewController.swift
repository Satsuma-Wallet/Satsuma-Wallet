//
//  PassphraseInputViewController.swift
//  Satsuma
//
//  Created by Peter Denton on 5/22/23.
//

import UIKit

class PassphraseInputViewController: UIViewController, UITextFieldDelegate {

    @IBOutlet weak var passphraseInput: UITextField!
    @IBOutlet weak var confirmInput: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        passphraseInput.delegate = self
        confirmInput.delegate = self
        passphraseInput.isSecureTextEntry = true
        confirmInput.isSecureTextEntry = true
        passphraseInput.becomeFirstResponder()
        addTapGesture()
    }
    
    // The "confirm" button action.
    @IBAction func confirmAction(_ sender: Any) {
        if passphraseInput.text == "" && confirmInput.text == "" {
            // An empty string was entered by the user, we confrim they want to use an empty passphrase.
            promptToCreateWalletWithEmptyPassphrase()
            
        } else if passphraseInput.text == confirmInput.text {
            // The text inputs match so we can create the wallet with the provided passphrase.
            createWallet(passphrase: passphraseInput.text!)
            
        } else {
            self.showAlert(title: "Passphrases do not match.", message: "Try again.")
        }
    }
    
    private func promptToCreateWalletWithEmptyPassphrase() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let alert = UIAlertController(title: "Empty passphrase.", message: "Would you like to create your wallet with an empty passphrase?", preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: { action in
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    // User wants an empty passphrase so we create the wallet without a passphrase.
                    self.createWallet(passphrase: "")
                }
            }))
            
            alert.addAction(UIAlertAction(title: "No", style: .default, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    // Creates a wallet with a provided passphrase.
    private func createWallet(passphrase: String) {
        WalletTools.shared.create(passphrase: passphrase) { [weak self] (message, created) in
            guard let self = self else { return }
            
            guard created else {
                self.showAlert(title: "Wallet creation failed.", message: message ?? "Unknown")
                return
            }
            
            // Wallet creation succeeeded, so we dismiss the view back to home and look for a balance.
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.navigationController?.popToRootViewController(animated: true)
            }
        }
    }
    
    // Gets called when the user taps the return button on the keypad.
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.endEditing(true)
        return true
    }
    
    // Forces the keypad to dismiss when editing finishes.
    func textFieldDidEndEditing(_ textField: UITextField) {
        textField.resignFirstResponder()
    }
    
    // Adds the tap gesture that dismisses the keypad when the user taps the view.
    func addTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard (_:)))
        tapGesture.numberOfTapsRequired = 1
        self.view.addGestureRecognizer(tapGesture)
    }
    
    // Dismisses the keyboard.
    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        passphraseInput.resignFirstResponder()
        confirmInput.resignFirstResponder()
    }

}
