//
//  AppDelegate.swift
//  MorganaMusic
//
//  Created by Vittorio Scocca on 04/04/17.
//  Copyright © 2017 Vittorio Scocca. All rights reserved.
//

import FBSDKCoreKit
import UIKit
import CoreData
import FBSDKLoginKit
import Firebase
import FirebaseMessaging
import UserNotifications



@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    //for Firebase push notification
    let gcmMessageIDKey = "gcm.message_id"
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        //Paypal sandbox credentials
        PayPalMobile.initializeWithClientIds(forEnvironments: [PayPalEnvironmentProduction: "ARowfMHmd5EwE2lUU2Gc3DkAwyQEFUi1H2qzmwhIiplZ9T2r0eqAAzh_qoE8O57fH6yEz6P9Kl6uRHU2",PayPalEnvironmentSandbox: "AfN_l2vZFwYniDa6bpCW3NmqrD4wX0VV7vH3VdDUb0Fjxsw2__X9gC0fee2VNKus-mRuvN4oHCjPJyBl"])

        //var token for Firebase and Facebook
        let fbToken = UserDefaults.standard
        let fireBaseToken = UserDefaults.standard
        let uidFiB = fireBaseToken.object(forKey: "FireBaseToken") as? String
        let uidFB = fbToken.object(forKey: "FBToken") as? String
        
        //Firebase configuration
        FirebaseApp.configure()
        
        //Firebase push notification
        if #available(iOS 10.0, *) {
            let authOptions : UNAuthorizationOptions = [.alert, .badge, .sound]
            UNUserNotificationCenter.current().requestAuthorization(
                options: authOptions,
                completionHandler: {_,_ in })
            
            setCategories()
            
            // For iOS 10 display notification (sent via APNS)
            UNUserNotificationCenter.current().delegate = self
            // For iOS 10 data message (sent via FCM)
            Messaging.messaging().delegate = self
            
        }
        
        application.registerForRemoteNotifications()
        guard (( uidFB == nil) && (uidFiB == nil)) else{
            print("[DEBUG] Salto il login iniziale")
            MorganaMusicActivate()
            return true
        }
        //FBSDKLoginButton.classForCoder()
        
        FBSDKApplicationDelegate.sharedInstance().application(application, didFinishLaunchingWithOptions: launchOptions)
        
        return true
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        
        let badgeCount = 0
        
        UIApplication.shared.applicationIconBadgeNumber = badgeCount + 1
        
        // If you are receiving a notification message while your app is in the background,
        // this callback will not be fired till the user taps on the notification launching the application.
        if let messageID = userInfo[gcmMessageIDKey] {
            print("Message ID: \(messageID)")
        }
        // Print full message.
        print(userInfo)
        completionHandler(UIBackgroundFetchResult.newData)
    }
    
    // [END receive_message]
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Unable to register for remote notifications: \(error.localizedDescription)")
    }
    
   
    // If swizzling is disabled then this function must be implemented so that the APNs token can be paired to
    // the FCM registration token.
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("APNs token retrieved: \(deviceToken)")
        

        Messaging.messaging().apnsToken = deviceToken
        /*
        InstanceID.instanceID().setAPNSToken(deviceToken, type: InstanceIDAPNSTokenType.sandbox)
        InstanceID.instanceID().setAPNSToken(deviceToken, type: InstanceIDAPNSTokenType.prod)*/
        
        /*
        let tokenChars = UnsafePointer<CChar>(deviceToken.bytes)
        var tokenString = ""
        for i in 0..<deviceToken.count {
            tokenString += String(format: "%02.2hhx", arguments: [tokenChars[i]])
        }
        FIRInstanceID.instanceID().setAPNSToken(deviceToken, type: FIRInstanceIDAPNSTokenType.unknown)
        print("Device token: \(tokenString)")*/
        
        // With swizzling disabled you must set the APNs token here.
        // Messaging.messaging().apnsToken = deviceToken
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }
    
    private func killFirebaseObserver (){
        let firebaseObserverKilled = UserDefaults.standard
        if !firebaseObserverKilled.bool(forKey: "firebaseObserverKilled") {
            firebaseObserverKilled.set(true, forKey: "firebaseObserverKilled")
            let fireBaseToken = UserDefaults.standard
            let uid = fireBaseToken.object(forKey: "FireBaseToken") as? String
            let user = CoreDataController.sharedIstance.findUserForIdApp(uid)
            
            FireBaseAPI.removeObserver(node: "users/" + (user?.idApp)!)
            FireBaseAPI.removeObserver(node: "ordersSent/" + (user?.idApp)!)
            FireBaseAPI.removeObserver(node: "ordersReceived/" + (user?.idApp)!)
            firebaseObserverKilled.set(true, forKey: "firebaseObserverKilled")
            print("Firebase Observer Killed")
        } else {print("no observer killed")}
        
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        killFirebaseObserver()
        
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
        //activeFirebaseObserver()
        
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        FBSDKAppEvents.activateApp()
        MorganaMusicActivate()
        
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        // Saves changes in the application's managed object context before the application terminates.
        
        self.saveContext()
        killFirebaseObserver()
        
        
    }
    
    func application(_ application: UIApplication, open url: URL, sourceApplication: String?, annotation: Any) -> Bool {
        
        return FBSDKApplicationDelegate.sharedInstance().application(application, open: url, sourceApplication: sourceApplication, annotation: annotation)
        
    }

    // MARK: - Core Data stack

    lazy var persistentContainer: NSPersistentContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
        */
        let container = NSPersistentContainer(name: "MorganaMusic")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                 
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()

    // MARK: - Core Data Saving support

    func saveContext () {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }

}

