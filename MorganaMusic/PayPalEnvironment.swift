//
//  PayPalEnvironment.swift
//  MorganaMusic
//
//  Created by vscocca on 27/09/18.
//  Copyright © 2018 Vittorio Scocca. All rights reserved.
//

import Foundation
class PayPalEnvironment {
    //PayPalEnvironmentSandbox
    //PayPalEnvironmentProduction
    //Production run only on hardware device
    
    //Production enpoints
    var payPalEnvironmentProduction = ""
    var payPalSecretKeyProduction = ""
    var payPalTokenUrlProduction = ""
    var lookUpPaymentUrlProduction = ""
    
    //Sandbox endpoints
    var payPalEnvironmentSandbox = ""
    var payPalSecretKeySandbox = ""
    var payPalTokenUrlSandBox = ""
    var lookUpPaymentUrlSandBox = ""

    //Enviroment activated on Firease
    var actualEnvironment = ""
    
    init(companyId: String){
        initPayPalEnvironment(companyId: companyId)
    }
    
    private func initPayPalEnvironment(companyId: String){
        FireBaseAPI.readNodeOnFirebaseWithOutAutoId(node: "merchant/\(companyId)/payPalService", onCompletion: { (error, dictionary) in
            guard error == nil else {
                print("Errore di connessione")
                return
            }
            guard dictionary != nil else {
                print("Errore di lettura dell'Ordine richiesto")
                return
            }
            
            for (key,childDictionary) in dictionary! {
                if key == "actualEnvironment" {
                    if childDictionary as! String == "sandBox"{
                        self.actualEnvironment = PayPalEnvironmentSandbox
                    } else {
                        self.actualEnvironment = PayPalEnvironmentProduction
                    }
                } else {
                    guard let dictionary = childDictionary as? NSDictionary else { return }
                    if key == "production" {
                        self.payPalEnvironmentProduction = dictionary["PayPalEnvironmentProduction"] as! String
                        self.payPalSecretKeyProduction = dictionary["secretKey"] as! String
                        self.payPalTokenUrlProduction = dictionary["tokenUrl"] as! String
                        self.lookUpPaymentUrlProduction = dictionary["lookUpPaymentUrl"] as! String
                    } else if key == "sandbox" {
                        self.payPalEnvironmentSandbox = dictionary["PayPalEnvironmentSandbox"] as! String
                        self.payPalSecretKeySandbox = dictionary["secretKey"] as! String
                        self.payPalTokenUrlSandBox = dictionary["tokenUrl"] as! String
                        self.lookUpPaymentUrlSandBox = dictionary["lookUpPaymentUrl"] as! String
                    }
                }
                
            }
            
            PayPalMobile.initializeWithClientIds(forEnvironments: [PayPalEnvironmentProduction: self.payPalEnvironmentProduction,
                                                                   PayPalEnvironmentSandbox: self.payPalEnvironmentSandbox])
            
        })
    }
    
}
