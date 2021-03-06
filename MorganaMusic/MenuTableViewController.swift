//
//  MenuTableViewController.swift
//  MorganaMusic
//
//  Created by Vittorio Scocca on 19/10/17.
//  Copyright © 2017 Vittorio Scocca. All rights reserved.
//
import UIKit
import FirebaseAuth
import FBSDKLoginKit

class MenuTableViewController: UITableViewController {
    @IBOutlet var myTable: UITableView!
    
    let menuVoicesStandard = ["Home", "Mappa"]
    let menuCompany = ["Home", "Mappa","Profilo azienda"]
    var actualMenu =  [String]()
    var user: User?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.actualMenu = menuVoicesStandard
        
        self.myTable.contentInset = UIEdgeInsetsMake(-20, 0, 0, 0) //UIEdgeInsets.zero
        if CheckConnection.isConnectedToNetwork() == true {
            self.user = CoreDataController.sharedIstance.findUserForIdApp(Auth.auth().currentUser?.uid)
            if  user == nil {
                //self.loadUserFromFirebase()
                self.logout()
            } else {
                self.readMenu()
            }
        }
    }
    
    private func killFirebaseObserver (){
        let firebaseObserverKilled = UserDefaults.standard
        if !firebaseObserverKilled.bool(forKey: "firebaseObserverKilled") {
            firebaseObserverKilled.set(true, forKey: "firebaseObserverKilled")
            let fireBaseToken = UserDefaults.standard
            let uid = fireBaseToken.object(forKey: "FireBaseToken") as? String
            let user = CoreDataController.sharedIstance.findUserForIdApp(uid)
            if user != nil {
                guard let idApp = user?.idApp else {
                    return
                }
                FireBaseAPI.removeObserver(node: "users/" + idApp)
                FireBaseAPI.removeObserver(node: "ordersSent/" + idApp)
                FireBaseAPI.removeObserver(node: "ordersReceived/" + idApp)
                firebaseObserverKilled.set(true, forKey: "firebaseObserverKilled")
                print("[MenuTableViewController]: Firebase Observer Killed")
            }
        } else {
            print("[MenuTableViewController]: no observer killed")
        }
    }
    
    private func logout(){
        guard CheckConnection.isConnectedToNetwork() == true else {
            return
        }
        print("[MenuTableViewController]: MenuTableViewController")
        //effettuo logout FB
        let loginManager = FBSDKLoginManager()
        loginManager.logOut()
        
        //effettuologout da firebase
        let firebaseAuth = Auth.auth()
        do {
            //kill firebase observer
            self.killFirebaseObserver()
            try firebaseAuth.signOut()
            print("[MenuTableViewController]: utente disconnesso di firebase")
        } catch let signOutError as NSError {
            print ("[MenuTableViewController]: Error signing out: %@", signOutError)
        }
        
        //passo il controllo alla view di login, LoginViewController
        let loginPage = storyboard?.instantiateViewController(withIdentifier: "LoginViewController")
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.window?.rootViewController = loginPage
    }
    
    private func readMenu(){
        guard let idApp = self.user?.idApp else {
            return
        }
        FireBaseAPI.readNodeOnFirebaseWithOutAutoId(node: "users/" + idApp, onCompletion: { (error,dictionary) in
            guard error == nil else {return}
            guard let dic = dictionary else {return}
            
            if dic["companyCode"] as? String == "mr001" {
                self.actualMenu = self.menuCompany
                self.myTable.reloadData()
            }
        })
    }
    
    // MARK: - Table view data source
    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 2
    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        switch section {
        case 0:
            return 1
        case 1:
            return self.actualMenu.count
        default:
            return 2
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 {
            return 185.0
        } else {
            return 45.0
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        //let cell = tableView.dequeueReusableCell(withIdentifier: "menuRow", for: indexPath)
        var cell: UITableViewCell?
        if indexPath.section == 0 {
            cell = tableView.dequeueReusableCell(withIdentifier: "userProfileRow", for: indexPath)
            (cell as! UserProfileMenuRowTableViewCell).fullName_label.text = self.user?.fullName
            
            CacheImage.getImage(url: self.user?.pictureUrl, onCompletion: { (image) in
                guard let img = image else {
                    print("immagine utente non reperibile")
                    return
                }
                DispatchQueue.main.async(execute: {
                    if let cellToUpdate = tableView.cellForRow(at: indexPath) {
                        (cellToUpdate as! UserProfileMenuRowTableViewCell).friendImageView.image = img
                    }
                })
            })
            cell?.backgroundColor = #colorLiteral(red: 0.7411764706, green: 0.1529411765, blue: 0.2078431373, alpha: 1)
            
        } else {
            cell = tableView.dequeueReusableCell(withIdentifier: "menuRow", for: indexPath)
            cell?.textLabel?.text = actualMenu[indexPath.row]
            cell?.textLabel?.textColor = #colorLiteral(red: 0.9396358132, green: 0.1998271942, blue: 0.2721875906, alpha: 1)
        }
        return cell!
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let thisCell = tableView.cellForRow(at: indexPath)
        if  thisCell?.reuseIdentifier == "userProfileRow" {
            self.performSegue(withIdentifier: "segueToUserProfile", sender: nil)
        }else {
            switch (thisCell?.textLabel?.text)! {
            case "Home":
                self.performSegue(withIdentifier: "segueToHome", sender: nil)
                break
            case "Mappa":
                self.performSegue(withIdentifier: "segueToMap", sender: nil)
                break
            case "Profilo azienda":
                self.performSegue(withIdentifier: "segueToCompanyProfile", sender: nil)
                break
            default:
                break
            }
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
