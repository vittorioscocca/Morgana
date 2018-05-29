//
//  PaymentsManager.swift
//  MorganaMusic
//
//  Created by Vittorio Scocca on 25/08/17.
//  Copyright © 2017 Vittorio Scocca. All rights reserved.
//

import Foundation
import FirebaseDatabase
import Firebase

class PaymentManager {
    static let sharedIstance = PaymentManager()
    
    var payment: Payment?
    
    private init(){
        
    }
    
    func resolvePendingPayPalPayment(user: User, payment: Payment, onCompleted: @escaping (Bool)->()){
        self.payment = payment
        
        //******ENTER IN TESTING CASE*************
        //Code for testing, exclude Payments  for Test
        guard payment.idPayment?.range(of: "test")  == nil else {
            self.setPaymentAndOrderCompletedOnFirebase(user: user)
            self.prepareNotification(user: user)
            self.sendReceiptByEmail()
            self.saveReceiptOnFireBase()
            onCompleted(true)
            return
        }
        
        self.getPayPalAccessToken(){ (payPalAccessToken) in
            guard payPalAccessToken != nil else {
                onCompleted(false)
                return
            }
            self.verifyPendingPaypalPayment(user: user, access_token: payPalAccessToken, onCompleted: { (paymentVerified) in
                onCompleted(paymentVerified)
            })
        }
    }
    
    private func getPayPalAccessToken(onCompleted: @escaping (String?)->()){
        /*
         // PayPal server curl request
         curl -v https://api.sandbox.paypal.com/v1/oauth2/token \
         -H "Accept: application/json" \
         -H "Accept-Language: en_US" \
         -u "AfN_l2vZFwYniDa6bpCW3NmqrD4wX0VV7vH3VdDUb0Fjxsw2__X9gC0fee2VNKus-mRuvN4oHCjPJyBl:ECdrVG4XzWKF2BaMqJ_lLMoHQruvf141-lp8lltUKNfyOEgJMTRQtid3qNHAVRbVOQwvBlJrnvXEHggl" \
         -d "grant_type=client_credentials"
         
         */
        //production
        //https://api.paypal.com/v1/oauth2/token
        //sandbox
        //https://api.sandbox.paypal.com/v1/oauth2/token
        
        if let url = NSURL(string: "https://api.sandbox.paypal.com/v1/oauth2/token") {
            let request = NSMutableURLRequest(url: url as URL)
            request.httpMethod = "POST" //Or GET if that's what you need
            
            //set http header
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            request.addValue("en_US", forHTTPHeaderField: "Accept-Language")
            //this content type don' ude json input
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            
            let client_id = "AfN_l2vZFwYniDa6bpCW3NmqrD4wX0VV7vH3VdDUb0Fjxsw2__X9gC0fee2VNKus-mRuvN4oHCjPJyBl"
            let secret = "ECdrVG4XzWKF2BaMqJ_lLMoHQruvf141-lp8lltUKNfyOEgJMTRQtid3qNHAVRbVOQwvBlJrnvXEHggl"
            
            
            let userPasswordString = client_id+":"+secret
            let userPasswordData = userPasswordString.data(using: String.Encoding.utf8)
            let base64EncodedCredential = userPasswordData!.base64EncodedString()
            let authString = "Basic \(base64EncodedCredential)"
            
            request.addValue(authString, forHTTPHeaderField: "Authorization")
            
            let httpData = "grant_type=client_credentials".data(using: String.Encoding.utf8)
            request.httpBody = httpData
            let session = URLSession.shared
            session.dataTask(with: request as URLRequest, completionHandler: { (returnData, response, error) -> Void in
                let strData = NSString(data: returnData!, encoding: String.Encoding.utf8.rawValue)
                print("\(strData!)")
                
                var dataDictionary: NSDictionary?
                //Validazione e deserializzazione del retunData in JSON
                do {
                    let json = try JSONSerialization.jsonObject(with: returnData!, options: JSONSerialization.ReadingOptions.mutableContainers)
                    dataDictionary = (json as? NSDictionary)
                } catch _ {
                    print("[ERRORE] Errore con il parsing del json data")
                }
                let payPalAccessToken = dataDictionary?["access_token"] as? String
                
                onCompleted(payPalAccessToken)
            }).resume()
        }
    }
    
