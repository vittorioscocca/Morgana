//
//  PaymentTableViewCell.swift
//  MorganaMusic
//
//  Created by Vittorio Scocca on 17/05/17.
//  Copyright © 2017 Vittorio Scocca. All rights reserved.
//

import UIKit

class PaymentTableViewCell: UITableViewCell {

    @IBOutlet var brandCompany: UIImageView!
    @IBOutlet var nameCompany: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
