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
        
        if #available(iOS 11.0, *) {
            navigationItem.largeTitleDisplayMode = .never
        } else {
            // Fallback on earlier versions
        }
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
            guard let totalProducts = offertaInviata?.prodottiTotali else { return 0 }
            return totalProducts
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
            (cell as! CartUserTableViewCell).costoOfferta_label.text = "Totale " + LocalCurrency.instance.getLocalCurrency(currency: NSNumber(floatLiteral: (offertaInviata?.costoTotale)!))
            
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
            
            guard let products = offertaInviata?.products else { return cell! }
            
            if  indexPath.row <= products.count - 1  {
                let product = products[indexPath.row]
                guard let quantity = product.quantity,
                    let productName = product.productName,
                    let price = product.price
                else { return cell!}
                
                cell?.textLabel?.text = "(\(quantity))  " + productName + " \(LocalCurrency.instance.getLocalCurrency(currency: NSNumber(floatLiteral: price))) "
                cell?.textLabel?.textColor = #colorLiteral(red: 0.7419371009, green: 0.1511851847, blue: 0.20955199, alpha: 1)
            }
        }
        cell?.isUserInteractionEnabled = false
        return cell!
    }


}
