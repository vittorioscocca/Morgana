//
//  OrderSentDetailsViewController.swift
//  MorganaMusic
//
//  Created by Vittorio Scocca on 18/08/17.
//  Copyright © 2017 Vittorio Scocca. All rights reserved.
//

import UIKit

class OrderSentDetailsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource{
    
    @IBOutlet weak var myTable: UITableView!
    
    var sectionTitle = ["Destinatario", "Riepilogo"]
    var offertaInviata: Order?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.myTable.dataSource = self
        self.myTable.delegate = self
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return self.sectionTitle[section]
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 1
        }else {
            return (offertaInviata?.prodottiTotali)!
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if (sectionTitle[indexPath.section] == sectionTitle[0]) {
            return 78.0
        } else {
            return 42.0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: UITableViewCell?
        
        
        if (sectionTitle[indexPath.section] == sectionTitle[0]) {
            cell = tableView.dequeueReusableCell(withIdentifier: "cellUserDetaildTable", for: indexPath)
            
            //let url = NSURL(string: (offertaInviata?.userDestination?.pictureUrl)!)
            //let data = NSData(contentsOf: url! as URL)
            //(cell as! CartUserTableViewCell).friendImageView.image = UIImage(data: data! as Data)
            (cell as! CartUserTableViewCell).nome_label.text = offertaInviata?.userDestination?.fullName
            (cell as! CartUserTableViewCell).costoOfferta_label.text = "Totale € " + String(format:"%.2f", (offertaInviata?.costoTotale)!)
            
            CacheImage.getImage(url: offertaInviata?.userDestination?.pictureUrl, onCompletion: { (image) in
                guard image != nil else {
                    print("immagine utente non reperibile")
                    return
                }
                DispatchQueue.main.async(execute: {
                    if let cellToUpdate = tableView.cellForRow(at: indexPath) {
                        (cellToUpdate as! CartUserTableViewCell).friendImageView.image = image
                    }
                })
            })
            
        } else {
            cell = tableView.dequeueReusableCell(withIdentifier: "defaultCell", for: indexPath)
            
            if  indexPath.row <= (offertaInviata?.prodotti?.count)! - 1  {
                let product = offertaInviata?.prodotti?[indexPath.row]
                
                cell?.textLabel?.text = "(\((product?.quantity)!))  " + (product?.productName)! + " € " + String(format:"%.2f", (product?.price!)!)
                cell?.textLabel?.textColor = #colorLiteral(red: 0.7419371009, green: 0.1511851847, blue: 0.20955199, alpha: 1)
            }
        }
        return cell!
    }


}
