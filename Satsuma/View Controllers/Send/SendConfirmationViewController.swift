//
//  SendConfirmationViewController.swift
//  Satsuma
//
//  Created by Peter Denton on 5/17/23.
//

import UIKit

class SendConfirmationViewController: UIViewController {
    var rawTx = ""
    var fee = 0
    var destinationAddress = ""
    var destinationAmount = 0.0

    @IBOutlet weak var addressOutlet: UILabel!
    @IBOutlet weak var amountOutlet: UILabel!
    @IBOutlet weak var networkFeeOutlet: UILabel!
    @IBOutlet weak var totalAmountOutlet: UILabel!
    @IBOutlet weak var addressView: AddressView!
    @IBOutlet weak var fiatAmountOutlet: UILabel!
    @IBOutlet weak var fiatNetworkFeeOutlet: UILabel!
    @IBOutlet weak var fiatTotalOutlet: UILabel!

    
    override func viewDidLoad() {
        super.viewDidLoad()

        confirgureAddressViews()
        confirgureBtcAmountLabels()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        // Fetch the fiat exchange rate so fiat values can be displayed.
        let fiat = UserDefaults.standard.object(forKey: "fiat") as? String ?? "USD"
        
        FiatConverter.sharedInstance.getFxRate(currency: fiat) { fxRate in
            guard let fxRate = fxRate else { return }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.fiatAmountOutlet.text = destinationAmount.fiatBalance(fxRate: fxRate)
                self.fiatNetworkFeeOutlet.text = Double(fee).btcAmountDouble.fiatBalance(fxRate: fxRate)
                self.fiatTotalOutlet.text = (Double(fee).btcAmountDouble + destinationAmount).fiatBalance(fxRate: fxRate)
            }
        }
    }
    
    // The "eye" button action, shows the address detail.
    @IBAction func viewAddressAction(_ sender: Any) {
        addressView.alpha = 1
    }
    
    // The "send" button action. Broadcasts the transaction, the txid is returned if successful.
    @IBAction func sendAction(_ sender: Any) {
        self.addSpinnerView(description: "sending...")
        MempoolRequest.sharedInstance.command(method: .broadcast(tx: self.rawTx)) { [weak self] (response, errorDesc) in
            guard let self = self else { return }
            
            // Ensures the txid is returned, if not something failed.
            guard let txid = response as? String else {
                self.removeSpinnerView()
                self.showAlert(title: "Broadcasting failed.", message: errorDesc ?? "Unknown.")
                return
            }
            
            // MARK: - TODO Save the txid and other relevant info, inputs/outputs/amounts/note/date/time/etc...
            
            // Shows the success alert, the done button navigates us back to home which automatically refreshes the balance.
            self.showSuccesAlert()
        }
    }
    
    private func showSuccesAlert() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.removeSpinnerView()
            let alert = UIAlertController(title: "Transaction sent ✓", message: "", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Done", style: .default, handler: { action in
                // Navigates home.
                self.navigationController?.popToRootViewController(animated: true)
            }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    // Confirgures the address views.
    private func confirgureAddressViews() {
        addressView.alpha = 0
        addressView.derivation.alpha = 0
        addressView.balance.alpha = 0
        addressView.address.text = destinationAddress
        addressOutlet.text = destinationAddress
        addressView.address.text = destinationAddress
    }
    
    // Adds the btc amounts to our labels.
    private func confirgureBtcAmountLabels() {
        let feeBtc = Double(fee).btcBalance
        let destAmount = (destinationAmount * 100000000.0).btcBalance
        let total = (Double(fee) + destinationAmount * 100000000.0).btcBalance
        networkFeeOutlet.text = feeBtc
        amountOutlet.text = destAmount
        totalAmountOutlet.text = total
    }
}
