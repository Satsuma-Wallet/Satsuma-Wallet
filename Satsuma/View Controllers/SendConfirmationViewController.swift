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
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("destinationAmount: \(destinationAmount)")

        // Do any additional setup after loading the view.
        addressOutlet.text = destinationAddress
        //print("self.rawTx: \(self.rawTx)")
        
        let feeBtc = Double(fee).btcAmountDouble.avoidNotation
        let destAmount = destinationAmount.avoidNotation
        let total = (Double(fee).btcAmountDouble + destinationAmount).avoidNotation
        networkFeeOutlet.text = "\(feeBtc) BTC"
        addressOutlet.text = destinationAddress
        amountOutlet.text = "\(destAmount) BTC"
        totalAmountOutlet.text = "\(total) BTC"
    }
    
    @IBAction func viewAddressAction(_ sender: Any) {
    }
    
    @IBAction func sendAction(_ sender: Any) {
        MempoolRequest.sharedInstance.command(method: .broadcast(tx: self.rawTx)) { (response, errorDesc) in
            guard let txid = response as? String else {
                showAlert(vc: self, title: "Broadcasting failed.", message: errorDesc ?? "Unknown.")
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let alert = UIAlertController(title: "Transaction sent ✓", message: "", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Done", style: .default, handler: { action in
                    self.navigationController?.popToRootViewController(animated: true)
                }))
                alert.popoverPresentationController?.sourceView = self.view
                self.present(alert, animated: true, completion: nil)
            }
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
