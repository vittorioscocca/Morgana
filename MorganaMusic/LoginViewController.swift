//
//  LoginViewController.swift
//  MorganaMusic
//
//  Created by Vittorio Scocca on 04/04/17.
//  Copyright © 2017 Vittorio Scocca. All rights reserved.
//

import UIKit
import FBSDKLoginKit
import FirebaseDatabase
import FirebaseAuth
import FirebaseMessaging
import FirebaseInstanceID

public extension NSNotification.Name {
    static let FbTokenDidChangeNotification = NSNotification.Name("LoginFbTokenDidChangeNotification")
    static let FirebaseTokenDidChangeNotification = NSNotification.Name("LoginFirebaseTokenDidChangeNotification")
}

//Facebook and Firebase Login Controller
class LoginViewController: UIViewController, FBSDKLoginButtonDelegate {
    
    @IBOutlet weak var customFBButtom: FBSDKLoginButton!
    
    //FB and Firebase access Token
    var fbToken: String?
    var firebaseUserId: String?
    
    var controller :UIAlertController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let _ = Auth.auth().currentUser else {
            //Facebook Login
            customFBButtom.delegate = self
            customFBButtom.readPermissions = ["public_profile", "email", "user_friends"]
            FBSDKProfile.enableUpdates(onAccessTokenChange: true)
            
            NotificationCenter.default.addObserver(self,
                                                   selector:  #selector(fBAccessTokenDidChange(notification:)),
                                                   name:.FBSDKAccessTokenDidChange,
                                                   object: nil)
            
            NotificationCenter.default.addObserver(self,
                                                   selector:  #selector(messaginRegistrationTokenRefreshed),
                                                   name:.MessagingRegistrationTokenRefreshed,
                                                   object: nil)
            
            return
        }
        
        let userPage = storyboard?.instantiateViewController(withIdentifier: "SWRevealController")
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.window!.rootViewController = userPage
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //update Facebook access token
    @objc func fBAccessTokenDidChange(notification: NSNotification) {
        guard let oldToken = notification.userInfo?["FBSDKAccessTokenChangeOldKey"] as? FBSDKAccessToken else { return }
        guard let newToken = notification.userInfo?["FBSDKAccessTokenChangeNewKey"] as? FBSDKAccessToken else { return }
        
        if oldToken.tokenString != newToken.tokenString {
            guard let currentUserId = Auth.auth().currentUser?.uid else { return }
            CoreDataController.sharedIstance.updateFBAccessToken(idApp: currentUserId, fbAccessToken: newToken.tokenString)
            NotificationCenter.default.post(name: .FbTokenDidChangeNotification, object: self)
        }
    }
    
    @objc func messaginRegistrationTokenRefreshed() {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
        print("[AppDelegate]: firebase fcm modificato, impossibile aggiornare valore su firebase, user id inesistente")
        return
        }
    
