//
//  MorganaMusicSettings.swift
//  MorganaMusic
//
//  Created by Vittorio Scocca on 05/10/17.
//  Copyright © 2017 Vittorio Scocca. All rights reserved.
//

import Foundation
import UIKit

extension AppDelegate{
    
    func MorganaMusicActivate(){
        let storybard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storybard.instantiateViewController(withIdentifier: "HomeViewController") //HomeViewController
        self.window?.rootViewController = vc
    }
    
}