    private func verifyPendingPaypalPayment(user: User, access_token: String?, onCompleted: @escaping (Bool)->()){
        guard access_token != "" else {
            print("token non esistente")
            onCompleted(false)
            return
        }
        self.lookUpPayPalPayment(access_token: access_token){ (PayPalPaymentDataDictionary) in
            guard PayPalPaymentDataDictionary != nil else {
                return
            }
            
            var stateResponse: String?
            var totalResponse: String?
            var currencyResponse: String?
            var stateRelatedResourceSale: String?
            for (ch1,val1) in PayPalPaymentDataDictionary! {
                switch ch1 as! String {
                case "state":
                    stateResponse = val1 as? String
                    break
                case "transactions":
                    let transactions_array: NSArray = (val1 as? NSArray)!
                    let transactions_dictionary: NSDictionary = transactions_array[0] as! NSDictionary
                    for (ch2,val2) in transactions_dictionary {
                        switch ch2 as! String {
                        case "amount":
                            for (ch3,val3) in (val2 as? NSDictionary)!{
                                switch ch3 as! String {
                                case "total":
                                    totalResponse = val3 as? String
                                    break
                                case "currency":
                                    currencyResponse = val3 as? String
                                    break
                                default:
                                    break
                                }
                            }
                            break
                        case "related_resources":
                            let relatedresources_array: NSArray = (val2 as? NSArray)!
                            let relatedresources_dictionary: NSDictionary = relatedresources_array[0] as! NSDictionary
                            for (ch4,val4) in relatedresources_dictionary {
                                switch ch4 as! String {
                                case"sale":
                                    for (ch5,val5) in (val4 as? NSDictionary)! {
                                        switch ch5 as! String {
                                        case "state":
                                            stateRelatedResourceSale = val5 as? String
                                            break
                                        default:
                                            break
                                        }
                                    }
                                    break
                                default:
                                    break
                                }
                            }
                            break
                        default:
                            break
                        }
                    }
                    break
                default:
                    break
                }
            }
            guard stateResponse == "approved" else {
                print("state payement is not approved")
                onCompleted(false)
                return
            }
            guard totalResponse == self.payment?.total else{
                print("state payement is not approved")
                onCompleted(false)
                return
            }
            guard currencyResponse == "EUR" else{
                print("state payement is not approved")
                onCompleted(false)
                return
            }
            guard stateRelatedResourceSale == "completed" else{
                print("state payement is not approved")
                onCompleted(false)
                return
            }
            
            self.setPaymentAndOrderCompletedOnFirebase(user: user)
            self.prepareNotification(user: user)
            self.sendReceiptByEmail()
            self.saveReceiptOnFireBase()
            onCompleted(true)
        }
    }
    
