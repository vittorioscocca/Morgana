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

class NotitificationsCenter{
    
    private static let authorizationKey = "key=AAAA6dHO-Bo:APA91bEfTnS0TxY1lJPYuv0al7xGH3rjkuhFif09pTQKdW7deNay0z9BRRcHlQpeJNiot6IiOMRX82wiY-EGN0GG6ZkWT69VQmUe1CPokPbeD4PzS6G4iZq2IzpcRs4o7gQMr44Pc6bK"
    
    private static var userDestinationBadgeValue: Int = 0
    private static var fireBaseIstanceIDToken: String = String()
    
    
    class func sendNotification(userIdApp: String, msg: String, controlBadgeFrom: String) {
        
        FireBaseAPI.readNodeOnFirebaseWithOutAutoId(node: "users/" + userIdApp, onCompletion: {(error,dictionary) in
            guard error == nil else {
                (print("nessuna connessione"))
                return
            }
            guard dictionary != nil else {
                return
            }
            var valuePendingProduct = ""
            
            if controlBadgeFrom == "received" {
                valuePendingProduct = "number of pending received products"
            } else if controlBadgeFrom == "purchased" {
                valuePendingProduct = "number of pending purchased products"
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
                let params = ["to" : fireBaseIstanceIDToken, "data" : ["identifier" : "myDrinks"], "notification" :["title" : "", "body": msg, "identifier" : "myDrinks", "sound" : "default", "badge" : String(userDestinationBadgeValue)], "priority" : "high",] as [String : Any]
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
        content.categoryIdentifier = "alarm"
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
        
        // schedulare una notifica
        /*
         var dateComponents = DateComponents()
         dateComponents.hour = 19
         dateComponents.minute = 30
         let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)*/
        
        // Deliver the notification in five seconds.
        let trigger = UNTimeIntervalNotificationTrigger.init(timeInterval: 3.0, repeats: false)
        
        let request = UNNotificationRequest(identifier: "LocalAlert", content: content, trigger: trigger)
        
        center.add(request)
        
    }
}

