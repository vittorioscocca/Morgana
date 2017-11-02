//
//  NotificationCentre.swift
//  MorganaMusic
//
//  Created by Vittorio Scocca on 14/07/17.
//  Copyright © 2017 Vittorio Scocca. All rights reserved.
//

import Foundation
import FirebaseDatabase
import FirebaseAuth
import Firebase
import FirebaseMessaging
import FirebaseInstanceID
import UserNotifications
import UserNotificationsUI //framework to customize the notification


//Notification center for FireBase push notification and mailgun e-mail notification

class NotificationsCenter{
    
    private static let authorizationKey = "key=AAAA6dHO-Bo:APA91bEfTnS0TxY1lJPYuv0al7xGH3rjkuhFif09pTQKdW7deNay0z9BRRcHlQpeJNiot6IiOMRX82wiY-EGN0GG6ZkWT69VQmUe1CPokPbeD4PzS6G4iZq2IzpcRs4o7gQMr44Pc6bK"
    
    private static var userDestinationBadgeValue: Int = 0
    private static var fireBaseIstanceIDToken: String = String()
    
    
    class func sendNotification(userDestinationIdApp: String, msg: String, controlBadgeFrom: String) {
        
        FireBaseAPI.readNodeOnFirebaseWithOutAutoId(node: "users/" + userDestinationIdApp, onCompletion: {(error,dictionary) in
            guard error == nil else {
                (print("nessuna connessione"))
                return
            }
            guard dictionary != nil else {
                return
            }
            var valuePendingProduct = ""
            
            if controlBadgeFrom == "received" {
                valuePendingProduct = "numberOfPendingReceivedProducts"
            } else if controlBadgeFrom == "purchased" {
                valuePendingProduct = "numberOfPendingPurchasedProducts"
            }
            userDestinationBadgeValue = dictionary?[valuePendingProduct] as! Int
            userDestinationBadgeValue = userDestinationBadgeValue + 1
            
          
            guard (dictionary?["fireBaseIstanceIDToken"] as? String) != nil else {return}
            fireBaseIstanceIDToken = dictionary?["fireBaseIstanceIDToken"] as! String
            
            if let url = NSURL(string: "https://fcm.googleapis.com/fcm/send"){
                let request = NSMutableURLRequest(url: url as URL)
                request.httpMethod = "POST" //Or GET if that's what you need
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                
                request.setValue(authorizationKey, forHTTPHeaderField: "Authorization")//This is where you add your HTTP headers like Content-Type, Accept and so on
                request.timeoutInterval = 200000.0
                let params = ["to" : fireBaseIstanceIDToken, "data" : ["identifier" : "ExpiratedOrder"], "notification" :["title" : "", "body": msg, "sound" : "default", "badge" : String(userDestinationBadgeValue)], "priority" : "high" ] as [String : Any]
                var httpData :Data = Data()
                do {
                    httpData = try JSONSerialization.data(withJSONObject: params, options: .prettyPrinted)
                    // here "jsonData" is the dictionary encoded in JSON data
                    
                } catch {
                    print(error.localizedDescription)
                }
                
                request.httpBody = httpData
                let session = URLSession.shared
                session.dataTask(with: request as URLRequest, completionHandler: { (returnData, response, error) -> Void in
                    let strData = NSString(data: returnData!, encoding: String.Encoding.utf8.rawValue)
                    print("NOTIFICA INVIATA \(strData!)")
                }).resume() //Remember this one or nothing will happen :-)
            }
            
        })
    }
    
    class func sendOrderAcionNotification(userDestinationIdApp: String, msg: String, controlBadgeFrom: String) {
        
        FireBaseAPI.readNodeOnFirebaseWithOutAutoId(node: "users/" + userDestinationIdApp, onCompletion: {(error,dictionary) in
            guard error == nil else {
                (print("nessuna connessione"))
                return
            }
            guard dictionary != nil else {
                return
            }
            var valuePendingProduct = ""
            
            if controlBadgeFrom == "received" {
                valuePendingProduct = "numberOfPendingReceivedProducts"
            } else if controlBadgeFrom == "purchased" {
                valuePendingProduct = "numberOfPendingPurchasedProducts"
            }
            userDestinationBadgeValue = dictionary?[valuePendingProduct] as! Int
            userDestinationBadgeValue = userDestinationBadgeValue + 1
            
            
            guard (dictionary?["fireBaseIstanceIDToken"] as? String) != nil else {return}
            fireBaseIstanceIDToken = dictionary?["fireBaseIstanceIDToken"] as! String
            
            if let url = NSURL(string: "https://fcm.googleapis.com/fcm/send"){
                let request = NSMutableURLRequest(url: url as URL)
                request.httpMethod = "POST" //Or GET if that's what you need
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                
                request.setValue(authorizationKey, forHTTPHeaderField: "Authorization")//This is where you add your HTTP headers like Content-Type, Accept and so on
                request.timeoutInterval = 200000.0
                let params = ["to" : fireBaseIstanceIDToken, "data" : ["identifier" : "OrderAction"], "notification" :["title" : "", "body": msg, "sound" : "default", "badge" : String(userDestinationBadgeValue)], "priority" : "high" ] as [String : Any]
                var httpData :Data = Data()
                do {
                    httpData = try JSONSerialization.data(withJSONObject: params, options: .prettyPrinted)
                    // here "jsonData" is the dictionary encoded in JSON data
                    
                } catch {
                    print(error.localizedDescription)
                }
                
                request.httpBody = httpData
                let session = URLSession.shared
                session.dataTask(with: request as URLRequest, completionHandler: { (returnData, response, error) -> Void in
                    let strData = NSString(data: returnData!, encoding: String.Encoding.utf8.rawValue)
                    print("NOTIFICA INVIATA \(strData!)")
                }).resume() //Remember this one or nothing will happen :-)
            }
            
        })
    }
    