        FireBaseAPI.updateNode(node: "users/" + currentUserId, value: ["fireBaseIstanceIDToken" : Messaging.messaging().fcmToken ?? ""])
    }
    
    func fetchProfile(){
        print("fetch profile")
        let parameters = ["fields" : "email, name, first_name, last_name, age_range,id, gender, picture.type(large)"]
        
        FBSDKGraphRequest(graphPath: "me", parameters: parameters).start(completionHandler: { (connection, result, error) -> Void in
            if (error != nil){
                // Process error
                print("[LoginViewController]: Error: \(error!)")
            }else {
                let result = result as? NSDictionary
                let email = result?["email"] as? String
                let fullName = result?["name"] as? String
                let user_name = result?["first_name"] as? String
                let user_lastName = result?["last_name"] as? String
                let user_gender = result?["gender"] as? String
                guard let user_id_fb = result?["id"]  as? String else { return }
                let picture = result?["picture"] as? NSDictionary
                let data = picture?["data"] as? NSDictionary
                let url = data?["url"] as? String
                
                guard let userId = self.firebaseUserId else {
                    return
                }
                
                guard let newUser = CoreDataController.sharedIstance.addNewUser(idApp: userId, idFB: user_id_fb, email: email, fullName: fullName, firstName: user_name, lastName: user_lastName, gender: user_gender, pictureUrl: url, fbAccessToken: self.fbToken!) else {
                    return
                }
                NotificationCenter.default.post(name: .FbTokenDidChangeNotification, object: self)
                self.addUserInCloud(user: newUser, onCompletion: {
                    self.createUserPointsStats()
                })
            }
        })
    }
    
    //update user info on Firebase
    private func addUserInCloud(user: User, onCompletion: @escaping ()->()){
        guard let userFireBase = Auth.auth().currentUser else { return }
        let ref = Database.database().reference()
        
        ref.child("users/" + userFireBase.uid).observeSingleEvent(of: .value, with: { (snap) in
            //if user exist on firbase exit, else save user data on firebase(only one time)
            guard !snap.exists() else {
                print("[LoginViewController]: exist: user already exist on Firebase")
                //Firebase Token can changed, so if there is such problem with a login/logout we have the new Token
                let dataUser = [
                    "name" : user.firstName ?? "",
                    "surname" : user.lastName ?? "",
                    "fullName" : user.fullName ?? "",
                    "idFB" : user.idFB ?? "",
                    "email" : user.email ?? "",
                    "gender" : user.gender ?? "",
                    "pictureUrl" : user.pictureUrl ?? "",
                    "fireBaseIstanceIDToken" : Messaging.messaging().fcmToken ?? ""
                    ] as [String : Any]
                ref.child("users/" + userFireBase.uid).updateChildValues(dataUser)
                onCompletion()
                return
            }
            //create user data on Firebase
            let dataUser = [
                "name" : user.firstName ?? "",
                "surname" : user.lastName ?? "",
                "fullName" : user.fullName ?? "",
                "idFB" : user.idFB ?? "",
                "email" : user.email ?? "",
                "gender" : user.gender ?? "",
                "pictureUrl" : user.pictureUrl ?? "",
                "numberOfPendingPurchasedProducts": 0,
                "numberOfPendingReceivedProducts" : 0,
                "accountState" : "Active",
                "companyCode":"0",
                "fireBaseIstanceIDToken" : Messaging.messaging().fcmToken ?? "",
                "credits": 5,
                "birthday": "",
                "cityOfRecidence":""
                ] as [String : Any]
            ref.child("users/").child(userFireBase.uid).setValue(dataUser)
            onCompletion()
            
        })
    }
    
    private func createUserPointsStats(){
        guard let userFireBase = Auth.auth().currentUser else { return }
        let ref = Database.database().reference()
        
        
        ref.child("usersPointsStats/" + userFireBase.uid).observeSingleEvent(of: .value, with: { (snap) in
            guard !snap.exists() else {
                print("[LoginViewController]: exist: userPoints already exist on Firebase")
                return
            }
            //create user data on Firebase
            let dataUserPointsStats = [
                "personalDiscount": 0,
                "totalCurrentPoints": 0,
                "totalExtraDiscountShopping": 0,
                "totalFreeMoney": 0,
                "totalStandardShopping": 0,
                "weeklyShopping": 0,
                "totalShopping": 0,
                "totalPresence": 0,
                "totalStandardConsumptions": 0,
                "totalDiversifiedConsumptions": 0,
                "totalPoints": 0,
                "currentFreeMoney": 0,
                "lastDateShopping": 0
                ] as [String : Any]
            
            FireBaseAPI.saveNodeOnFirebaseWithoutAutoId(node: "usersPointsStats", child: userFireBase.uid, dictionaryToSave: dataUserPointsStats, onCompletion: { (error) in
                guard error == nil else {
                    print(error!)
                    return
                }
                ref.child("usersPointsStats/" + userFireBase.uid + "/" + "lastDateShopping").setValue(ServerValue.timestamp())
                print("[LoginViewController]: userPointsSats salvate su Firebase")
            })
            
        })
    }
    
    func generateAlert(){
        controller = UIAlertController(title: "Attenzione connessione Internet assente",
                                       message: "Accertati che la tua connessione WiFi o cellulare sia attiva",
                                       preferredStyle: .alert)
        let action = UIAlertAction(title: "CHIUDI", style: UIAlertActionStyle.default, handler:
        {(paramAction:UIAlertAction!) in
            
        })
        controller!.addAction(action)
        self.present(controller!, animated: true, completion: nil)
        
    }
    
    func loginButton(_ loginButton: FBSDKLoginButton!, didCompleteWith result: FBSDKLoginManagerLoginResult!, error: Error!) {
        
        if (error == nil) {
            guard CheckConnection.isConnectedToNetwork() == true else{
                self.generateAlert()
                return
            }
            if FBSDKAccessToken.current()?.tokenString != nil {
                //log to FireBase
                let credential = FacebookAuthProvider.credential(withAccessToken: FBSDKAccessToken.current().tokenString)
                
                Auth.auth().signIn(with: credential) { (user, error) in
                    if error != nil {
                        print(error!)
                    }else {
                        print("[LoginViewController]: User logged on Facebook")
                        
                        while Auth.auth().currentUser == nil {
                            print("[LoginViewController]...waiting Firebase user id")
                        }
                        print("[LoginViewController]: Success! Firebase User id is ready")
                        guard let fireBaseUser = Auth.auth().currentUser else { return }
                        
                        self.firebaseUserId = fireBaseUser.uid
                        NotificationCenter.default.post(name: .FirebaseTokenDidChangeNotification, object: self)
                        
                        if (result.token) != nil {
                            print("[LoginViewController]: User logged on Facebook")
                            
                            //save token on UserDefaults
                            self.fbToken = FBSDKAccessToken.current()?.tokenString
                            self.fetchProfile()
                            DispatchQueue.main.async(execute: { () -> Void in
                                //slider first access
                                let userPage = self.storyboard?.instantiateViewController(withIdentifier: "SliderViewController")
                                let appDelegate = UIApplication.shared.delegate as! AppDelegate
                                appDelegate.window!.rootViewController = userPage
                            })
                        }
                    }
                }
            }
        } else{
            print(error.localizedDescription)
            return
        }
    }
    
    func loginButtonWillLogin(_ loginButton: FBSDKLoginButton!) -> Bool {
        return true
    }
    
    func loginButtonDidLogOut(_ loginButton: FBSDKLoginButton!) {
        print("User disconnected")
    }
    
}
