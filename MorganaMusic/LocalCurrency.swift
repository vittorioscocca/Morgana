//
//  LocalCurrency.swift
//  MorganaMusic
//
//  Created by vscocca on 10/12/2018.
//  Copyright © 2018 Vittorio Scocca. All rights reserved.
//

import Foundation
class LocalCurrency: NSObject {
    public static let instance = LocalCurrency()
    
    let currencyFormatter = NumberFormatter()
    
    override init() {
        currencyFormatter.usesGroupingSeparator = true
        currencyFormatter.numberStyle = .currency
        
        // localize to your grouping and decimal separator
        currencyFormatter.locale = Locale.current
        
        super.init()
    }
    
    func getLocalCurrency(currency: NSNumber)-> String {
        return currencyFormatter.string(from: currency) ?? "0,00"
    }
    
}