    class func sendConsuptionNotification(userDestinationIdApp: String, msg: String, controlBadgeFrom: String) {
        
        FireBaseAPI.readNodeOnFirebaseWithOutAutoId(node: "users/" + userDestinationIdApp, onCompletion: {(error,dictionary) in
            guard error == nil else {
                (print("nessuna connessione"))
                return
            }
            guard dictionary != nil else {
                return
            }
            var valuePendingProduct = ""
            
            if controlBadgeFrom == "received" {
                valuePendingProduct = "numberOfPendingReceivedProducts"
            } else if controlBadgeFrom == "purchased" {
                valuePendingProduct = "numberOfPendingPurchasedProducts"
            }
            userDestinationBadgeValue = dictionary?[valuePendingProduct] as! Int
            userDestinationBadgeValue = userDestinationBadgeValue + 1
            
            
            guard (dictionary?["fireBaseIstanceIDToken"] as? String) != nil else {return}
            fireBaseIstanceIDToken = dictionary?["fireBaseIstanceIDToken"] as! String
            
            if let url = NSURL(string: "https://fcm.googleapis.com/fcm/send"){
                let request = NSMutableURLRequest(url: url as URL)
                request.httpMethod = "POST" //Or GET if that's what you need
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                
                request.setValue(authorizationKey, forHTTPHeaderField: "Authorization")//This is where you add your HTTP headers like Content-Type, Accept and so on
                request.timeoutInterval = 200000.0
                let params = ["to" : fireBaseIstanceIDToken, "data" : ["identifier" : "Consuption"], "notification" :["title" : "", "body": msg, "sound" : "default", "badge" : String(userDestinationBadgeValue)], "priority" : "high" ] as [String : Any]
                var httpData :Data = Data()
                do {
                    httpData = try JSONSerialization.data(withJSONObject: params, options: .prettyPrinted)
                    // here "jsonData" is the dictionary encoded in JSON data
                    
                } catch {
                    print(error.localizedDescription)
                }
                
                request.httpBody = httpData
                let session = URLSession.shared
                session.dataTask(with: request as URLRequest, completionHandler: { (returnData, response, error) -> Void in
                    let strData = NSString(data: returnData!, encoding: String.Encoding.utf8.rawValue)
                    print("NOTIFICA INVIATA \(strData!)")
                }).resume() //Remember this one or nothing will happen :-)
            }
            
        })
    }
    
    class func sendOrderNotification(userDestinationIdApp: String, msg: String, controlBadgeFrom: String, companyId: String, userFullName: String, userIdApp: String, userSenderIdApp: String, idOrder: String, autoIdOrder: String) {
        
