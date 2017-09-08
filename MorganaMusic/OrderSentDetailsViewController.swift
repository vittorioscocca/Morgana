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
    

    //le sezioni della tabella
    var sectionTitle = ["Destinatario", "Riepilogo"]
    var offertaInviata: Order?
    var imageCache = [String:UIImage]()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.myTable.dataSource = self
        self.myTable.delegate = self
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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
            
            
            if let pictureUrl = offertaInviata?.userDestination?.pictureUrl {
                if let img = imageCache[pictureUrl] {
                    (cell as! OrderSentTableViewCell).friendImageView.image = img
                }else {
                    // The image isn't cached, download the img data
                    // We should perform this in a background thread
                    
                    //let request: NSURLRequest = NSURLRequest(url: url! as URL)
                    //let mainQueue = OperationQueue.main
                    
                    let request = NSMutableURLRequest(url: NSURL(string: (offertaInviata?.userDestination?.pictureUrl)!)! as URL)
                    let session = URLSession.shared
                    
                    //NSURLConnection.sendAsynchronousRequest(request as URLRequest, queue: mainQueue, completionHandler: { (response, data, error) -> Void in
                    let task = session.dataTask(with: request as URLRequest, completionHandler: {data, response, error -> Void in
                        if error == nil {
                            // Convert the downloaded data in to a UIImage object
                            let image = UIImage(data: data!)
                            // Store the image in to our cache
                            self.imageCache[(self.offertaInviata?.userDestination?.pictureUrl)!] = image
                            // Update the cell
                            DispatchQueue.main.async(execute: {
                                if let cellToUpdate = tableView.cellForRow(at: indexPath) {
                                    (cellToUpdate as! CartUserTableViewCell).friendImageView.image = image
                                }
                            })
                        }
                        else {
                            print("Error: \(error!.localizedDescription)")
                        }
                    })
                    task.resume()
                }
                
            }
            
        } else {
            cell = tableView.dequeueReusableCell(withIdentifier: "defaultCell", for: indexPath)
            
            if  indexPath.row <= (offertaInviata?.prodotti?.count)! - 1  {
                let product = offertaInviata?.prodotti?[indexPath.row]
                
                cell?.textLabel?.text = "(\((product?.quantity)!))  " + (product?.productName)! + " € " + String(format:"%.2f", (product?.price!)!)
            }
            
            
        }
        
        return cell!
    }


}
