//
//  MenuTableViewController.swift
//  MorganaMusic
//
//  Created by Vittorio Scocca on 19/10/17.
//  Copyright © 2017 Vittorio Scocca. All rights reserved.
//

import UIKit

class MenuTableViewController: UITableViewController {

    @IBOutlet var myTable: UITableView!
    
    
    let menuVoicesStandard = ["Home", "Mappa"]
    let menuCompany = ["Home", "Mappa","Profilo azienda"]
    var actualMenu =  [String]()
    var user: User?
    var fireBaseToken = UserDefaults.standard
    var uid: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.actualMenu = menuVoicesStandard
        
        self.myTable.contentInset = UIEdgeInsetsMake(-20, 0, 0, 0) //UIEdgeInsets.zero
        if CheckConnection.isConnectedToNetwork() == true {
            self.uid = fireBaseToken.object(forKey: "FireBaseToken") as? String
            self.user = CoreDataController.sharedIstance.findUserForIdApp(uid)
            
            guard user != nil else{
                print("user ancora non esiste")
                return
            }
            self.readMenu()
        }
        
        
    }
    
    private func readMenu(){
        FireBaseAPI.readNodeOnFirebaseWithOutAutoId(node: "users/" + (user?.idApp)!, onCompletion: { (error,dictionary) in
            guard error == nil else {return}
            guard dictionary != nil else {return}
            
            if dictionary?["companyCode"] as! String != "0" {
                self.actualMenu = self.menuCompany
                self.myTable.reloadData()
            }
        })
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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
                guard image != nil else {
                    print("immagine utente non reperibile")
                    return
                }
                DispatchQueue.main.async(execute: {
                    if let cellToUpdate = tableView.cellForRow(at: indexPath) {
                        (cellToUpdate as! UserProfileMenuRowTableViewCell).friendImageView.image = image
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
