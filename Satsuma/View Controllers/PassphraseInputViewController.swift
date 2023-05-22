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
    
    
    @IBAction func confirmAction(_ sender: Any) {
        if passphraseInput.text == "" && confirmInput.text == "" {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let alert = UIAlertController(title: "Empty passphrase.", message: "Would you like to create your wallet with an empty passphrase?", preferredStyle: .alert)
                
                alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: { action in
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        
                        self.createWallet(passphrase: "")
                    }
                }))
                
                alert.addAction(UIAlertAction(title: "No", style: .default, handler: { action in }))
                alert.popoverPresentationController?.sourceView = self.view
                self.present(alert, animated: true, completion: nil)
            }
            
        } else {
            if passphraseInput.text == confirmInput.text {
                createWallet(passphrase: passphraseInput.text!)
            } else {
                self.showAlert(title: "Passphrases do not match.", message: "Try again.")
            }
        }
    }
    
    private func createWallet(passphrase: String) {
        WalletTools.shared.create(passphrase: passphrase) { [weak self] (message, created) in
            guard let self = self else { return }
            
            guard created else {
                self.showAlert(title: "Wallet creation failed.", message: message ?? "Unknown")
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.navigationController?.popToRootViewController(animated: true)
            }
            
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.endEditing(true)
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        textField.resignFirstResponder()
    }
    
    func addTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard (_:)))
        tapGesture.numberOfTapsRequired = 1
        self.view.addGestureRecognizer(tapGesture)
    }
    
    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        passphraseInput.resignFirstResponder()
        confirmInput.resignFirstResponder()
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
