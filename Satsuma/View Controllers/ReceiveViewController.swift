//
//  ReceiveViewController.swift
//  Satsuma
//
//  Created by Peter Denton on 5/10/23.
//

import UIKit

class ReceiveViewController: UIViewController {

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var addressLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        fetchAddress { [weak self] (message, address) in
            guard let self = self else { return }
            
            guard let address = address else {
                showAlert(vc: self, title: "There was an issue fetching your address.", message: message ?? "Unknown.")
                return
            }
            self.loadViews(address: address)
        }
    }
    
    @IBAction func backAction(_ sender: Any) {
        self.dismiss(animated: true)
    }
    
    @IBAction func shareAction(_ sender: Any) {
        let text = addressLabel.text!
        let textToShare:[String] = [text]
        let activityViewController = UIActivityViewController(activityItems: textToShare, applicationActivities: nil)
        activityViewController.popoverPresentationController?.sourceView = self.view // so that iPads won't crash
        activityViewController.excludedActivityTypes = [ UIActivity.ActivityType.airDrop, UIActivity.ActivityType.postToFacebook ]
        self.present(activityViewController, animated: true, completion: nil)
    }
    
    @IBAction func copyAction(_ sender: Any) {
        guard let address = addressLabel.text else { return }
        UIPasteboard.general.string = address
        showAlert(vc: self, title: "Copied to clipboard ✓", message: address)
    }
    
    private func fetchAddress(completion: @escaping ((message: String?, address: String?)) -> Void) {
        CoreDataService.retrieveEntity(entityName: .wallets) { wallets in
            guard let wallets = wallets, wallets.count > 0 else {
                completion(("No wallet exists yet.", nil))
                return
            }
            
            let wallet = Wallet(wallets[0])
            
            CoreDataService.retrieveEntity(entityName: .receiveAddr) { recAddresses in
                guard let recAddresses = recAddresses, recAddresses.count > 0 else {
                    completion(("No receive addresses exist yet.", nil))
                    return
                }
                
                for recAddress in recAddresses {
                    let address = Address_Cache(recAddress)
                    if address.index == wallet.receiveIndex {
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
