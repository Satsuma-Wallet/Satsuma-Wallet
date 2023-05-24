//
//  ReceiveViewController.swift
//  Satsuma
//
//  Created by Peter Denton on 5/10/23.
//

import UIKit

class ReceiveViewController: UIViewController {
    
    var address:Address_Cache!
    @IBOutlet weak var addressView: AddressView!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var addressLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        addressView.alpha = 0
        addressView.sizeToFit()
        
        fetchAddress { [weak self] (message, address) in
            guard let self = self else { return }
            
            guard let address = address else {
                self.showAlert(title: "There was an issue fetching your address.", message: message ?? "Unknown.")
                return
            }
            self.loadViews(address: address)
        }
    }
    
    @IBAction func showAddressAction(_ sender: Any) {
        addressView.address.text = address.address
        addressView.derivation.text = address.derivation
        addressView.balance.alpha = 0
        addressView.alpha = 1
        
    }
    
    @IBAction func backAction(_ sender: Any) {
        self.dismiss(animated: true)
    }
    
    @IBAction func shareAction(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let text = self.address.address
            let textToShare:[String] = [text]
            let activityViewController = UIActivityViewController(activityItems: textToShare, applicationActivities: nil)
            activityViewController.popoverPresentationController?.sourceView = self.view // so that iPads won't crash
            self.present(activityViewController, animated: true, completion: nil)
        }
    }
    
    @IBAction func copyAction(_ sender: Any) {
        guard let address = addressLabel.text else { return }
        UIPasteboard.general.string = address
        self.showAlert(title: "Copied to clipboard ✓", message: address)
    }
    
    private func fetchAddress(completion: @escaping ((message: String?, address: String?)) -> Void) {
        CoreDataService.retrieveEntity(entityName: .wallets) { wallets in
            guard let wallets = wallets, wallets.count > 0 else {
                completion(("No wallet exists yet.", nil))
                return
            }
            
            let wallet = Wallet(wallets[0])
            
            CoreDataService.retrieveEntity(entityName: .receiveAddr) { [weak self] recAddresses in
                guard let self = self else { return }
                guard let recAddresses = recAddresses, recAddresses.count > 0 else {
                    completion(("No receive addresses exist yet.", nil))
                    return
                }
                
                for recAddress in recAddresses {
                    let address = Address_Cache(recAddress)
                    if address.index == wallet.receiveIndex {
                        self.address = address
                        completion((nil, address.address))
                    }
                }
            }
        }
    }
    
    private func loadViews(address: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.addressLabel.text = address
            self.imageView.image = QRGenerator().getQRCode(text: address)
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
