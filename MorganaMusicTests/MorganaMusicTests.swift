//
//  MorganaMusicTests.swift
//  MorganaMusicTests
//
//  Created by Vittorio Scocca on 28/09/17.
//  Copyright © 2017 Vittorio Scocca. All rights reserved.
//

import XCTest
@testable import MorganaMusic
import FirebaseAuth
import FirebaseDatabase

class MorganaMusicTests: XCTestCase {
    
    let userDestination_fullName = "Vittorio Scocca"
    let userDestination_pictureUrl = "https://goo.gl/v5FFC9"
    let userDestination_idFB = "10212636768259173"
    let userDestination_idApp = "i2bwMowu4tcmJ3tCV68vdiMMWpQ2"
    let userDestination_fireBaseIstanceIDToken = "eNGzn53t8uY:APA91bHVhMrxmfsqxy-h_HlDqAE4wgXbn6YKK5tdY5gHd2y7EOox9QlCZyhLRhKXAoLl6x72xB1yNR7x8F5_05SoRUd4d9lcmtxf5GV8zNEPwER7XphpCK_BDAXEqSOFezRYGbkalLsS"
    
    let userSender_fullName = "Vittorio Caruso Peccerella"
    let userSender_pictureUrl = "https://goo.gl/qZFUYU"
    let userSender_idFB = "104579600272078"
    let userSender_idApp = "qnsRkQjHEMaCe8loU8IcwoC6hil2"
    let userSender_fireBaseIstanceIDToken = "fXMzv1YPXQQ:APA91bGSbbsEa2RFdvibQslokrGpwN6nAO6CHRZyV-k78IeczYRPfLfMap9VHqSM-oZ_mysXAshx-XheZXylrZXPMBhErSZ339geh6FF7pnL4LevI0OeW79lmW3WhnGdYCmiTP0QD_U-"
    
    var product1: Product?
    var product2: Product?
    var userDestination: UserDestination?
    var userSender: UserDestination?
    var order: Order?
    var payment: Payment?
    var company: Company?
    
    
    private func createProducts(productName: String, price: Double, quantity: Int)->Product{
        return Product(productName: productName, price: price, quantity: quantity)
    }
    
    private func createUserDestination(fullName: String, idFB: String, pictureUrl: String, idApp: String, fireBaseIstanceIDToken: String)-> UserDestination{
        return UserDestination(fullName, idFB, pictureUrl, idApp, fireBaseIstanceIDToken)
    }
    
    private func createOrder(products: [Product], userSender: UserDestination, userDestination: UserDestination)->Order{
        return  Order(prodotti: products, userDestination: userDestination, userSender: userSender)
        
    }
    private func addProductToOrder(order: Order, product: Product){
        order.prodotti?.append(product)
    }
    
    private func createPayment( platform: String, paymentType: String, createTime: String, idPayment: String, statePayment: String, autoId: String, total: String)->Payment{
        
        return Payment( platform: platform, paymentType: paymentType, createTime: createTime, idPayment: idPayment, statePayment: statePayment, autoId: autoId, total: total)
    }
    
    private func createCart(){
        self.product1 = createProducts(productName: "Birra", price: 2.50, quantity: 2)
        self.product2 = createProducts(productName: "Rum", price: 5.00, quantity: 2)
        
        self.userDestination = createUserDestination(fullName: userDestination_fullName, idFB: userDestination_idFB, pictureUrl: userDestination_pictureUrl, idApp: userDestination_idApp, fireBaseIstanceIDToken: userDestination_fireBaseIstanceIDToken)
        
        self.userSender = createUserDestination(fullName: userSender_fullName, idFB: userSender_idFB, pictureUrl: userSender_pictureUrl, idApp: userSender_idApp, fireBaseIstanceIDToken: userSender_fireBaseIstanceIDToken)
        
        let products = [product1!,product2!]
        
        self.order = createOrder(products: products, userSender: userSender!, userDestination: userDestination!)
        
        
        
        self.payment = createPayment(platform: "iOS", paymentType: "PayPal", createTime: "2017-09-25T12:25:38Z", idPayment: "test_PAY-9YC496555W193134HLHFBRHI", statePayment: "terminated", autoId: "", total: "15.00")
        
        self.company = Company(userId: self.userSender_idApp, city: "Benevento", companyName: "Morgana Music Club")
        
        
        Cart.sharedIstance.paymentMethod = self.payment
        Cart.sharedIstance.carrello.append(self.order!)
        Cart.sharedIstance.state = "Valid"
        Cart.sharedIstance.company = self.company
        print(Cart.sharedIstance.carrello.count)
    }
    func testFirebaseData_SaveCartOnFirebase() {
        print("testFirebaseData_SaveCartOnFirebase")
        createCart()
        
        let fireBaseUser = Auth.auth().currentUser
        
        let user = CoreDataController.sharedIstance.findUserForIdApp((fireBaseUser?.uid))
        /*
        FirebaseData.sharedIstance.saveCartOnFirebase(user: user!, badgeValue: 1, onCompletion: {
            print("ordine salvato su firebase")
            
            if Cart.sharedIstance.state == "Valid" {
                print("Pagamento carrello valido")
                
                PointsManager.sharedInstance.readUserPointsStatsOnFirebase(onCompletion: { (error) in
                    guard error == nil else {
                        print(error!)
                        return
                    }
                    let points = PointsManager.sharedInstance.addPointsForShopping(expense: Cart.sharedIstance.costoTotale)
                    PointsManager.sharedInstance.updateNewValuesOnFirebase(onCompletion: {
                        
                        NotitificationsCenter.localNotification(title: "Congratulazioni \((user?.firstName)!)", body: "Hai appena cumulato \(points) Punti!")
                    })
                    
                    print("Punti aggiornati")
                    Cart.sharedIstance.initializeCart()
                })
            } else {
                print("Pagamento carrello non valido, riprova")
            }
        })
        FireBaseAPI.saveNodeOnFirebaseWithAutoId(node: "orderSentTest", child: (user?.idApp)!, dictionaryToSave: ["test": 1], onCompletion: {
            (error) in
            
        })
        
        FireBaseAPI.readNodeOnFirebase(node: "users/"+(user?.idApp)!, onCompletion: { (error,dictionary) in
            print(dictionary!["nome completo"] as! String)
        })*/
        let ref = Database.database().reference()
        ref.child("orderSentTest").child((user?.idApp)!).setValue(["test": 1])
        
        //XCTAssert(done, "Completion should be called")
    }
    
    
}