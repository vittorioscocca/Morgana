//
//  CompanyDaysParametersTableViewCell.swift
//  MorganaMusic
//
//  Created by Vittorio Scocca on 23/10/17.
//  Copyright © 2017 Vittorio Scocca. All rights reserved.
//

import UIKit

class CompanyDaysParametersTableViewCell: UITableViewCell {

    @IBOutlet var daysOfWeek: UILabel!
    @IBOutlet var daysSelected: UISwitch!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
