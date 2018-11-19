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
        return Product(productName: productName, price: price, quantity: quantity, points: nil
        )
    }
    
    private func createUserDestination(fullName: String, idFB: String, pictureUrl: String, idApp: String, fireBaseIstanceIDToken: String)-> UserDestination{
        return UserDestination(fullName, idFB, pictureUrl, idApp, fireBaseIstanceIDToken)
    }
    
    private func createOrder(products: [Product], userSender: UserDestination, userDestination: UserDestination)->Order{
        return  Order(prodotti: products, userDestination: userDestination, userSender: userSender)
        
    }
    private func addProductToOrder(order: Order, product: Product){
        order.products?.append(product)
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
        
        FirebaseData.sharedIstance.saveCartOnFirebase(user: user!, badgeValue: 1, onCompletion: {
            print("ordine salvato su firebase")
            
            if Cart.sharedIstance.state == "Valid" {
                print("Pagamento carrello valido")
                
                PointsManager.sharedInstance.readUserPointsStatsOnFirebase(userId: (user?.idApp)!, onCompletion: { (error) in
                    guard error == nil else {
                        print(error!)
                        return
                    }
                    let points = PointsManager.sharedInstance.addPointsForShopping(userId: (user?.idApp)!, expense: Cart.sharedIstance.costoTotale)
                    PointsManager.sharedInstance.updateNewValuesOnFirebase(actualUserId: (user?.idApp)!, onCompletion: {
                        
                        NotificationsCenter.scheduledRememberExpirationLocalNotification(title: "Congratulazioni \((user?.firstName)!)", body: "Hai appena cumulato \(points) Punti!", identifier: "")
                    })
                    
                    print("Punti aggiornati")
                    Cart.sharedIstance.initializeCart()
                })
            } else {
                print("Pagamento carrello non valido, riprova")
            }
            XCTAssertEqual(Cart.sharedIstance.state, "Valid")
        })
    }
    
    func testFirebaseData_ReadOrderSent(){
        let fireBaseUser = Auth.auth().currentUser
        let user = CoreDataController.sharedIstance.findUserForIdApp((fireBaseUser?.uid))
        CoreDataController.sharedIstance.loadAllFriendsOfUser(idAppUser: (fireBaseUser?.uid)!, completion: {(friendList) in
            FirebaseData.sharedIstance.readOrdersSentOnFireBase(user: user!, friendsList: friendList, onCompletion: {(ordersSent) in
                for order in ordersSent {
                    XCTAssertEqual(order.userDestination?.fullName, "Vittorio Scocca")
                    XCTAssertEqual(order.userDestination?.idApp, "i2bwMowu4tcmJ3tCV68vdiMMWpQ2")
                    XCTAssertEqual(order.userDestination?.idFB, "10212636768259173")
                    XCTAssertEqual(order.userDestination?.fireBaseIstanceIDToken, "eNGzn53t8uY:APA91bHVhMrxmfsqxy-h_HlDqAE4wgXbn6YKK5tdY5gHd2y7EOox9QlCZyhLRhKXAoLl6x72xB1yNR7x8F5_05SoRUd4d9lcmtxf5GV8zNEPwER7XphpCK_BDAXEqSOFezRYGbkalLsS")
                    XCTAssertEqual(order.userDestination?.pictureUrl, "https://goo.gl/v5FFC9")
                    XCTAssertEqual(order.products![0].productName, "Birra")
                }
            })
        })
    }
}
