//
//  AddressView.swift
//  Satsuma
//
//  Created by Peter Denton on 5/19/23.
//

import UIKit

class AddressView: UIView {

    @IBOutlet var contentView: UIView!
    @IBOutlet weak var address: UILabel!
    @IBOutlet weak var derivation: UILabel!
    @IBOutlet weak var balance: UILabel!
    @IBOutlet weak var closeButton: UIButton!
    
    override init(frame: CGRect) {
        super.init (frame: frame)
        commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init (coder: aDecoder)
        commonInit ()
    }
    
    private func commonInit() {
        Bundle.main.loadNibNamed("AddressView", owner: self)
        addSubview(contentView)
        contentView.frame = bounds
        contentView.layer.cornerRadius = 18
        contentView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
    }
    
    @IBAction func closeAction(_ sender: Any) {
        self.alpha = 0
    }
    
}
