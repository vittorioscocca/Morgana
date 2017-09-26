//
//  OfferteRicevuteTableViewCell.swift
//  MorganaMusic
//
//  Created by Vittorio Scocca on 09/06/17.
//  Copyright © 2017 Vittorio Scocca. All rights reserved.
//

import UIKit

class OrderReceivedTableViewCell: UITableViewCell {

    @IBOutlet var friendImageView: UIImageView!
    @IBOutlet var friendFullName: UILabel!
    @IBOutlet var productus: UILabel!
    @IBOutlet var createDate: UILabel!
    @IBOutlet var lastDate: UILabel!
    @IBOutlet var cost: UILabel!
    
    var cellReaded = false
    var orderOfferedAutoId: String!
    var orderReceivedAutoId: String!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        self.friendImageView.layer.borderWidth = 2.5
        self.friendImageView.layer.borderColor = #colorLiteral(red: 0.7419371009, green: 0.1511851847, blue: 0.20955199, alpha: 1)
        self.friendImageView.layer.masksToBounds = false
        self.friendImageView.layer.cornerRadius = friendImageView.frame.height/2
        self.friendImageView.clipsToBounds = true
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
        if selected == true || !cellReaded {
            self.backgroundColor = UIColor(red: 243/255, green: 239/255, blue: 237/255, alpha: 1.0)
        }else {
            self.backgroundColor = UIColor(red: 1, green: 1, blue: 1, alpha: 1)
        }
    }
}
