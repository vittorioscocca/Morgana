//
//  FirendsListTableViewCell.swift
//  MorganaMusic
//
//  Created by Vittorio Scocca on 12/04/17.
//  Copyright © 2017 Vittorio Scocca. All rights reserved.
//

import UIKit

class FirendsListTableViewCell: UITableViewCell {

    @IBOutlet weak var friendImageView: UIImageView!
    @IBOutlet weak var friendName: UILabel!
    @IBOutlet weak var forwardButton: UIButton!
    @IBOutlet var cityOfRecidence: UILabel!
    
    
    
    var idFB: String?
    var friendImageUrl: String?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        self.friendImageView.layer.borderWidth = 2.5
        self.friendImageView.layer.borderColor = #colorLiteral(red: 0.7419371009, green: 0.1511851847, blue: 0.20955199, alpha: 1)
        self.friendImageView.layer.masksToBounds = false
        self.friendImageView.layer.cornerRadius = friendImageView.frame.height/2
        self.friendImageView.clipsToBounds = true
    }
    
    
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
        if selected == true {
            self.backgroundColor = UIColor(red: 248/255, green: 179/255, blue: 52/255, alpha: 1)
        } else {
            self.backgroundColor = UIColor(red: 1, green: 1, blue: 1, alpha: 1)
        }
    }
    
    
    

}
