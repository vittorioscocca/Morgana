//
//  CompanyProfileViewController.swift
//  MorganaMusic
//
//  Created by Vittorio Scocca on 22/10/17.
//  Copyright © 2017 Vittorio Scocca. All rights reserved.
//

import UIKit

class CompanyProfileViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var myTable: UITableView!
    @IBOutlet var menuButton: UIBarButtonItem!
    
    var companyServices = ["Offri a Clienti", "Parametri di fidelizzazione","Gestisci Menù","Gestisci Promozioni", "Dati fatturazione"]
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.myTable.dataSource = self
        self.myTable.delegate = self
        self.myTable.contentInset = UIEdgeInsets.zero
        if revealViewController() != nil {
            menuButton.target = revealViewController()
            menuButton.action = #selector(SWRevealViewController.revealToggle(_:))
            view.addGestureRecognizer(self.revealViewController().panGestureRecognizer())
        }
        
    navigationController?.navigationBar.setBackgroundImage(UIImage(), for: UIBarMetrics.default)
    navigationController?.navigationBar.shadowImage = UIImage()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return self.companyServices.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "companyProfileCell", for: indexPath)
        cell.textLabel?.text = companyServices[indexPath.row]
        cell.textLabel?.textColor = #colorLiteral(red: 0.7419371009, green: 0.1511851847, blue: 0.20955199, alpha: 1)
        cell.accessoryType = UITableViewCellAccessoryType.disclosureIndicator
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
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
            case "Parametri di fidelizzazione":
                self.performSegue(withIdentifier: "segueToStatistiParameters", sender: nil)
                break
            default:
                break
            }
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    
    @IBAction func qrReader(_ sender: UIBarButtonItem) {
        self.performSegue(withIdentifier: "segueToQROrderReader", sender: nil)
    }
    
}
