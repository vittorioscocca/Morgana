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
    private var offersDictionary: [String : Double]? = [String : Double]()
    
    var products: [String]? {
        return productsList
    }
    
    var offers: [String : Double]? {
        return offersDictionary
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
        
        self.notificationCenter.addObserver(self,
                                            selector: #selector(loadRemoteProducts),
                                            name: .FirebaseTokenDidChangeNotification,
                                            object: nil)
        
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
    
    @objc func loadRemoteProducts(){
        guard networkStatus.online else {
            self.productsList = nil
            self.offersDictionary = nil
            return
        }
        
        FireBaseAPI.readNodeOnFirebase(node: "merchant products", onCompletion: { (error, dictionary) in
            guard error == nil else {
                self.productsList = nil
                self.offersDictionary = nil
                return
            }
            guard let productsDictionary = dictionary else {
                return
            }
            
            self.productsList = [String]()
            self.offersDictionary = [String : Double]()
            
            for (prodotto, costo) in productsDictionary {
                if prodotto != "autoId" {
                    let prodottoConCosto = prodotto
                    self.productsList!.append(prodottoConCosto)
                    self.offersDictionary![prodotto] = costo as? Double
                }
            }
            self.productsList = self.productsList?.sorted{ $0 < $1 }
            self.dispatchQueue.async {
                print("Notifying products change")
                self.notificationCenter.post(name: .RemoteProductsListDidChange, object: self)
            }
            
        })
    }
    
    func isNotNull() -> Bool {
        return productsList != nil && offersDictionary != nil
    }
    
    func isNotEmpty()-> Bool {
        if isNotNull() {
            return !(productsList?.isEmpty)! && !(offersDictionary?.isEmpty)!
        }else {
            return false
        }
        
    }
    
    
}