        FireBaseAPI.readNodeOnFirebaseWithOutAutoId(node: "users/" + userDestinationIdApp, onCompletion: {(error,dictionary) in
            guard error == nil else {
                (print("nessuna connessione"))
                return
            }
            guard dictionary != nil else {
                return
            }
            var valuePendingProduct = ""
            
            if controlBadgeFrom == "received" {
                valuePendingProduct = "numberOfPendingReceivedProducts"
            } else if controlBadgeFrom == "purchased" {
                valuePendingProduct = "numberOfPendingPurchasedProducts"
            }
            userDestinationBadgeValue = dictionary?[valuePendingProduct] as! Int
            userDestinationBadgeValue = userDestinationBadgeValue + 1
            
            
            guard (dictionary?["fireBaseIstanceIDToken"] as? String) != nil else {return}
            fireBaseIstanceIDToken = dictionary?["fireBaseIstanceIDToken"] as! String
            
            if let url = NSURL(string: "https://fcm.googleapis.com/fcm/send"){
                let request = NSMutableURLRequest(url: url as URL)
                request.httpMethod = "POST" //Or GET if that's what you need
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                
                request.setValue(authorizationKey, forHTTPHeaderField: "Authorization")//This is where you add your HTTP headers like Content-Type, Accept and so on
                request.timeoutInterval = 200000.0
                let params = ["to" : fireBaseIstanceIDToken, "data" : ["identifier" : "OrderSent","userFullName": userFullName, "userIdApp": userDestinationIdApp, "userSenderIdApp": userSenderIdApp, "idOrder": idOrder, "autoIdOrder": autoIdOrder, "companyId": companyId], "notification" :["title" : "", "body": msg, "click_action":"OrderSent", "sound" : "default", "badge" : String(userDestinationBadgeValue)], "priority" : "high" ] as [String : Any]
                var httpData :Data = Data()
                do {
                    httpData = try JSONSerialization.data(withJSONObject: params, options: .prettyPrinted)
                    // here "jsonData" is the dictionary encoded in JSON data
                    
                } catch {
                    print(error.localizedDescription)
                }
                
                request.httpBody = httpData
                let session = URLSession.shared
                session.dataTask(with: request as URLRequest, completionHandler: { (returnData, response, error) -> Void in
                    let strData = NSString(data: returnData!, encoding: String.Encoding.utf8.rawValue)
                    print("NOTIFICA INVIATA \(strData!)")
                }).resume() //Remember this one or nothing will happen :-)
            }
            
        })
    }

        
        
    
    
    class func localNotification(title: String, body: String) {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        
        content.title = title
        content.body = body
        content.categoryIdentifier = "alert"
        content.userInfo = ["gcm.message_id": "LocalAlert"]
        content.sound = UNNotificationSound.default()
        //content.subtitle = "Lets code,Talk is cheap"
        //To Present image in notification 
        /*
        if let path = Bundle.main.path(forResource: "monkey", ofType: "png") {
            let url = URL(fileURLWithPath: path)
            do {
                let attachment = try UNNotificationAttachment(identifier: "sampleImage", url: url, options: nil)
                content.attachments = [attachment]
            } catch {
                print("attachment not found.")
            }
        }*/
        
        // Deliver the notification in five seconds.
        let trigger = UNTimeIntervalNotificationTrigger.init(timeInterval: 3.0, repeats: false)
        let request = UNNotificationRequest(identifier: "LocalAlert", content: content, trigger: trigger)
        center.add(request) { (error : Error?) in
            if let theError = error {
                print(theError.localizedDescription)
            }
            
        }
    }
    
    class func scheduledExpiratedOrderLocalNotification(title: String, body: String, identifier: String, expirationDate: Date){
        
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
    
        content.title = title
        content.body = body
        content.categoryIdentifier = "alert"
        content.userInfo = ["gcm.message_id": "expiratedOrder"]
        content.sound = UNNotificationSound.default()
        
        var dateComponents = DateComponents()
        let calendar = Calendar.current
        dateComponents.hour = 8
        dateComponents.minute = 00
        dateComponents.day = calendar.component(.day, from: expirationDate)
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        print("NOTIFICA REMEBER EXPIRATION CREATA alle \(dateComponents.hour!):\(dateComponents.minute!)")
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request) { (error : Error?) in
            if let theError = error {
                print(theError.localizedDescription)
            }
            
        }
    }
    
    class func scheduledBirthdayOrder(title: String, userIdApp: String, credits: Double, body: String, identifier: String, scheduledNotification: Date){
        
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        
        content.title = title
        content.body = body
        content.categoryIdentifier = "birthdayNotification"
        content.userInfo = ["gcm.message_id":"birthdayNotification", "creditsSended": credits, "userIdApp": userIdApp]
        content.sound = UNNotificationSound.default()
        /*
        var dateComponents = DateComponents()
        let calendar = Calendar.current
        dateComponents.day = calendar.component(.day, from: scheduledNotification)
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
       
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
         */
        
        let trigger = UNTimeIntervalNotificationTrigger.init(timeInterval: 3.0, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request) { (error : Error?) in
            if let theError = error {
                print(theError.localizedDescription)
            }
        }
        
        // continuare da qui: dedcommentare il giorno schedulato, in face di accept salvare la nuova data 
    }
    
    class func scheduledRememberExpirationLocalNotification(title: String, body: String, identifier: String){
        
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        
        content.title = title
        content.body = body
        content.categoryIdentifier = "RemeberExpiration"
        content.userInfo = ["gcm.message_id": "RemeberExpiration"]
        content.sound = UNNotificationSound.default()
        
        
        var dateComponents = DateComponents()
        dateComponents.hour = 21
        dateComponents.minute = 42
        
            
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        //let trigger1 = UNTimeIntervalNotificationTrigger.init(timeInterval: 3.0, repeats: false)
         print("NOTIFICA CICLICA CREATA ogni giorno ore \(dateComponents.hour!):\(dateComponents.minute!)")
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request) { (error : Error?) in
            if let theError = error {
                print(theError.localizedDescription)
            }
           
        }
    }
    
    
    
}

