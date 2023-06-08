//
//  PinEntryViewController.swift
//  Satsuma
//
//  Created by Peter Denton on 6/7/23.
//

import UIKit

class PinEntryViewController: UIViewController, UITextFieldDelegate {
    
    @IBOutlet weak var circleOne: UIImageView!
    @IBOutlet weak var circleTwo: UIImageView!
    @IBOutlet weak var circleThree: UIImageView!
    @IBOutlet weak var circleFour: UIImageView!
    @IBOutlet weak var subHeaderLabel: UILabel!
    @IBOutlet weak var hiddenTextField: UITextField!
    
    var onDoneBlock : ((Bool) -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        hiddenTextField.alpha = 0
        hiddenTextField.delegate = self
        hiddenTextField.keyboardType = .numberPad
    }
    
    override func viewDidAppear(_ animated: Bool) {
        hiddenTextField.becomeFirstResponder()
    }
    
    func textFieldDidChangeSelection(_ textField: UITextField) {
        guard let text = textField.text else { return }
                        
        fillCircle(text: text)
        
        if text.count == 4 {
            CoreDataService.retrieveEntity(entityName: .pin) { [weak self] pins in
                guard let self = self else { return }
                
                guard let pins = pins else { return }
                
                let encryptedPin = pins[0]["pin"] as! Data
                guard let decryptedPin = Crypto.decrypt(encryptedPin), let pin = decryptedPin.utf8String else { return }
                
                if text == pin {
                    greenCircle()
                    subHeaderLabel.text = "PIN correct ✓"
                    Vibration.success.vibrate()
                    hiddenTextField.resignFirstResponder()

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        guard let self = self else { return }
                        
                        onDoneBlock!(true)
                        dismiss(animated: true)
                    }
                    
                } else {
                    hiddenTextField.text = ""
                    subHeaderLabel.text = "PIN incorrect!"
                    redCircle()
                    subHeaderLabel.shake()
                    Vibration.error.vibrate()
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                        guard let self = self else { return }
                        
                        emptyCircle()
                        subHeaderLabel.text = ""
                    }
                }
            }
        }
    }
    
    private func emptyCircle() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            circleOne.image = .init(systemName: "circle")
            circleTwo.image = .init(systemName: "circle")
            circleThree.image = .init(systemName: "circle")
            circleFour.image = .init(systemName: "circle")
            
            circleOne.tintColor = .tintColor
            circleTwo.tintColor = .tintColor
            circleThree.tintColor = .tintColor
            circleFour.tintColor = .tintColor
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
    
    private func fillCircle(imageView: UIImageView) {
        DispatchQueue.main.async {
            imageView.image = .init(systemName: "circle.fill")
        }
    }
    
    private func greenCircle() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            circleOne.tintColor = .green
            circleTwo.tintColor = .green
            circleThree.tintColor = .green
            circleFour.tintColor = .green
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