    private func lookUpPayPalPayment (access_token: String?,onCompleted: @escaping (NSDictionary?)->()) {
        /*
         curl https://api.sandbox.paypal.com/v1/payments/payment/PAY-5YK922393D847794YKER7MUI \
         -H "Content-Type: application/json" \
         -H "Authorization: Bearer accessToken"*/
        
        //production endpoint
        //https://api.paypal.com/v1/payments/payment/{payment_id}
        //sandbox
        //https://api.sandbox.paypal.com/v1/payments/payment/
        if let url = NSURL(string: "https://api.sandbox.paypal.com/v1/payments/payment/"+(self.payment?.idPayment)!) {
            let request = NSMutableURLRequest(url: url as URL)
            request.httpMethod = "GET" //Or GET if that's what you need
            
            //set http header
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.addValue("Bearer "+access_token!, forHTTPHeaderField: "Authorization")
            
            /*
             let httpData = "grant_type=client_credentials".data(using: String.Encoding.utf8)
             request.httpBody = httpData
             */
            let session = URLSession.shared
            session.dataTask(with: request as URLRequest, completionHandler: { (returnData, response, error) -> Void in
                let strData = NSString(data: returnData!, encoding: String.Encoding.utf8.rawValue)
                print("PAYPAL VERIFY PAYMENT RESPONSE  \(strData!)")
                let PayPalPaymentDataDictionary: NSDictionary?
                do {
                    let json = try JSONSerialization.jsonObject(with: returnData!, options: JSONSerialization.ReadingOptions.mutableContainers)
                    
                    PayPalPaymentDataDictionary = (json as? NSDictionary)
                    onCompleted(PayPalPaymentDataDictionary)
                    
                } catch _ {
                    print("[ERRORE] Errore con il parsing del json data")
                }
            }).resume()
        }
        
    }
    
    private func setPaymentAndOrderCompletedOnFirebase(user: User){
        let ref = Database.database().reference()
        ref.child("pendingPayments/\((user.idApp)!)/\((self.payment?.company?.companyId)!)/\((self.payment?.autoId)!)").updateChildValues(["stateCartPayment":"Valid","statePayment" : "terminated"])
        for relatedOrders in (self.payment?.relatedOrders)! {
            ref.child("ordersSent/\((user.idApp)!)/\((self.payment?.company?.companyId)!)/\(relatedOrders)").updateChildValues(["paymentState" : "Valid"])
            self.setOrderReceivedCompletedOnFirebase(user: user, autiIdOrderReceived: relatedOrders)
        }
    }
    
    private func setOrderReceivedCompletedOnFirebase(user: User, autiIdOrderReceived: String){
        let ref = Database.database().reference()
        ref.child("ordersSent/\((user.idApp)!)/\((self.payment?.company?.companyId)!)/\(autiIdOrderReceived)").observeSingleEvent(of: .value, with: { (snap) in
            guard snap.exists() else {return}
            guard snap.value != nil else {return}
            
            var userDestination: String?
            var ordersSentAutoId : String?
            let dizionario_offerte = snap.value! as! NSDictionary
            
            for (chiave,valore) in dizionario_offerte {
                
                switch chiave as! String {
                case "IdAppUserDestination":
                    userDestination = valore as? String
                    break
                case "ordersSentAutoId":
                    ordersSentAutoId = valore as? String
                    break
                default:
                    break
                }
            }
            if  userDestination != nil && ordersSentAutoId != nil {
                ref.child("ordersReceived/\((userDestination!))/\((self.payment?.company?.companyId)!)/\((ordersSentAutoId!))").updateChildValues(["paymentState" : "Valid"])
            }
        })
    }
    
    private func prepareNotification(user: User){
        let ref = Database.database().reference()
        for relatedOrders in (self.payment?.relatedOrders)! {
            ref.child("ordersSent/\((user.idApp)!)/\((self.payment?.company?.companyId)!)/\(relatedOrders)").observeSingleEvent(of: .value, with: { (snap) in
                guard snap.exists() else {return}
                guard snap.value != nil else {return}
                
                let dizionario_offerte = snap.value! as! NSDictionary
                
                
                let idAppUserDestination = dizionario_offerte["IdAppUserDestination"] as? String
                let userFullName = user.fullName
                let userIdApp = user.idApp
                let userSenderIdApp = user.idApp
                let idOrder = dizionario_offerte["orderAutoId"] as? String
                let autoIdOrder = dizionario_offerte["ordersSentAutoId"] as? String
                
                
                if  idAppUserDestination != user.idApp {
                    let msg = "Il tuo amico " + (user.fullName)! + " ti ha appena offerto qualcosa"
                    //push notification and App badge value for Receiver
                    NotificationsCenter.sendOrderNotification(userDestinationIdApp: idAppUserDestination!, msg: msg, controlBadgeFrom: "received", companyId: (self.payment?.company?.companyId)!, userFullName: userFullName!, userIdApp: userIdApp!, userSenderIdApp: userSenderIdApp!,idOrder: idOrder!, autoIdOrder: autoIdOrder!)
                }
                self.updateNumberPendingProducts(idAppUserDestination!, recOrPurch: "received")
                
            })
        }
    }
    
