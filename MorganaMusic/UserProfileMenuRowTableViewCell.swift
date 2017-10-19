//
//  userProfileMenuRowTableViewCell.swift
//  MorganaMusic
//
//  Created by Vittorio Scocca on 19/10/17.
//  Copyright © 2017 Vittorio Scocca. All rights reserved.
//

import UIKit

class UserProfileMenuRowTableViewCell: UITableViewCell {

    @IBOutlet var friendImageView: UIImageView!
    @IBOutlet var fullName_label: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.friendImageView.layer.borderWidth = 2.5
        self.friendImageView.layer.borderColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
        self.friendImageView.layer.masksToBounds = false
        self.friendImageView.layer.cornerRadius = friendImageView.frame.height/2
        self.friendImageView.clipsToBounds = true
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
