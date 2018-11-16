//
//  UpdateBadgeInfo.swift
//  MorganaMusic
//
//  Created by Vittorio Scocca on 22/06/17.
//  Copyright © 2017 Vittorio Scocca. All rights reserved.
//

import UIKit
import FBSDKCoreKit
import FBSDKLoginKit
import Firebase
import Foundation
import SystemConfiguration


class UpdateBadgeInfo {
    static let sharedIstance = UpdateBadgeInfo()
    var user: User?
    var productOfferedBadge = UserDefaults.standard
    
    private init(){
    }
    
    func updateBadgeInformations(nsArray: NSArray?){
        self.user = CoreDataController.sharedIstance.findUserForIdApp(Auth.auth().currentUser?.uid)
        
        guard CheckConnection.isConnectedToNetwork() == true else {
            print("connessione assente")
            return
        }
        
        guard let userIdApp = user?.idApp else { return }
        
        let ref = Database.database().reference()
        ref.child("users/" + userIdApp).observe(.value, with: { (snap) in
            guard snap.exists() else {return}
            guard snap.value != nil else {return}
            
            let datiUtente = snap.value! as! NSDictionary
            
            // read offers data
            for (chiave,valore) in datiUtente {
                switch chiave as! String {
                case "numberOfPendingReceivedProducts":
                    self.productOfferedBadge.set(valore as! Int, forKey: "productOfferedBadge")
                    break
                    
                case "numberOfPendingPurchasedProducts":
                    self.productOfferedBadge.set(valore as! Int, forKey: "paymentOfferedBadge")
                    break
                default:
                    break
                }
            }
            let tabItems = nsArray
            
            //  modify the badge number of the third tab
            let tabItem = tabItems?[2]  as! UITabBarItem
            if (self.productOfferedBadge.object(forKey: "productOfferedBadge") as? Int != 0) || self.productOfferedBadge.object(forKey: "paymentOfferedBadge") as? Int != 0 {
                // Now set the badge of the third tab
                let val = self.productOfferedBadge.object(forKey: "productOfferedBadge") as! Int
                if let paymentVal = self.productOfferedBadge.object(forKey: "paymentOfferedBadge") as? Int {
                    tabItem.badgeValue = String(describing: (val + paymentVal))
                }
            } else if (self.productOfferedBadge.object(forKey: "productOfferedBadge") as? Int == 0) && self.productOfferedBadge.object(forKey: "paymentOfferedBadge") as? Int == 0{
                tabItem.badgeValue = nil
            }
        })
    }
}





