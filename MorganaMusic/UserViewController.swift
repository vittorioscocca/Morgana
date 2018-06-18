//
//  UserViewController.swift
//  MorganaMusic
//
//  Created by Vittorio Scocca on 04/04/17.
//  Copyright © 2017 Vittorio Scocca. All rights reserved.
//
import FBSDKCoreKit
import FBSDKLoginKit
import FBSDKShareKit
import UIKit
import FirebaseDatabase
import FirebaseAuth

class UserViewController: UIViewController, FBSDKAppInviteDialogDelegate {
    
    
    @IBOutlet weak var userImage_image: UIImageView!
    @IBOutlet weak var userFullName: UILabel!
    @IBOutlet weak var userEmail_text: UILabel!
    
    @IBOutlet var userCredits_label: UILabel!
    @IBOutlet var menuButton: UIBarButtonItem!
    
    var uid: String?
    var user: User?
    var fbTokenString: String?
    var fireBaseToken = UserDefaults.standard
    let fbToken = UserDefaults.standard
    let idUserApp = UserDefaults.standard
    let defaults = UserDefaults.standard
    var qrcodeImage: CIImage!
    var activityIndicator: UIActivityIndicatorView = UIActivityIndicatorView()
    var strLabel = UILabel()
    let effectView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    var companyCode: String?
    
    //alert
    var controller :UIAlertController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.navigationBar.setBackgroundImage(UIImage(), for: UIBarMetrics.default)
        navigationController?.navigationBar.shadowImage = UIImage()
        
        if revealViewController() != nil {
            menuButton.target = revealViewController()
            menuButton.action = #selector(SWRevealViewController.revealToggle(_:))
            view.addGestureRecognizer(self.revealViewController().panGestureRecognizer())
        }
        if CheckConnection.isConnectedToNetwork() == true {
            
            self.uid = fireBaseToken.object(forKey: "FireBaseToken") as? String
            self.user = CoreDataController.sharedIstance.findUserForIdApp(uid)
            guard user != nil else { return }
            self.userFullName.text = self.user?.fullName
            self.userEmail_text.text = self.user?.email
        } else {self.generateAlert()}
        
