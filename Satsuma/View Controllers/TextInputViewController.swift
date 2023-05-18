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
        
        // Do any additional setup after loading the view.
        textFieldOutlet.delegate = self
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
        view.layoutIfNeeded()
        subscribeToShowKeyboardNotifications()
        textFieldOutlet.becomeFirstResponder()
        textFieldOutlet.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        addTapGesture()
        
        if address != "" {
            textFieldOutlet.text = address
            if validAddress(string: address) {
                showContinueButton()
            }
        }
    }
    
    @IBAction func pasteAction(_ sender: Any) {
        guard let content = UIPasteboard.general.string else {
            showAlert(vc: self, title: "", message: "No text on the clipboard.")
            return
        }
        
        if parseTextInput(text: content) {
            textFieldOutlet.text = content
            showContinueButton()
        } else {
            showAlert(vc: self, title: "", message: "Not a valid bitcoin address or invoice.")
        }
    }
    
    func validAddress(string: String) -> Bool {
        return WalletTools.shared.validAddress(string: string)
    }
    
    private func validBip21Invoice(string: String) -> (address: String?, amount: Double?, label: String?, message: String?) {
        return BIP21InvoiceParser.shared.parseInvoice(url: string)
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
        
        if parseTextInput(text: text) {
            showContinueButton()
        } else {
            showAlert(vc: self, title: "", message: "Invalid address or invoice.")
        }
    }
    
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
    
    private func showContinueButton() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.continueButtonOutlet.alpha = 1
            self.continueButtonOutlet.isEnabled = true
        }
    }
    
    func addTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard (_:)))
        tapGesture.numberOfTapsRequired = 1
        self.view.addGestureRecognizer(tapGesture)
    }
    
    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        textFieldOutlet.resignFirstResponder()
    }
    
    @objc func textFieldDidChange() {
        guard let text = textFieldOutlet.text else {
            continueButtonOutlet.isEnabled = false
            return }
        if parseTextInput(text: text) {
            textFieldOutlet.endEditing(true)
        } else {
            continueButtonOutlet.isEnabled = false
        }
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
    
    @objc func buttonAction() {
        textFieldOutlet.resignFirstResponder()
    }
    
    
    
     // MARK: - Navigation
     
     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
     // Get the new view controller using segue.destination.
     // Pass the selected object to the new view controller.
         switch segue.identifier {
         case "segueToAmountInput":
             guard let vc = segue.destination as? AmountInputViewController else { return }
             vc.address = address
             vc.amount = amount
         default:
             break
         }
     }
    
}