    private func updateNumberPendingProducts(_ idAppUserDestination: String, recOrPurch: String){
        let ref = Database.database().reference()
        ref.child("users/" + idAppUserDestination).observeSingleEvent(of: .value, with: { (snap) in
            guard snap.exists() else {return}
            guard snap.value != nil else {return}
            
            var badgeValueToUpdate = ""
            if recOrPurch == "received" {
                badgeValueToUpdate = "numberOfPendingReceivedProducts"
            } else if recOrPurch == "purchased" {
                badgeValueToUpdate = "numberOfPendingOurchasedProducts"
            }
            let dizionario_users = snap.value! as! NSDictionary
            var badgeValue = 0
            
            for (chiave,valore) in dizionario_users {
                switch chiave as! String {
                    
                case badgeValueToUpdate:
                    badgeValue = (valore as? Int)!
                    break
                default:
                    break
                }
            }
            ref.child("users/"+idAppUserDestination).updateChildValues([badgeValueToUpdate : badgeValue + 1])
        })
    }
    
    private func sendReceiptByEmail(){
        /*
         curl -s --user 'api:key-8c2bae2b713b839f3f766f21c3cd31d4' \
         https://api.mailgun.net/v3/sandbox.morganazone.it/messages \
         -F from='Excited User <postmaster@sandbox.morganazone.it>' \
         -F to='vittorioscocca@hotmail.com' \
         -F subject='Hello' \
         -F text='Testing some Mailgun awesomness!'
         */
        FireBaseAPI.readNodeOnFirebaseWithOutAutoId(node: "users/"+(self.payment?.pendingUserIdApp)!, onCompletion: { (error,dictionary) in
            guard error == nil else {
                print("errore")
                return
            }
            guard dictionary != nil else {
                return
            }
            let emailUser = dictionary?["email"]
            let fullName = dictionary?["fullName"]
            if let url = NSURL(string: "https://api.mailgun.net/v3/sandbox.morganazone.it/messages") {
                
                let request = NSMutableURLRequest(url: url as URL)
                request.httpMethod = "POST"
                let user = "api"
                let psw = "key-8c2bae2b713b839f3f766f21c3cd31d4"
                let userPasswordString = user+":"+psw
                let userPasswordData = userPasswordString.data(using: String.Encoding.utf8)
                let base64EncodedCredential = userPasswordData!.base64EncodedString()
                let authString = "Basic \(base64EncodedCredential)"
                request.addValue(authString, forHTTPHeaderField: "Authorization")
                request.timeoutInterval = 200000.0
                let bodyStr = "from=Ricevuta dell tuo pagamento a Morgana Music Srls <postmaster@sandbox.morganazone.it>&to=Receiver name <\(emailUser!)>&subject=Test&text=Caro \(fullName!) grazie per aver acquistato i nostri prodotti...segue ricevuta"
                
                
                request.httpBody = bodyStr.data(using: String.Encoding.utf8)
                let session = URLSession.shared
                session.dataTask(with: request as URLRequest, completionHandler: { (returnData, response, error) -> Void in
                    let strData = NSString(data: returnData!, encoding: String.Encoding.utf8.rawValue)
                    print("Mailgun response \(strData!)")
                }).resume()
            }
        })
    }
    
    private func saveReceiptOnFireBase(){
        //Numero Progressivo documento es 01-Data
        //Denominazione, Via, Città, Cap,Provincia,P.Iva
        //Data Emissione
        //Descrizione, prezzo
        //Iva
        //Totale
        //Modalità di pagamento es: firebase
    }

}
