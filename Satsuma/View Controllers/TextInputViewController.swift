//
//  TextInputViewController.swift
//  Satsuma
//
//  Created by Peter Denton on 5/11/23.
//

import UIKit

class TextInputViewController: UIViewController, UITextFieldDelegate {
    
    var buttonConstraint: NSLayoutConstraint!
    var address = ""
    var amount = 0.0
    @IBOutlet weak var textFieldOutlet: UITextField!
    @IBOutlet weak var continueButtonOutlet: UIButton!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureViews()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        textFieldOutlet.becomeFirstResponder()
    }
    
    // The paste button action.
    @IBAction func pasteAction(_ sender: Any) {
        guard let content = UIPasteboard.general.string else {
            self.showAlert(title: "", message: "No text on the clipboard.")
            return
        }
        
        if parseTextInput(text: content) {
            textFieldOutlet.text = content
            showContinueButton()
        } else {
            self.showAlert(title: "", message: "Not a valid bitcoin address or invoice.")
        }
    }
    
    // Configures all of the views.
    private func configureViews() {
        // Ensures the scanner is bypassed if user navigates back.
        if let rootVC = navigationController?.viewControllers.first {
            navigationController?.viewControllers = [rootVC, self]
        }
        confirgureContinueButton()
        view.layoutIfNeeded()
        subscribeToShowKeyboardNotifications()
        addTapGesture()
        configureTextField()
    }
    
    // Configure the text input.
    private func configureTextField() {
        textFieldOutlet.delegate = self
        textFieldOutlet.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        if address != "" {
            textFieldOutlet.text = address
        }
    }
    
    // Configure the continue button.
    private func confirgureContinueButton() {
        continueButtonOutlet.alpha = 0
        view.addSubview(continueButtonOutlet)
        continueButtonOutlet.translatesAutoresizingMaskIntoConstraints = false
        continueButtonOutlet.addTarget(self, action: #selector(buttonAction), for: .touchUpInside)
        continueButtonOutlet.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 40).isActive = true
        continueButtonOutlet.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -40).isActive = true
        buttonConstraint = continueButtonOutlet.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10)
        buttonConstraint.isActive = true
        continueButtonOutlet.heightAnchor.constraint(equalToConstant: 50).isActive = true
        continueButtonOutlet.isEnabled = false
        if address != "" {
            if validAddress(string: address) {
                showContinueButton()
            }
        }
    }
    
    // Checks if an address is valid.
    private func validAddress(string: String) -> Bool {
        return WalletTools.shared.validAddress(string: string)
    }
    
    // Checks if an invoice is valid.
    // MARK: - TODO Test BIP21 invoices.
    private func validBip21Invoice(string: String) -> (address: String?, amount: Double?, label: String?, message: String?) {
        return BIP21InvoiceParser.shared.parseInvoice(url: string)
    }
    
    // Calls textFieldDidEndEditing when the user taps return/done on the keyboard.
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.endEditing(true)
        return true
    }
    
    // User has finished typing.
    func textFieldDidEndEditing(_ textField: UITextField) {
        // Dismiss the keyboard.
        textField.resignFirstResponder()
        
        // Ensure text was input before processing it.
        guard let text = textField.text, text != "" else {
            return
        }
        
        // Parse the input to ensure it is a valid address.
        if parseTextInput(text: text) {
            showContinueButton()
        } else {
            self.showAlert(title: "", message: "Invalid address or invoice.")
        }
    }
    
    // Checks given text to see if it is a valid address or bip21 invoice.
    private func parseTextInput(text: String) -> Bool {
        if validAddress(string: text) {
            address = text
            return true
        } else {
            let (address, amount, _, _) = validBip21Invoice(string: text)
            guard let address = address else {
                return false
            }
            self.address = address
            if let amount = amount {
                self.amount = amount
            }
            
            return true
        }
    }
    
    // Displays the continue button.
    private func showContinueButton() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.continueButtonOutlet.alpha = 1
            self.continueButtonOutlet.isEnabled = true
        }
    }
    
    // Adds a tap gesture to dismiss the keyboard if a use taps the view.
    func addTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard (_:)))
        tapGesture.numberOfTapsRequired = 1
        self.view.addGestureRecognizer(tapGesture)
    }
    
    // Dismisses the keyboard.
    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        textFieldOutlet.resignFirstResponder()
    }
    
    // Gets called everytime the user edits the text.
    @objc func textFieldDidChange() {
        guard let text = textFieldOutlet.text else {
            continueButtonOutlet.isEnabled = false
            return
        }
        
        if parseTextInput(text: text) {
            textFieldOutlet.endEditing(true)
        } else {
            continueButtonOutlet.isEnabled = false
        }
    }
    
    // So we know where to put the "continue" button when the keyboard shows.
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
    
    // So we know where to put the "continue" button when the keyboard hides.
    @objc func keyboardWillHide(_ notification: Notification) {
        buttonConstraint.constant = -10

        let userInfo = notification.userInfo
        let animationDuration = userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as! Double
        UIView.animate(withDuration: animationDuration) {
            self.view.layoutIfNeeded()
        }
    }
    
    // So we get a notification when keyboard will show/hide.
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
    
    // "Continue" button action, triggers textFieldDidEndEditing.
    @objc func buttonAction() {
        textFieldOutlet.resignFirstResponder()
    }    
    
     // MARK: - Navigation
     
     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
     // Passes the address and potential amount (if an invoice was scanned to the amount input view.
         switch segue.identifier {
         case "segueToAmountInput":
             guard let vc = segue.destination as? AmountInputViewController else { return }
             vc.address = address
             vc.btcAmountToSend = amount
         default:
             break
         }
     }
    
}
