//
//  CompanyParametersTableViewCell.swift
//  MorganaMusic
//
//  Created by Vittorio Scocca on 23/10/17.
//  Copyright © 2017 Vittorio Scocca. All rights reserved.
//

import UIKit

class CompanyParametersTableViewCell: UITableViewCell {

    
    @IBOutlet var parameterName: UILabel!
    @IBOutlet var parameterValue: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
