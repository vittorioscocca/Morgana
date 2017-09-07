//
//  OfferteInviateTableViewCell.swift
//  MorganaMusic
//
//  Created by Vittorio Scocca on 25/05/17.
//  Copyright © 2017 Vittorio Scocca. All rights reserved.
//

import UIKit

class OrderSentTableViewCell: UITableViewCell {

    @IBOutlet var friendImageView: UIImageView!
    @IBOutlet var friendFullName: UILabel!
    @IBOutlet var productus: UILabel!
    @IBOutlet var createDate: UILabel!
    @IBOutlet var lastDate: UILabel!
    @IBOutlet var cost: UILabel!
    
    var cellReaded = false
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        //self.friendImageView.layer.borderWidth = 0.5
        self.friendImageView.layer.masksToBounds = false
        //self.friendImageView.layer.borderColor = UIColor..cgColor
        self.friendImageView.layer.cornerRadius = friendImageView.frame.height/2
        self.friendImageView.clipsToBounds = true
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
        if selected == true || !cellReaded {
            self.backgroundColor = UIColor(red: 242/255, green: 239/255, blue: 237/255, alpha: 1.0)
        } else {
            self.backgroundColor = UIColor(red: 1, green: 1, blue: 1, alpha: 1)
        }
    
    }

}
