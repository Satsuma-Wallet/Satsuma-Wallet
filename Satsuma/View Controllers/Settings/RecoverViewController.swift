//
//  RecoverViewController.swift
//  Satsuma
//
//  Created by Peter Denton on 6/2/23.
//

import UIKit

class RecoverViewController: UIViewController, UINavigationControllerDelegate, UITextViewDelegate, UITextFieldDelegate {

    @IBOutlet weak var passphraseField: UITextField!
    @IBOutlet weak var textView: UITextField!
    @IBOutlet weak var wordView: UITextView!
    @IBOutlet weak var addSignerOutlet: UIButton!
    
    var addedWords = [String]()
    var justWords = [String]()
    var bip39Words = [String]()
    var autoCompleteCharacterCount = 0
    var timer = Timer()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        navigationController?.delegate = self
        passphraseField.delegate = self
        textView.delegate = self
        addSignerOutlet.isEnabled = false
        wordView.layer.cornerRadius = 8
        wordView.layer.borderColor = UIColor.lightGray.cgColor
        wordView.layer.borderWidth = 0.5
        addSignerOutlet.clipsToBounds = true
        addSignerOutlet.layer.cornerRadius = 8
        bip39Words = Words.valid
        updatePlaceHolder(wordNumber: 1)
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard(_:)))
        tapGesture.numberOfTapsRequired = 1
        self.view.addGestureRecognizer(tapGesture)
        textView.removeGestureRecognizer(tapGesture)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    @IBAction func addSignerAction(_ sender: Any) {
        promptToRecover()
    }
    
    private func promptToRecover() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            var alertStyle = UIAlertController.Style.actionSheet
            if (UIDevice.current.userInterfaceIdiom == .pad) {
              alertStyle = UIAlertController.Style.alert
            }
            let alert = UIAlertController(title: "⚠️ Existing wallets will be deleted!", message: "Recovering a wallet will overwrite your existing wallet. Ensure your existing wallet is backed up prior to recovering a wallet.", preferredStyle: alertStyle)
            alert.addAction(UIAlertAction(title: "Recover now", style: .destructive, handler: { [weak self] action in
                guard let self = self else { return }
                
                self.recoverAction()
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    @IBAction func addWordAction(_ sender: Any) {
        processTextfieldInput()
    }
    
    @IBAction func removeWordAction(_ sender: Any) {
        if justWords.count > 0 {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.wordView.text = ""
                self.addedWords.removeAll()
                self.justWords.remove(at: self.justWords.count - 1)
                
                for (i, word) in self.justWords.enumerated() {
                    self.addedWords.append("\(i + 1). \(word)\n")
                    
                    if i == 0 {
                        self.updatePlaceHolder(wordNumber: i + 1)
                    } else {
                        self.updatePlaceHolder(wordNumber: i + 2)
                    }
                }
                
                self.wordView.text = self.addedWords.joined(separator: "")
                self.checkForAutoScroll()
                
                if WalletTools.shared.validMnemonic(words: self.justWords.joined(separator: " ")) {
                    self.validWordsAdded()
                }
            }
        }
    }
    
    private func processTextfieldInput() {
        guard textView.text != "" else {
            textView.endEditing(true)
            return
        }
        
        //check if user pasted more then one word
        let processed = processedCharacters(textView.text!)
        let userAddedWords = processed.split(separator: " ")
        var multipleWords = [String]()
        
        if userAddedWords.count > 1 {
            //user add multiple words
            for (i, word) in userAddedWords.enumerated() {
                var isValid = false
                
                for bip39Word in bip39Words {
                    if word == bip39Word {
                        isValid = true
                        multipleWords.append("\(word)")
                    }
                }
                
                if i + 1 == userAddedWords.count {
                    // we finished our checks
                    if isValid {
                        // they are valid bip39 words
                        addMultipleWords(words: multipleWords)
                        textView.text = ""
                    } else {
                        //they are not all valid bip39 words
                        textView.text = ""
                        self.showAlert(title: "Error", message: "At least one of those words is not a valid BIP39 word. We suggest inputting them one at a time so you can utilize our autosuggest feature which will prevent typos.")
                    }
                }
            }
        } else {
            //its one word
            let processedWord = textView.text!.replacingOccurrences(of: " ", with: "")
            
            for word in bip39Words {
                if processedWord == word {
                    addWord(word: processedWord)
                    textView.text = ""
                }
            }
        }
    }
    
    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        hideKeyboards()
    }
    
    private func hideKeyboards() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.textView.resignFirstResponder()
            self.passphraseField.resignFirstResponder()
        }
    }
    
    @objc func keyboardWillShow(notification: NSNotification) {
        if passphraseField.isEditing {
            if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
                if self.view.frame.origin.y == 0 {
                    self.view.frame.origin.y -= keyboardSize.height
                }
            }
        }
    }
    
    @objc func keyboardWillHide(notification: NSNotification) {
        if passphraseField.isEditing {
            if self.view.frame.origin.y != 0 {
                self.view.frame.origin.y = 0
            }
        }
    }
    
    private func updatePlaceHolder(wordNumber: Int) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.textView.attributedPlaceholder = NSAttributedString(string: "add word #\(wordNumber)", attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightGray])
        }
    }
    
    private func recoverAction() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.addSpinnerView(description: "recovering...")
            
            let words = self.justWords.joined(separator: " ")
            let passphrase = self.passphraseField.text ?? ""

            WalletTools.shared.recover(words: words, passphrase: passphrase) { [weak self] (message, recovered) in
                guard let self = self else { return }
                
                self.removeSpinnerView()
                
                guard recovered else {
                    self.showAlert(title: "Recovery failed.", message: message ?? "Unknown error.")
                    return
                }
                
                self.walletRecovered()
            }
        }
    }

    private func formatSubstring(subString: String) -> String {
        let formatted = String(subString.dropLast(autoCompleteCharacterCount)).lowercased()
        return formatted
    }
    
    private func resetValues() {
        textView.textColor = .systemGreen
        autoCompleteCharacterCount = 0
        textView.text = ""
    }
    
    func searchAutocompleteEntriesWIthSubstring(substring: String) {
        
        let userQuery = substring
        let suggestions = getAutocompleteSuggestions(userText: substring)
        self.textView.textColor = .systemGreen
        
        if suggestions.count > 0 {
            timer = .scheduledTimer(withTimeInterval: 0.01, repeats: false, block: { (timer) in
                let autocompleteResult = self.formatAutocompleteResult(substring: substring, possibleMatches: suggestions)
                self.putColorFormattedTextInTextField(autocompleteResult: autocompleteResult, userQuery : userQuery)
                self.moveCaretToEndOfUserQueryPosition(userQuery: userQuery)
            })
            
        } else {
            timer = .scheduledTimer(withTimeInterval: 0.01, repeats: false, block: { [weak self] (timer) in
                guard let self = self else { return }
                self.textView.text = substring
                
                if WalletTools.shared.validMnemonic(words: self.processedCharacters(self.textView.text!)) {
                    self.processTextfieldInput()
                    self.textView.textColor = .systemGreen
                    self.validWordsAdded()
                } else {
                    self.textView.textColor = .systemRed
                }
            })
            autoCompleteCharacterCount = 0
        }
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if textField != passphraseField {
            var subString = (textField.text!.capitalized as NSString).replacingCharacters(in: range, with: string)
            subString = formatSubstring(subString: subString)
            if subString.count == 0 {
                resetValues()
            } else {
                searchAutocompleteEntriesWIthSubstring(substring: subString)
            }
        }
        return true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField != passphraseField {
            processTextfieldInput()
        } else {
            textField.endEditing(true)
        }
        return true
    }
    
    func getAutocompleteSuggestions(userText: String) -> [String]{
        var possibleMatches: [String] = []
        for item in bip39Words {
            let myString:NSString! = item as NSString
            let substringRange:NSRange! = myString.range(of: userText)
            if (substringRange.location == 0) {
                possibleMatches.append(item)
            }
        }
        return possibleMatches
    }
    
    func putColorFormattedTextInTextField(autocompleteResult: String, userQuery : String) {
        let coloredString: NSMutableAttributedString = NSMutableAttributedString(string: userQuery + autocompleteResult)
        coloredString.addAttribute(NSAttributedString.Key.foregroundColor,
                                   value: UIColor.systemGreen,
                                   range: NSRange(location: userQuery.count,length:autocompleteResult.count))
        self.textView.attributedText = coloredString
    }
    
    func moveCaretToEndOfUserQueryPosition(userQuery : String) {
        if let newPosition = self.textView.position(from: self.textView.beginningOfDocument, offset: userQuery.count) {
            self.textView.selectedTextRange = self.textView.textRange(from: newPosition, to: newPosition)
        }
        let selectedRange: UITextRange? = textView.selectedTextRange
        textView.offset(from: textView.beginningOfDocument, to: (selectedRange?.start)!)
    }
    
    func formatAutocompleteResult(substring: String, possibleMatches: [String]) -> String {
        var autoCompleteResult = possibleMatches[0]
        autoCompleteResult.removeSubrange(autoCompleteResult.startIndex..<autoCompleteResult.index(autoCompleteResult.startIndex, offsetBy: substring.count))
        autoCompleteCharacterCount = autoCompleteResult.count
        return autoCompleteResult
    }
    
    private func addMultipleWords(words: [String]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.wordView.text = ""
            self.addedWords.removeAll()
            self.justWords = words
            
            for (i, word) in self.justWords.enumerated() {
                self.addedWords.append("\(i + 1). \(word)\n")
                self.updatePlaceHolder(wordNumber: i + 2)
            }
            
            self.wordView.text = self.addedWords.joined(separator: "")
            self.checkForAutoScroll()
        }
    }
    
    private func addWord(word: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.wordView.text = ""
            self.addedWords.removeAll()
            self.justWords.append(word)
            
            for (i, word) in self.justWords.enumerated() {
                self.addedWords.append("\(i + 1). \(word)\n")
                self.updatePlaceHolder(wordNumber: i + 2)
                
            }
            
            self.wordView.text = self.addedWords.joined(separator: "")
            checkForAutoScroll()
            
            if WalletTools.shared.validMnemonic(words: self.justWords.joined(separator: " ")) {
                self.validWordsAdded()
            }
            
            self.textView.becomeFirstResponder()
        }
    }
    
    private func checkForAutoScroll() {
        let textHeight = self.getTextHeight(text: self.wordView.text, width: self.wordView.frame.height, font: self.wordView.font!)
        
        if textHeight > 251.0 {
            scrollToBottom()
        }
    }
    
    private func processedCharacters(_ string: String) -> String {
        var result = string.filter("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ ".contains)
        result = result.condenseWhitespace()
        return result
    }
    
    private func validWordsAdded() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.textView.resignFirstResponder()
            self.addSignerOutlet.isEnabled = true
        }
        self.showAlert(title: "Valid Seed Words ✓", message: "This is a valid BIP39 mnemonic. You can add an optional passphrase. Tap \"Recover\" to encrypt, save and recover the wallet.")
    }
    
    private func walletRecovered() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            var alertStyle = UIAlertController.Style.actionSheet
            if (UIDevice.current.userInterfaceIdiom == .pad) {
              alertStyle = UIAlertController.Style.alert
            }
            
            CoreDataService.retrieveEntity(entityName: .utxos) { utxos in
                guard let utxos = utxos else { return }
                
                var totalSats = 0.0
                for utxo in utxos {
                    let utxo = Utxo_Cache(utxo)
                    totalSats += utxo.value
                }
                let alert = UIAlertController(title: "Wallet successfully recovered with a balance of \(totalSats.btcAmountDouble.avoidNotation) BTC", message: "Tap done to go home.", preferredStyle: alertStyle)
                alert.addAction(UIAlertAction(title: "Done", style: .cancel, handler: { action in
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        NotificationCenter.default.post(name: Notification.Name(rawValue: "walletRecovered"), object: nil)
                        self.navigationController?.popToRootViewController(animated: true)
                        tabBarController?.selectedIndex = 0
                    }
                }))
                alert.popoverPresentationController?.sourceView = self.view
                self.present(alert, animated: true, completion: nil)
            }
            
        }
    }
    
    private func getTextHeight(text: String, width: CGFloat, font: UIFont) -> CGFloat {
        let lbl = UILabel(frame: .zero)
        lbl.frame.size.width = width
        lbl.font = font
        lbl.numberOfLines = 0
        lbl.text = text
        lbl.sizeToFit()
        return lbl.frame.size.height
    }
    
    private func scrollToBottom() {
        let bottomRange = NSMakeRange(self.wordView.text.count - 1, 1)
        self.wordView.scrollRangeToVisible(bottomRange)
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
