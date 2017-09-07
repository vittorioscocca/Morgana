//
//  UserDestination.swift
//  MorganaMusic
//
//  Created by Vittorio Scocca on 27/04/17.
//  Copyright © 2017 Vittorio Scocca. All rights reserved.
//

import Foundation

class UserDestination{
    
    static let sharedIstance = UserDestination()
    
    var fullName: String?
    var idFB: String?
    var pictureUrl: String?
    var idApp: String?
    var fireBaseIstanceIDToken: String?
    
    private init(){
        
    }
    
    
    init(_ fullName: String?, _ idFB: String?, _ pictureUrl: String?, _ idApp: String?, _ fireBaseIstanceIDToken: String?){
        self.fullName = fullName
        self.idFB = idFB
        self.pictureUrl = pictureUrl
        self.idApp = idApp
        self.fireBaseIstanceIDToken = fireBaseIstanceIDToken
    }
    
    
}
