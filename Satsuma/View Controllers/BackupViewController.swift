//
//  BackupViewController.swift
//  Satsuma
//
//  Created by Peter Denton on 6/6/23.
//

import UIKit

class BackupViewController: UIViewController {

    @IBOutlet weak var passphraseLabel: UILabel!
    @IBOutlet weak var passphraseHeaderLabel: UILabel!
    @IBOutlet weak var deletePassphraseOutlet: UIButton!
    @IBOutlet weak var seedWordsLabel: UITextView!
    @IBOutlet weak var passphraseFooterLabel: UILabel!
    
    var wordsToDisplay = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        passphraseLabel.alpha = 0
        passphraseHeaderLabel.alpha = 0
        deletePassphraseOutlet.alpha = 0
        passphraseFooterLabel.alpha = 0
        getSeedWords()
        getPassphrase()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
    }
    
    @IBAction func showSeedWordsAction(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            performSegue(withIdentifier: "segueToPinToShowWords", sender: self)
        }
    }
    
    
    private func getSeedWords() {
        CoreDataService.retrieveEntity(entityName: .wallets) { [weak self] wallets in
            guard let self = self else { return }
            
            guard let wallets = wallets else { return }
            
            let wallet = Wallet(wallets[0])
            
            guard let encryptedSeed = wallet.mnemonic else {
                self.showSeedWords(words: "Previously deleted.")
                return
            }
            
            guard let decryptedSeed = Crypto.decrypt(encryptedSeed) else {
                self.showSeedWords(words: "Unable to decrypt the seed words.")
                return
            }
            
            guard let words = decryptedSeed.utf8String else {
                self.showSeedWords(words: "Unable to convert to utf8 string.")
                return
            }
            
            var censoredWordsToDisplay = ""
            let wordArray = words.components(separatedBy: " ")
            for (i, word) in wordArray.enumerated() {
                wordsToDisplay += "\(i + 1). \(word)   "
                censoredWordsToDisplay += "\(i + 1). *****   "
            }
            
            showSeedWords(words: censoredWordsToDisplay)
        }
    }
    
    private func getPassphrase() {
        CoreDataService.retrieveEntity(entityName: .wallets) { [weak self] wallets in
            guard let self = self else { return }
            
            guard let wallets = wallets else { return }
            
            let wallet = Wallet(wallets[0])
            
            guard let encryptedPassphrase = wallet.passphrase else {
                passphraseLabel.removeFromSuperview()
                passphraseHeaderLabel.removeFromSuperview()
                deletePassphraseOutlet.removeFromSuperview()
                passphraseFooterLabel.removeFromSuperview()
                return
            }
                        
            guard let decryptedPassphrase = Crypto.decrypt(encryptedPassphrase) else {
                self.showPassphrase(passphrase: "Unable to decrypt the passphrase.")
                return
            }
            
            guard let passphrase = decryptedPassphrase.utf8String else {
                self.showPassphrase(passphrase: "Unable to convert to utf8 string.")
                return
            }
            
            showPassphrase(passphrase: passphrase)
        }
    }
    
    private func showSeedWords(words: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            seedWordsLabel.text = words
            seedWordsLabel.translatesAutoresizingMaskIntoConstraints = true
            seedWordsLabel.sizeToFit()
            seedWordsLabel.isScrollEnabled = false
        }
    }
    
    private func showPassphrase(passphrase: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            passphraseLabel.text = passphrase
            passphraseLabel.alpha = 1
            passphraseHeaderLabel.alpha = 1
            deletePassphraseOutlet.alpha = 1
            passphraseFooterLabel.alpha = 1
        }
    }
    
    @IBAction func deleteSeedAction(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            var alertStyle = UIAlertController.Style.actionSheet
            if (UIDevice.current.userInterfaceIdiom == .pad) {
              alertStyle = UIAlertController.Style.alert
            }
            let alert = UIAlertController(title: "Delete seed words from the device?", message: "Make sure you have saved these words offline, without them you will not be able to recover your wallet!\n\nYour wallet will still be able to send bitcoins, no private keys are deleted.", preferredStyle: alertStyle)
            alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { [weak self] action in
                guard let self = self else { return }
                
                deleteSeed()
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    @IBAction func deletePassphraseAction(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            var alertStyle = UIAlertController.Style.actionSheet
            if (UIDevice.current.userInterfaceIdiom == .pad) {
              alertStyle = UIAlertController.Style.alert
            }
            let alert = UIAlertController(title: "Delete the passphrase from the device?", message: "Make sure you have saved the passphrase offline, without it you will not be able to recover your wallet!\n\nYour wallet will still be able to send bitcoins without the passphrase saved.", preferredStyle: alertStyle)
            alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { [weak self] action in
                guard let self = self else { return }
                
                deletePassphrase()
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func deleteSeed() {
        CoreDataService.retrieveEntity(entityName: .wallets) { wallets in
            guard let wallets = wallets else { return }
            
            let wallet = Wallet(wallets[0])
            CoreDataService.deleteValue(id: wallet.id, keyToDelete: "mnemonic", entity: .wallets) { [weak self] seedDeleted in
                guard let self = self else { return }
                
                guard seedDeleted else {
                    self.showAlert(title: "Seed deletion failed.", message: "")
                    return
                }
                
                getSeedWords()
                
                showAlert(title: "Seed words deleted.", message: "")
            }
        }
    }
    
    private func deletePassphrase() {
        CoreDataService.retrieveEntity(entityName: .wallets) { wallets in
            guard let wallets = wallets else { return }
            
            let wallet = Wallet(wallets[0])
            CoreDataService.deleteValue(id: wallet.id, keyToDelete: "passphrase", entity: .wallets) { [weak self] seedDeleted in
                guard let self = self else { return }
                
                guard seedDeleted else {
                    self.showAlert(title: "Passphrase deletion failed.", message: "You will still be able to send bitcoins.")
                    return
                }
                
                getPassphrase()
                
                showAlert(title: "Passphrase deleted.", message: "You will still be able to send bitcoins.")
            }
        }
    }
    

    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        if segue.identifier == "segueToPinToShowWords" {
            guard let vc = segue.destination as? PinEntryViewController else { return }
            
            vc.onDoneBlock = { [weak self] _ in
                guard let self = self else { return }
                
                self.showSeedWords(words: wordsToDisplay)
            }
        }
    }
}
