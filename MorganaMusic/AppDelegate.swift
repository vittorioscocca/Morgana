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


public extension NSNotification.Name {
    static let didOpenApplicationFromLetOrderShortCutNotification = NSNotification.Name("AppDelegateDidOpenApplicationFromLetOrderShortCutNotification")
    static let didOpenApplicationFromUserPointsShortCutNotification = NSNotification.Name("AppDelegateDidOpenApplicationFromUserPointsShortShortCutNotification")
    static let didOpenApplicationFromMyOrderShortCutNotification = NSNotification.Name("AppDelegateDidOpenApplicationFromMyOrderShortCutNotification")
    static let didOpenApplicationFromEventsShortCutNotification = NSNotification.Name("AppDelegateDidOpenApplicationFromEventsShortCutNotification")
}


@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var lastViewControllerOnQuick = UserDefaults.standard
    
    enum ShortcutIdentifier: String {
        case letOrder
        case myOrder
        
        init?(fullType: String) {
            guard let last = fullType.components(separatedBy: ".").last else { return nil }
            self.init(rawValue: last)
        }
        
        var type: String {
            return Bundle.main.bundleIdentifier! + ".\(self.rawValue)"
        }
    }
    
    static let applicationShortcutUserInfoIconKey = "applicationShortcutUserInfoIconKey"
    
    var window: UIWindow?
    var launchedShortcutItem: UIApplicationShortcutItem?
    
    //for Firebase push notification
    let gcmMessageIDKey = "gcm.message_id"
    
    @objc private func initializeDynamicShortcuts() {
        var shortcutItems :[UIApplicationShortcutItem] = []
        
        // Construct dynamic short #1
        let shortcut1UserInfo = [AppDelegate.applicationShortcutUserInfoIconKey: UIApplicationShortcutIconType.invitation.rawValue]
        let shortcut1 = UIMutableApplicationShortcutItem(type: ShortcutIdentifier.letOrder.type,
                                                         localizedTitle:"Offi ad un amico",
                                                         localizedSubtitle: "",
                                                         icon: UIApplicationShortcutIcon(type: .invitation),
                                                         userInfo: shortcut1UserInfo)
        shortcutItems.append(shortcut1)
        
        // Construct dynamic short #2
        let shortcut2UserInfo = [AppDelegate.applicationShortcutUserInfoIconKey: UIApplicationShortcutIconType.favorite.rawValue]
        let shortcut2 = UIMutableApplicationShortcutItem(type: ShortcutIdentifier.myOrder.type,
                                                         localizedTitle:"I miei ordini",
                                                         localizedSubtitle: "",
                                                         icon: UIApplicationShortcutIcon(type: .favorite),
                                                         userInfo: shortcut2UserInfo)
        
        shortcutItems.append(shortcut2)
        
        
        UIApplication.shared.shortcutItems = shortcutItems
        
    }
    
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
        //Singleton initialization
        _ = FirebaseData.sharedIstance
        _ = NetworkStatus.default
        _ = FacebookFriendsListManager.instance
        _ = LoadRemoteProducts.instance
        _ = OrdersListManager.instance
        
        
        //Firebase push notification
        if #available(iOS 10.0, *) {
            let authOptions : UNAuthorizationOptions = [.alert, .badge, .sound]
            UNUserNotificationCenter.current().requestAuthorization(
                options: authOptions,
                completionHandler: {(granted, error) in
                    if (granted) {
                        DispatchQueue.main.async(execute: {
                            //UIApplication.shared.registerForRemoteNotifications()
                            //application.registerForRemoteNotifications()
                        })
                    } else{
                        print("Notification permissions not granted")
                    }
            })
            
            setCategories()
            
            // For iOS 10 display notification (sent via APNS)
            UNUserNotificationCenter.current().delegate = self
            
            // For iOS 10 data message (sent via FCM)
            Messaging.messaging().delegate = self
        }
        
        application.registerForRemoteNotifications()
        
        guard (( uidFB == nil) && (uidFiB == nil) && lastViewControllerOnQuick.object(forKey: "lastViewControllerOnQuick") == nil) else{
            print("[DEBUG] Salto il login iniziale")
            MorganaMusicActivate()
            updateFacebookAndFirebaseInfo()
            return true
        }
        
        //FBSDKLoginButton.classForCoder()
        FBSDKApplicationDelegate.sharedInstance().application(application, didFinishLaunchingWithOptions: launchOptions)
        
        initializeDynamicShortcuts()
        
        if let shortcutItem = launchOptions?[UIApplicationLaunchOptionsKey.shortcutItem] as? UIApplicationShortcutItem {
            if !handleShortCutItem(shortcutItem){
                return false
            }
        }

        return true
    }
    
    func MorganaMusicActivate(){
        //let vc = storybard.instantiateViewController(withIdentifier: "HomeViewController") //HomeViewController
        
        if let lastController = lastViewControllerOnQuick.object(forKey: "lastViewControllerOnQuick") as? Int {
            switch lastController {
            case 0:
                NotificationCenter.default.post(name: .didOpenApplicationFromLetOrderShortCutNotification, object: nil)
            case 1:
                NotificationCenter.default.post(name: .didOpenApplicationFromUserPointsShortCutNotification, object: nil)
            case 2:
                NotificationCenter.default.post(name: .didOpenApplicationFromMyOrderShortCutNotification, object: nil)
            case 3:
                NotificationCenter.default.post(name: .didOpenApplicationFromEventsShortCutNotification, object: nil)
            default:
                break
            }
        } else {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let vc = storyboard.instantiateViewController(withIdentifier: "SWRevealController") //HomeViewController
            self.window?.rootViewController = vc
        }
    }
    
    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        let handledShortCutItem = handleShortCutItem(shortcutItem)
        completionHandler(handledShortCutItem)
    }
    
    func handleShortCutItem(_ shortcutItem: UIApplicationShortcutItem) -> Bool {
        guard ShortcutIdentifier(fullType: shortcutItem.type) != nil else { return false }
        guard let shortCutType = shortcutItem.type as String? else { return false }
        lastViewControllerOnQuick.set(nil, forKey: "lastViewControllerOnQuick")
        
        switch shortCutType {
        case ShortcutIdentifier.letOrder.type:
            NotificationCenter.default.post(name: .didOpenApplicationFromLetOrderShortCutNotification, object: nil)
            return true
        case ShortcutIdentifier.myOrder.type:
            NotificationCenter.default.post(name: .didOpenApplicationFromMyOrderShortCutNotification, object: nil)
            return true
        default:
            return false
        }
    }
    
    func updateFacebookAndFirebaseInfo(){
        let parameters = ["fields" : "email, name, first_name, last_name, age_range,id, gender, picture.type(large)"]
        
        let fbToken = UserDefaults.standard
        let fbTokenString = fbToken.object(forKey: "FBToken") as? String
        
        FBSDKGraphRequest(graphPath: "me", parameters: parameters, tokenString: fbTokenString, version: nil, httpMethod: "GET").start(completionHandler: {(connection,result, error) -> Void in
            if ((error) != nil){
                // Process error
                print("Error: \(error!)")
            } else{
                let result = result as? NSDictionary
                let email = result?["email"] as? String
                let fullName = result?["name"] as? String
                let user_name = result?["first_name"] as? String
                let user_lastName = result?["last_name"] as? String
                let user_gender = result?["gender"] as? String
                let user_id_fb = result?["id"]  as? String
                let picture = result?["picture"] as? NSDictionary
                let data = picture?["data"] as? NSDictionary
                let url = data?["url"] as? String
                let fireBaseToken = UserDefaults.standard
                let user = fireBaseToken.object(forKey: "FireBaseToken") as? String
                let newUser = CoreDataController.sharedIstance.addNewUser(user!, user_id_fb!, email, fullName, user_name, user_lastName, user_gender, url)
                self.updateUserInCloud(user: newUser)
            }
        })
    }
    
    //update user info on Firebase
    private func updateUserInCloud(user: User){
        let userFireBase = Auth.auth().currentUser
        let ref = Database.database().reference()
    
        ref.child("users/"+(userFireBase?.uid)!).observeSingleEvent(of: .value, with: { (snap) in
            //if user exist on firbase exit, else save user data on firebase(only one time)
            if snap.exists() {
                //create user data on Firebase
                let dataUser = [
                    "name" : user.firstName!,
                    "surname" : user.lastName!,
                    "fullName" : user.fullName!,
                    "idFB" : user.idFB!,
                    "email" : user.email!,
                    "gender" : user.gender!,
                    "pictureUrl" : user.pictureUrl!,
                    "fireBaseIstanceIDToken" : Messaging.messaging().fcmToken!, //InstanceID.instanceID().token()!,
                    ] as [String : Any]
                //Firebase Token can changed, so if there is such problem with a login/logout we have the new Token
                ref.child("users/"+(userFireBase?.uid)!).updateChildValues(dataUser)
            }
        })
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
        lastViewControllerOnQuick.set(nil, forKey: "lastViewControllerOnQuick")
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
        
        print("Will Present")
        // Print full message.
        print("%@", userInfo)
        print("Message ID: \(userInfo["gcm.message_id"]!)")
        
        //Local Notification
        if notification.request.identifier == "LocalAlert"{
            completionHandler( [.alert,.sound,.badge])
        }
        //Local Notification
        if notification.request.identifier == "alert"{
            completionHandler( [.alert,.sound,.badge])
        }
        //Local Notification
        if userInfo["gcm.message_id"] as! String == "expiratedOrder"{
            print(notification.request.identifier)
            completionHandler( [.alert,.sound,.badge])
        }
        
        //Local Notification
        if userInfo["gcm.message_id"] as! String == "expiratedOrder"{
            print(notification.request.identifier)
            completionHandler( [.alert,.sound,.badge])
        }
        
        //Local Notification
        if userInfo["gcm.message_id"] as! String == "birthdayNotification"{
            print(notification.request.identifier)
            completionHandler( [.alert,.sound,.badge])
        }
        
        
        //Firebase Remote Push Notification
        if userInfo["identifier"] as? String == "Consuption"{
            completionHandler( [.alert,.sound,.badge])
        }
        
        //Firebase Remote Push Notification
        if userInfo["identifier"] as? String == "ExpiratedOrder"{
            print(notification.request.identifier)
            completionHandler( [.alert,.sound,.badge])
        }
        
        //Firebase Remote Push Notification
        if userInfo["identifier"] as? String == "OrderSent"{
            print(notification.request.identifier)
            completionHandler( [.alert,.sound,.badge])
        }
        
        //Firebase Remote Push Notification
        if userInfo["identifier"] as? String == "OrderAction"{
            print(notification.request.identifier)
            completionHandler( [.alert,.sound,.badge])
        }
        
        //This works for iphone 7 and above using haptic feedback
        let feedbackGenerator = UINotificationFeedbackGenerator()
        feedbackGenerator.notificationOccurred(.success)
    }
    
    func setCategories(){
        
        let deleteExpirationAction = UNNotificationAction(identifier: "delete.action",title: "Non ricordarlmelo più",options: [])
        let acceptOrderAction = UNNotificationAction(identifier: "acceptOrder.action",title: "Accetta",options: [.foreground])
        let refuseOrderAction = UNNotificationAction(identifier: "refuseOrder.action",title: "Rifiuta",options: [])
        let acceptCredits = UNNotificationAction(identifier: "acceptCredits.action",title: "Accetta i crediti",options: [])
        
        let remeberExpirationCategory = UNNotificationCategory(identifier: "RemeberExpiration",actions: [deleteExpirationAction],intentIdentifiers: [],options: [])
        let OrderSentCategory = UNNotificationCategory(identifier: "OrderSent",actions: [acceptOrderAction,refuseOrderAction],intentIdentifiers: [],options: [])
        let birthdayNotificationCategory = UNNotificationCategory(identifier: "birthdayNotification",actions: [acceptCredits],intentIdentifiers: [],options: [])
        UNUserNotificationCenter.current().setNotificationCategories([remeberExpirationCategory,OrderSentCategory,birthdayNotificationCategory])
    }
  
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        print("Did Receive")
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
        case "acceptCredits.action":
            let credits = userInfo["creditsSended"] as? Double
            let userIdApp = userInfo["userIdApp"] as? String
            let scheduledNotification = userInfo["scheduledNotification"] as? Date
            let notificationIdentifier = userInfo["notificationIdentifier"] as? String
            
            ManageCredits.updateCredits(newCredit: String(credits!), userId: userIdApp! , onCompletion: {_ in
                print("Crediti aggiornati")
            })
            
            FirebaseData.sharedIstance.changeSchedulationBirthday(scheduledBirthdayNotification: scheduledNotification!, idApp: userIdApp!, notificationIdentifier: notificationIdentifier!)
            
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let rootVC = storyboard.instantiateViewController(withIdentifier: "HomeViewController") as! UITabBarController
            self.window!.rootViewController = rootVC
            NotificationCenter.default.post(name: .didOpenApplicationFromUserPointsShortCutNotification, object: nil)
        default:
            break
        }
        
        if let id = userInfo["identifier"] as? String  {
            if id == "OrderSent" || id == "Consuption" {
                
                //when tap on notification user go to view notification target
                let storyboard = UIStoryboard(name: "Main", bundle: nil)
                let rootVC = storyboard.instantiateViewController(withIdentifier: "HomeViewController") as! UITabBarController
                self.window!.rootViewController = rootVC
                NotificationCenter.default.post(name: .didOpenApplicationFromMyOrderShortCutNotification, object: nil)
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
