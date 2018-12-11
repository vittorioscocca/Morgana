//
//  CartOrderDetailsViewController.swift
//  MorganaMusic
//
//  Created by Vittorio Scocca on 18/10/17.
//  Copyright © 2017 Vittorio Scocca. All rights reserved.
//

import UIKit

class CartOrderDetailsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var myTable: UITableView!
    
    var sectionsTableTitles = ["Destinatario","Riepilogo"]
    
    var orderSent: Order?
    
    
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
        return self.sectionsTableTitles[section]
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 1
        }else {
            guard let products = orderSent?.prodottiTotali else { return 1}
            return products
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if (sectionsTableTitles[indexPath.section] == sectionsTableTitles[0]) {
            return 78.0
        } else {
            return 42.0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: UITableViewCell?
        
        if (sectionsTableTitles[indexPath.section] == sectionsTableTitles[0]) {
            cell = tableView.dequeueReusableCell(withIdentifier: "destinationCartOrderCell", for: indexPath)
            
            
            (cell as! CartUserTableViewCell).nome_label.text = orderSent?.userDestination?.fullName
            CacheImage.getImage(url: orderSent?.userDestination?.pictureUrl, onCompletion: { (image) in
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
            cell = tableView.dequeueReusableCell(withIdentifier: "cartOrderDetailsCell", for: indexPath)
            guard let productsCount = orderSent?.products?.count,
            let products = orderSent?.products else { return cell!}
            if  indexPath.row <= productsCount - 2  {
                let product = products[indexPath.row]
                guard let quantity = product.quantity,
                    let productName = product.productName,
                    let price  = product.price else { return cell! }
                cell?.textLabel?.text = "(\(quantity))  " + productName + " \( LocalCurrency.instance.getLocalCurrency(currency: NSNumber(floatLiteral: (price)))) " 
                cell?.textLabel?.textColor = #colorLiteral(red: 0.7419371009, green: 0.1511851847, blue: 0.20955199, alpha: 1)
            }
        }
        cell?.isUserInteractionEnabled = false
        return cell!
    }
}
