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
    var uid: String?
    
    let fbToken = UserDefaults.standard
    let fireBaseToken = UserDefaults.standard
    var productOfferedBadge = UserDefaults.standard
    
    
    
    private init(){
    }
    
    func updateBadgeInformations(nsArray: NSArray?){
        self.uid = fireBaseToken.object(forKey: "FireBaseToken") as? String
        self.user = CoreDataController.sharedIstance.findUserForIdApp(uid)
        
        guard CheckConnection.isConnectedToNetwork() == true else {
            print("connessione assente")
            return
        }
        
        let ref = Database.database().reference()
        ref.child("users/" + (self.user?.idApp)!).observe(.value, with: { (snap) in
            
           
            guard snap.exists() else {return}
            guard snap.value != nil else {return}
            
            let datiUtente = snap.value! as! NSDictionary
            
            // read offers data
            for (chiave,valore) in datiUtente {
                switch chiave as! String {
                case "numberOfPendingReceivedProducts":
                    self.productOfferedBadge.set(valore as! Int, forKey: "productOfferedBadge")
                    break
                case "ì":
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
                let paymentVal = self.productOfferedBadge.object(forKey: "paymentOfferedBadge") as! Int
                tabItem.badgeValue = String(describing: (val + paymentVal))
                
            } else if (self.productOfferedBadge.object(forKey: "productOfferedBadge") as? Int == 0) && self.productOfferedBadge.object(forKey: "paymentOfferedBadge") as? Int == 0{
                tabItem.badgeValue = nil
            }
        })
    }
}