//Push notification settings

@available(iOS 10, *)
extension AppDelegate : UNUserNotificationCenterDelegate {
    
    // Receive displayed notifications for iOS 10 devices.
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        
        // Print full message.
        print("%@", userInfo)
        print("Message ID: \(userInfo["gcm.message_id"]!)")
        
        
        if notification.request.identifier == "LocalAlert"{
            completionHandler( [.alert,.sound,.badge])
        }
        
        if userInfo["gcm.message_id"] as! String == "RemeberExpiration"{
            print(notification.request.identifier)
            completionHandler( [.alert,.sound,.badge])
        }
        
        if userInfo["gcm.message_id"] as! String == "OrderSent"{
            print(notification.request.identifier)
            completionHandler( [.alert,.sound,.badge])
        }
        
        if userInfo["gcm.message_id"] as! String == "expiratedOrder"{
            print(notification.request.identifier)
            completionHandler( [.alert,.sound,.badge])
        }
        
        
    }
    
    func setCategories(){
        
        let deleteExpirationAction = UNNotificationAction(identifier: "delete.action",title: "Non ricordarlmelo più",options: [])
        let acceptOrderAction = UNNotificationAction(identifier: "acceptOrder.action",title: "Accetta",options: [])
        let refuseOrderAction = UNNotificationAction(identifier: "refuseOrder.action",title: "Rifiuta",options: [])
        let remeberExpirationCategory = UNNotificationCategory(identifier: "RemeberExpiration",actions: [deleteExpirationAction],intentIdentifiers: [],options: [])
        let OrderSentCategory = UNNotificationCategory(identifier: "OrderSent",actions: [acceptOrderAction,refuseOrderAction],intentIdentifiers: [],options: [])
        UNUserNotificationCenter.current().setNotificationCategories([remeberExpirationCategory,OrderSentCategory])
    }
  
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        
        let userInfo = response.notification.request.content.userInfo
        // Print message ID.
        if let messageID = userInfo[gcmMessageIDKey] {
            print("Message ID: \(messageID)")
        }
        
        // Print full message.
        print(userInfo)
        
        let action = response.actionIdentifier
        
        switch action {
        case "delete.action":
            print(response.notification.request.identifier)
            center.removePendingNotificationRequests(withIdentifiers: [response.notification.request.identifier] )
            print("Notification id \(response.notification.request.identifier) killed")
            break
        case "acceptOrder.action":
            let fireBaseToken = UserDefaults.standard
            let uid = fireBaseToken.object(forKey: "FireBaseToken") as? String
            let user = CoreDataController.sharedIstance.findUserForIdApp(uid)
            let userFullName = user?.fullName
            let userIdApp = userInfo["userIdApp"] as? String
            let userSenderIdApp = userInfo["userSenderIdApp"] as? String
            let idOrder = userInfo["idOrder"] as? String
            let autoIdOrder = userInfo["autoIdOrder"] as? String
            let companyId = userInfo["companyId"] as? String
                
            FirebaseData.sharedIstance.acceptOrder(state: "Offerta accettata", userFullName: userFullName!, userIdApp: userIdApp!, comapanyId: companyId!, userSenderIdApp: userSenderIdApp!, idOrder: idOrder!, autoIdOrder: autoIdOrder!)
            print("Ordine ACCETTATO")
            break
        case "refuseOrder.action" :
            let fireBaseToken = UserDefaults.standard
            let uid = fireBaseToken.object(forKey: "FireBaseToken") as? String
            let user = CoreDataController.sharedIstance.findUserForIdApp(uid)
            let userFullName = user?.fullName
            let userIdApp = userInfo["userIdApp"] as? String
            let userSenderIdApp = userInfo["userSenderIdApp"] as? String
            let idOrder = userInfo["idOrder"] as? String
            let autoIdOrder = userInfo["autoIdOrder"] as? String
            let companyId = userInfo["companyId"] as? String
            
            FirebaseData.sharedIstance.refuseOrder(state: "Offerta rifiutata", userFullName: userFullName!, userIdApp: userIdApp!, comapanyId: companyId!, userSenderIdApp: userSenderIdApp!, idOrder: idOrder!, autoIdOrder: autoIdOrder!)
            print("Ordine Rifiutato")
            break
        default:
            break
        }
        
        
        if let id = userInfo["identifier"] as? String  {
            if id == "OrderSent" {
                
                //when tap on notification user go to view notification target
                let storyboard = UIStoryboard(name: "Main", bundle: nil)
                /*
                 let tabBarViewChild = storyboard.instantiateViewController(withIdentifier: "OfferViewController")
                 UpdateBadgeInfo.sharedIstance.updateBadgeInformations(nsArray: tabBarViewChild.tabBarController?.tabBar.items as NSArray!)*/
                
                let rootVC = storyboard.instantiateViewController(withIdentifier: "HomeViewController") as! UITabBarController
                rootVC.selectedIndex = 2 // Index of the tab bar item you want to present, as shown in question it seems is item 2
                self.window!.rootViewController = rootVC
            }
        }
        completionHandler()
    }
}

extension AppDelegate : MessagingDelegate {
    func messaging(_ messaging: Messaging, didRefreshRegistrationToken fcmToken: String) {
        print(fcmToken)
    }
    
    
    // Receive data message on iOS 10 devices.
    func application(received remoteMessage: MessagingRemoteMessage) {
    
    }
}
