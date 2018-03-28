//
//  LoadRemoteProducts.swift
//  MorganaMusic
//
//  Created by Vittorio Scocca on 23/02/18.
//  Copyright © 2018 Vittorio Scocca. All rights reserved.
//

import Foundation
import FirebaseDatabase
import FirebaseAuth

public extension NSNotification.Name {
    static let RemoteProductsListDidChange = NSNotification.Name("RemoteProductsListDidChangeNotification")
}

class LoadRemoteProducts {
    public static let instance = LoadRemoteProducts(dispatchQueue: DispatchQueue.main,
                                                    networkStatus: NetworkStatus.default,
                                                    notificationCenter: NotificationCenter.default,
                                                    uiApplication: UIApplication.shared)
    
    private var dispatchQueue: DispatchQueue
    private var networkStatus: NetworkStatus
    private var notificationCenter: NotificationCenter
    private let uiApplication: UIApplication
    
    private var productsList: [String]? = [String]()
    private var offersDctionary: [String : Double]? = [String : Double]()
    
    var products: [String]? {
        return productsList
    }
    
    var offers: [String : Double]? {
        return offersDctionary
    }
    
    init(dispatchQueue: DispatchQueue, networkStatus: NetworkStatus, notificationCenter: NotificationCenter, uiApplication: UIApplication) {
        self.dispatchQueue = dispatchQueue
        self.networkStatus = networkStatus
        self.notificationCenter = notificationCenter
        self.uiApplication = uiApplication
        
        self.notificationCenter.addObserver(self,
                                            selector: #selector(networkStatusDidChange),
                                            name: .NetworkStatusDidChange,
                                            object: self.networkStatus)
        
        
        self.notificationCenter.addObserver(self,
                                            selector: #selector(applicationWillEnterForeground),
                                            name: .UIApplicationWillEnterForeground,
                                            object: uiApplication)
        
        loadRemoteProducts()
    }
    deinit {
       notificationCenter.removeObserver(self)
    }
    
    @objc func networkStatusDidChange(){
        loadRemoteProducts()
    }
    
    @objc func applicationWillEnterForeground(){
        print("Entering in foreground: Reload products")
        loadRemoteProducts()
    }
    
    func loadRemoteProducts(){
        guard networkStatus.online else {
            self.productsList = nil
            self.offersDctionary = nil
            return
        }
        
        FireBaseAPI.readNodeOnFirebase(node: "merchant products", onCompletion: { (error, dictionary) in
            guard error == nil else {
                self.productsList = nil
                self.offersDctionary = nil
                return
            }
            guard dictionary != nil else {
                return
            }
            
            self.productsList = [String]()
            self.offersDctionary = [String : Double]()
            
            for (prodotto, costo) in dictionary! {
                if prodotto != "autoId" {
                    let prodottoConCosto = prodotto
                    self.productsList!.append(prodottoConCosto)
                    self.offersDctionary![prodotto] = costo as? Double
                    print("Prodotto caricato \(prodotto)")
                }
            }
            self.dispatchQueue.async {
                print("Notifying products change")
                self.notificationCenter.post(name: .RemoteProductsListDidChange, object: self)
            }
            
        })
    }
    
    func isNotNull() -> Bool {
        return productsList != nil && offersDctionary != nil
    }
    
    func isNotEmpty()-> Bool {
        if isNotNull() {
            return !(productsList?.isEmpty)! && !(offersDctionary?.isEmpty)!
        }else {
            return false
        }
        
    }
    
    
}
