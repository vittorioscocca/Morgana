//
//  Prodotto.swift
//  MorganaMusic
//
//  Created by Vittorio Scocca on 26/04/17.
//  Copyright © 2017 Vittorio Scocca. All rights reserved.
//

import Foundation
class Product {
    static let sharedIstance = Product()
    
    var productName: String?
    var price: Double?
    var quantity: Int?
    var points: Int?
    
    private init(){
    }

    
    init(productName: String?, price: Double?, quantity: Int?, points: Int?){
        self.productName = productName
        self.price = price
        self.quantity = quantity
        self.points = points
    }
}
