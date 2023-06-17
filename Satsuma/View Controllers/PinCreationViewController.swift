//
//  PinCreationViewController.swift
//  Satsuma
//
//  Created by Peter Denton on 6/7/23.
//

import UIKit

class PinCreationViewController: UIViewController, UITextFieldDelegate {
    
    @IBOutlet weak var createConfirmLabel: UILabel!
    @IBOutlet weak var circleOne: UIImageView!
    @IBOutlet weak var circleTwo: UIImageView!
    @IBOutlet weak var circleThree: UIImageView!
    @IBOutlet weak var circleFour: UIImageView!
    @IBOutlet weak var subheaderLabel: UILabel!
    @IBOutlet weak var hiddenTextField: UITextField!
    
    var firstPin = ""
    var secondPin = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        hiddenTextField.delegate = self
        hiddenTextField.alpha = 0
        hiddenTextField.keyboardType = .numberPad
        hiddenTextField.isSecureTextEntry = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        hiddenTextField.becomeFirstResponder()
    }
    
    func textFieldDidChangeSelection(_ textField: UITextField) {
        guard let text = textField.text else { return }
                        
        fillCircle(text: text)
        
        if text.count == 4 && firstPin == "" {
            firstPin = text
            textField.text = ""
            showConfirm()
            
        } else if text.count == 4 {
            secondPin = text
            if firstPin == secondPin {
                greenCircle()
                subheaderLabel.text = "PIN matched ✓"
                Vibration.success.vibrate()
                hiddenTextField.resignFirstResponder()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    guard let self = self else { return }
                    
                    savePin()
                }
                
            } else {
                firstPin = ""
                secondPin = ""
                hiddenTextField.text = ""
                subheaderLabel.text = "PIN did not match"
                redCircle()
                subheaderLabel.shake()
                Vibration.error.vibrate()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    guard let self = self else { return }
                    
                    subheaderLabel.text = ""
                    createConfirmLabel.text = "Create your PIN"
                    emptyCircle()
                }
            }
        }
    }
    
    private func savePin() {
        guard let encryptedPin = Crypto.encrypt(firstPin.utf8) else {
            showAlert(title: "Unable to encrypt pin.", message: "Please let us know about this bug.")
            
            return
        }
        
        let dict:[String:Any] = ["pin": encryptedPin]
        
        CoreDataService.saveEntity(dict: dict, entityName: .pin) { [weak self] pinSaved in
            guard let self = self else { return }
            
            guard pinSaved else {
                showAlert(title: "Pin not saved.", message: "Please let us know about this bug.")
                
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                dismiss(animated: true)
            }
        }
    }
    
    private func showConfirm() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            createConfirmLabel.text = "Confirm your PIN"
            emptyCircle()
        }
    }
    
    private func fillCircle(text: String) {
        switch text.count {
        case 1:
            fillCircle(imageView: circleOne)
        case 2:
            fillCircle(imageView: circleTwo)
        case 3:
            fillCircle(imageView: circleThree)
        case 4:
            fillCircle(imageView: circleFour)
        default:
            break
        }
    }
    
    private func emptyCircle() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            circleOne.image = .init(systemName: "circle")
            circleTwo.image = .init(systemName: "circle")
            circleThree.image = .init(systemName: "circle")
            circleFour.image = .init(systemName: "circle")
            
            circleOne.tintColor = #colorLiteral(red: 0, green: 0.5628422499, blue: 0.3188166618, alpha: 1)
            circleTwo.tintColor = #colorLiteral(red: 0, green: 0.5628422499, blue: 0.3188166618, alpha: 1)
            circleThree.tintColor = #colorLiteral(red: 0, green: 0.5628422499, blue: 0.3188166618, alpha: 1)
            circleFour.tintColor = #colorLiteral(red: 0, green: 0.5628422499, blue: 0.3188166618, alpha: 1)
        }
    }
    
    private func redCircle() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            circleOne.image = .init(systemName: "circle.fill")
            circleTwo.image = .init(systemName: "circle.fill")
            circleThree.image = .init(systemName: "circle.fill")
            circleFour.image = .init(systemName: "circle.fill")
            
            circleOne.tintColor = .red
            circleTwo.tintColor = .red
            circleThree.tintColor = .red
            circleFour.tintColor = .red
        }
    }
    
    private func greenCircle() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            circleOne.tintColor = #colorLiteral(red: 0, green: 0.5628422499, blue: 0.3188166618, alpha: 1)
            circleTwo.tintColor = #colorLiteral(red: 0, green: 0.5628422499, blue: 0.3188166618, alpha: 1)
            circleThree.tintColor = #colorLiteral(red: 0, green: 0.5628422499, blue: 0.3188166618, alpha: 1)
            circleFour.tintColor = #colorLiteral(red: 0, green: 0.5628422499, blue: 0.3188166618, alpha: 1)
        }
    }
    
    private func fillCircle(imageView: UIImageView) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            imageView.image = .init(systemName: "circle.fill")
        }
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