        self.readImage()
        self.setCustomImage()
        readUserCreditsFromFirebase()
    }
    
    private func readUserCreditsFromFirebase(){
        FireBaseAPI.readNodeOnFirebaseWithOutAutoId(node: "users/" + (user?.idApp)!, onCompletion: { (error,dictionary) in
            guard error == nil else {
                self.generateAlert()
                return
            }
            guard dictionary != nil else {
                return
            }
            DispatchQueue.main.async(execute: {
                self.userCredits_label.text = "€ " + String(format:"%.2f", dictionary?["credits"] as! Double)
                if dictionary?["companyCode"] as! String != "0" {
                    self.companyCode = dictionary?["companyCode"] as? String
                    
                }
            })
        })
    }
    
    private func readImage(){
        CacheImage.getImage(url: self.user?.pictureUrl, onCompletion: { (image) in
            guard image != nil else {
                print("Attenzione URL immagine Mittente non presente")
                return
            }
            DispatchQueue.main.async(execute: {
                self.userImage_image.image = image
            })
        })
    }
    
    private func setCustomImage(){
        self.userImage_image.layer.borderWidth = 2.5
        self.userImage_image.layer.borderColor = #colorLiteral(red: 0.7419371009, green: 0.1511851847, blue: 0.20955199, alpha: 1)
        self.userImage_image.layer.masksToBounds = false
        self.userImage_image.layer.cornerRadius = userImage_image.frame.height/2
        self.userImage_image.clipsToBounds = true
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let identifier = segue.identifier else {
            return
        }
        switch identifier {
        case "segueToFriendsList":
            (segue.destination as! FriendsListViewController).segueFrom = "userView"
            break
        case "segueToUserQrCode":
            (segue.destination as! UserQrCodeViewController).user = self.user
            break
        case "segueToCityAndBirthday":
            (segue.destination as! UserCityAndBirthdayViewController).user = self.user
            break
        default:
            break
        }
    }
    
    @IBAction func fbFriend_clicked(_ sender: UIButton) {
        guard CheckConnection.isConnectedToNetwork() == true else {
            self.generateAlert()
            return
        }
        self.performSegue(withIdentifier: "segueToFriendsList", sender: nil)
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
    
    private func killFirebaseObserver (){
        let firebaseObserverKilled = UserDefaults.standard
        if !firebaseObserverKilled.bool(forKey: "firebaseObserverKilled") {
            firebaseObserverKilled.set(true, forKey: "firebaseObserverKilled")
            let fireBaseToken = UserDefaults.standard
            let uid = fireBaseToken.object(forKey: "FireBaseToken") as? String
            let user = CoreDataController.sharedIstance.findUserForIdApp(uid)
            if user != nil {
                FireBaseAPI.removeObserver(node: "users/" + (user?.idApp)!)
                FireBaseAPI.removeObserver(node: "ordersSent/" + (user?.idApp)!)
                FireBaseAPI.removeObserver(node: "ordersReceived/" + (user?.idApp)!)
                firebaseObserverKilled.set(true, forKey: "firebaseObserverKilled")
                print("Firebase Observer Killed")
            }
            
        } else {print("no observer killed")}
        
    }
    
    private func logout(){
        guard CheckConnection.isConnectedToNetwork() == true else {
            self.generateAlert()
            return
        }
        //effettuo logout FB
        let loginManager = FBSDKLoginManager()
        loginManager.logOut()
        //self.fbToken.set(nil, forKey: "FBToken")
        self.fbToken.set(nil, forKey: "FBToken")
        
        //effettuologout da firebase
        let firebaseAuth = Auth.auth()
        do {
            //kill firebase observer
            self.killFirebaseObserver()
            try firebaseAuth.signOut()
            self.fireBaseToken.removeObject(forKey: "FireBaseToken")
            
            print("utente disconnesso di firebase")
        } catch let signOutError as NSError {
            print ("Error signing out: %@", signOutError)
        }
        
        //passo il controllo alla view di login, LoginViewController
        let loginPage = storyboard?.instantiateViewController(withIdentifier: "LoginViewController")
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.window!.rootViewController = loginPage
    }
    
    private func activeActionSheet (){
        self.controller = UIAlertController(title: "", message: "Confermi di volere uscire?", preferredStyle: .actionSheet)
        
        let action = UIAlertAction(title: "Esci", style: .destructive,handler: {(paramAction:UIAlertAction!) in
            self.logout()
        })
        
        let actionDestructive = UIAlertAction(title: "Annulla", style: .default,handler: {(paramAction:UIAlertAction!) in
            return
        })
        
        self.controller!.addAction(action)
        self.controller!.addAction(actionDestructive)
        self.present(controller!, animated: true, completion: nil)
    }
    
    @IBAction func logoutFBButton(_ sender: UIButton) {
        self.activeActionSheet()
    }
    
    @IBAction func unwindToProfile(_ sender: UIStoryboardSegue) {
        print("Unwind Segue il profilo")
        
        // controllo che l'identifier non sia nil
        // se lo è entra dentro l'else ed esce dalla funzione
        // in alternativa puoi scrivere un codice per la gestione
        // di unwind senza identifier
        guard sender.identifier != nil else {
            return
        }
        //self.navigationController?.popViewController(animated: true)
        
    }
    
    @IBAction func inviteButtonTapped(_ sender: UIButton) {
        print("Invite button tapped")
        
        let inviteDialog:FBSDKAppInviteDialog = FBSDKAppInviteDialog()
        if(inviteDialog.canShow()){
            
            //si deve creare un deep link all'app tramite facebook https://developers.facebook.com/quickstarts/1372786676101271/?platform=app-links-host
            
            let appLinkUrl:NSURL = NSURL(string: "https://fb.me/1438133796233225")!
            let previewImageUrl:NSURL = NSURL(string: "https://www.facebook.com/photo.php?fbid=10212867899477309&l=69699bed07")!
            
            let inviteContent:FBSDKAppInviteContent = FBSDKAppInviteContent()
            inviteContent.appLinkURL = appLinkUrl as URL
            inviteContent.appInvitePreviewImageURL = previewImageUrl as URL
            
            inviteDialog.content = inviteContent
            inviteDialog.delegate = self
            inviteDialog.show()
        }
    }
    
    @IBAction func segueToUserQrCode_clicked(_ sender: UIButton) {
        self.performSegue(withIdentifier: "segueToUserQrCode", sender: nil)
        
    }
    
    @IBAction func segueToUserCityAndBirthday(_ sender: UIButton) {
        self.performSegue(withIdentifier: "segueToCityAndBirthday", sender: nil)
    }
    
    //supplementary Facebook invite funtions
    func appInviteDialog(_ appInviteDialog: FBSDKAppInviteDialog!, didFailWithError error: Error) {
        print("Error tool place in appInviteDialog \(error)")
    }
    
    func appInviteDialog(_ appInviteDialog: FBSDKAppInviteDialog!, didCompleteWithResults results: [AnyHashable : Any]!) {
        if results == nil {
            print("User Canceled invitation dialog with Done Button")
        }else {
            let resultObject = NSDictionary(dictionary: results)
            if let didCancel = resultObject.value(forKey: "completionGesture"){
                if (didCancel as AnyObject).caseInsensitiveCompare("Cancel") == ComparisonResult.orderedSame
                {
                    print("User Canceled invitation dialog")
                }
            }
        }
    }
}
