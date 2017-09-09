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
import FirebaseInstanceID

//Facebook and Firebase Login Controller
class LoginViewController: UIViewController, FBSDKLoginButtonDelegate {
    
    @IBOutlet weak var customFBButtom: FBSDKLoginButton!
    
    //FB and Firebase access Token
    var fbToken = UserDefaults.standard
    var fireBaseToken = UserDefaults.standard
    
    var controller :UIAlertController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let uidFiB = fireBaseToken.object(forKey: "FireBaseToken") as? String
        
        if  uidFiB != nil {
            // User is signed in.
            //after FB access control pass to HomeViewController
            let userPage = storyboard?.instantiateViewController(withIdentifier: "HomeViewController")
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            appDelegate.window!.rootViewController = userPage
            
        } else {
            // No user is signed in.
            
            //Facebook Login
            customFBButtom.delegate = self
            customFBButtom.readPermissions = ["public_profile", "email", "user_friends"]
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func fetchProfile(){
        print("fetch profile")
        let parameters = ["fields" : "email, name, first_name, last_name, id, gender, picture.type(large)"]
        
        FBSDKGraphRequest(graphPath: "me", parameters: parameters).start(completionHandler: { (connection, result, error) -> Void in
            
            if ((error) != nil)
            {
                // Process error
                print("Error: \(error!)")
            }
            else
            {
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
    
                let user = self.fireBaseToken.object(forKey: "FireBaseToken") as? String
                let newUser = CoreDataController.sharedIstance.addNewUser(user!, user_id_fb!, email, fullName, user_name, user_lastName, user_gender, url)
                self.addUserInCloud(user: newUser, onCompletion: {
                    self.createUserPointsStats()
                })
            }
        })
    }
    
    //update user info on Firebase
    private func addUserInCloud(user: User, onCompletion: @escaping ()->()){
        let userFireBase = FIRAuth.auth()?.currentUser
        let ref = FIRDatabase.database().reference()
        
        
        ref.child("users/"+(userFireBase?.uid)!).observeSingleEvent(of: .value, with: { (snap) in
            //if user exist on firbase exit, else save user data on firebase(only one time)
            guard !snap.exists() else {
                print("exist: user already exist on Firebase")
                //Firebase Token can changed, so if there is such problem with a login/logout we have the new Token
                ref.child("user/"+(userFireBase?.uid)!).updateChildValues(["fireBaseIstanceIDToken" : FIRInstanceID.instanceID().token()!])
                onCompletion()
                return
            }
            //create user data on Firebase
            let dataUser = [
                "nome" : user.firstName!,
                "cognome" : user.lastName!,
                "nome completo" : user.fullName!,
                "id FB" : user.idFB!,
                "email" : user.email!,
                "sesso" : user.gender!,
                "picture url" : user.pictureUrl!,
                "number of pending purchased products": 0,
                "number of pending received products" : 0,
                "account state" : "Active",
                "merchantCode":"0",
                "fireBaseIstanceIDToken" : FIRInstanceID.instanceID().token()!,
                "credits": 5
                ] as [String : Any]
            ref.child("users").child((userFireBase?.uid)!).setValue(dataUser)
            onCompletion()
            
        })
    }
    
    private func createUserPointsStats(){
        let userFireBase = FIRAuth.auth()?.currentUser
        let ref = FIRDatabase.database().reference()
        
        ref.child("usersPointsStats/"+(userFireBase?.uid)!).observeSingleEvent(of: .value, with: { (snap) in
            guard !snap.exists() else {
                print("exist: userPoints already exist on Firebase")
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
            
            FireBaseAPI.saveNodeOnFirebaseWithoutAutoId(node: "usersPointsStats", child: (userFireBase?.uid)!, dictionaryToSave: dataUserPointsStats, onCompletion: { (error) in
                guard error == nil else {
                    print(error!)
                    return
                }
                ref.child("usersPointsStats/"+(userFireBase?.uid)!+"/"+"lastDateShopping").setValue(FIRServerValue.timestamp())
                print("userPointsSats salvate su Firebase")
            })
            
        })
    }
    
    func generateAlert(){
        controller = UIAlertController(title: "Attenzione connessione Internet assente",
                                       message: "Accertati che la tua connessione WiFi o cellulare sia attiva",
                                       preferredStyle: .alert)
        let action = UIAlertAction(title: "CHIUDI", style: UIAlertActionStyle.default, handler:
        {(paramAction:UIAlertAction!) in
            
            print("Il messaggio di chiusura è stato premuto")
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
                let credential = FIRFacebookAuthProvider.credential(withAccessToken: FBSDKAccessToken.current().tokenString)
                
                FIRAuth.auth()?.signIn(with: credential) { (user, error) in
                    if error != nil {
                        print(error!)
                    }else {
                        print("User logged on FireBase")
                        
                        while FIRAuth.auth()?.currentUser == nil {
                            print("...waiting Firebase user id")
                        }
                        print("Success! User id is ready")
                        
                        let fireBaseUser = FIRAuth.auth()?.currentUser
                        self.fireBaseToken.set((fireBaseUser?.uid)!, forKey: "FireBaseToken")
                        
                        if (result.token) != nil {
                            print("User logged on Facebook")
                            //save token on UserDefaults
                            self.fbToken.set(FBSDKAccessToken.current().tokenString!, forKey: "FBToken")
                            
                            self.fetchProfile()
                            
                            //slider first access
                            let userPage = self.storyboard?.instantiateViewController(withIdentifier: "SliderViewController")
                            let appDelegate = UIApplication.shared.delegate as! AppDelegate
                            appDelegate.window!.rootViewController = userPage
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
