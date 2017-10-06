//
//  AutOrderTableViewCell.swift
//  MorganaMusic
//
//  Created by Vittorio Scocca on 05/10/17.
//  Copyright © 2017 Vittorio Scocca. All rights reserved.
//

import UIKit

class AutOrderTableViewCell: UITableViewCell {

    @IBOutlet var productName_label: UILabel!
    @IBOutlet var productQuantity_label: UILabel!
    @IBOutlet var myStepper: UIStepper!
    
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
