//
//  UserPointsViewController.swift
//  MorganaMusic
//
//  Created by Vittorio Scocca on 08/03/18.
//  Copyright © 2018 Vittorio Scocca. All rights reserved.
//

import UIKit
import FirebaseAuth

class UserPointsViewController: UIViewController {
    @IBOutlet weak var menuButton: UIBarButtonItem!
    @IBOutlet weak var totalPoints_label: UILabel!
    @IBOutlet weak var creditConversion: UIButton!
    @IBOutlet weak var credits_label: UILabel!
    @IBOutlet weak var myActivityIndicator: UIActivityIndicatorView!
    
    var user: User?
    var controller :UIAlertController?
    var points: Int = 0
    var credits: Double = 0
    
    private func commonInit() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(updateUserPoints),
                                               name: .readingRemoteUserPointDidFinish,
                                               object: nil)
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        if revealViewController() != nil {
            menuButton.target = revealViewController()
            menuButton.action = #selector(SWRevealViewController.revealToggle(_:))
            view.addGestureRecognizer(self.revealViewController().panGestureRecognizer())
        }
        
        if CheckConnection.isConnectedToNetwork() == true {
            user = CoreDataController.sharedIstance.findUserForIdApp(Auth.auth().currentUser?.uid)
            guard user != nil else { return }
        } else {
            self.generateAlert()
        }
        creditConversion.layer.masksToBounds = true
        creditConversion.layer.cornerRadius = 10
        commonInit()
        
        points = PointsManager.sharedInstance.totalUsersPoints()
        totalPoints_label.text = self.points.formattedWithSeparator
        
        readUserCreditsFromFirebase()
    }
    
    @objc private func updateUserPoints() {
        self.points = PointsManager.sharedInstance.totalUsersPoints()
        guard let label = totalPoints_label else { return }
        label.text = points.formattedWithSeparator
    }
    
    private func readUserCreditsFromFirebase(){
        guard let userIdApp = user?.idApp else { return }
        FireBaseAPI.readNodeOnFirebaseWithOutAutoId(node: "users/" + userIdApp, onCompletion: { (error,dictionary) in
            guard error == nil else {
                self.generateAlert()
                return
            }
            guard let userDictionary = dictionary else {
                return
            }
            guard let credits = userDictionary["credits"] as? Double else { return }
            
            DispatchQueue.main.async(execute: {
                self.credits_label.text = LocalCurrency.instance.getLocalCurrency(currency: NSNumber(floatLiteral: credits))
                self.credits = credits
            })
        })
    }
    
    func generateAlert(){
        controller = UIAlertController(title: "Attenzione connessione Internet assente",
                                       message: "Accertati che la tua connessione WiFi o cellulare sia attiva",
                                       preferredStyle: .alert)
        let action = UIAlertAction(title: "CHIUDI", style: UIAlertActionStyle.default, handler:
        {(paramAction:UIAlertAction!) in
            
            print("[USERVIEWCONTROLLER]: Il messaggio di chiusura è stato premuto")
        })
        
        controller!.addAction(action)
        self.present(controller!, animated: true, completion: nil)
        
    }
    
    private func generateAlert(title: String, msg: String){
        controller = UIAlertController(title: title,
                                       message: msg,
                                       preferredStyle: .alert)
        let action = UIAlertAction(title: "Chiudi", style: UIAlertActionStyle.default, handler:
        {(paramAction:UIAlertAction!) in
            print("[ORDERVIEWCONTROLLER]: Il messaggio di chiusura è stato premuto")
        })
        controller!.addAction(action)
        self.present(controller!, animated: true, completion: nil)
    }
    
    @IBAction func convertAction(_ sender: UIButton) {
        if points > PointsManager.maxPointsThreshold {
            let creditsToAdd = Double(points / PointsManager.maxPointsThreshold) * PointsManager.conversioneEuroCostant
            credits += creditsToAdd
            credits_label.text = "€ " + LocalCurrency.instance.getLocalCurrency(currency: NSNumber(floatLiteral: credits))
            
            guard let userIdApp = user?.idApp else { return }
            FireBaseAPI.updateNode(node: "users/" + userIdApp, value: ["credits" : credits])
            
            points = points - (points / PointsManager.maxPointsThreshold) *  PointsManager.maxPointsThreshold
            totalPoints_label.text = points.formattedWithSeparator
            FireBaseAPI.updateNode(node: "usersPointsStats/" + userIdApp, value: ["totalCurrentPoints": points])
        }
        else {
            generateAlert(title: "Attenzione", msg: "Devi aver totalizzato almeno 250 punti prima di poterli convertire in crediti.")
        }
    }
    
    @IBAction func updatePoints(_ sender: UIBarButtonItem) {
        guard let userIdApp = user?.idApp else {
            return
        }
        myActivityIndicator.startAnimating()
        readUserCreditsFromFirebase()
        PointsManager.sharedInstance.readUserPoints(userId: userIdApp) { (points) in
            DispatchQueue.main.async(execute: {
                guard let totalePoints = points else {
                    return
                }
                self.points = totalePoints
                self.totalPoints_label.text = self.points.formattedWithSeparator
                self.myActivityIndicator.stopAnimating()
            })
        }
    }
    
    
}

extension Formatter {
    static let withSeparator: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.groupingSeparator = "."
        formatter.numberStyle = .decimal
        return formatter
    }()
}

extension BinaryInteger {
    var formattedWithSeparator: String {
        return Formatter.withSeparator.string(for: self) ?? ""
    }
}
