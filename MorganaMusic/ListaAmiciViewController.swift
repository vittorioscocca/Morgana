//
//  ListaAmiciViewController.swift
//  MorganaMusic
//
//  Created by Vittorio Scocca on 03/05/17.
//  Copyright © 2017 Vittorio Scocca. All rights reserved.
//

import UIKit

//User Facebook Friends List that use the app
class ListaAmiciViewController: UIViewController,UITableViewDelegate, UITableViewDataSource, UISearchResultsUpdating {

    @IBOutlet weak var myTable: UITableView!
    @IBOutlet weak var numAmici: UIBarButtonItem!
   
    var segueFrom: String?
    
    var resultSearchController: UISearchController?
    var imageCache = [String:UIImage]()
    let fireBaseToken = UserDefaults.standard
    var userId: String?
    
    //pagination settings
    enum PageSetting: Int {
        case cento = 1
        case mille = 100
        case duemila = 200
        case cinquemila = 300
    }
    
    var friendsList: [Friend]?
    var friendsListPaginated: [Friend]? = []
    var listaFiltrata = [Friend]()
    var start = 0
    var end = 0
    var page:Int?, friendsForPage:Int?, lastPageFriends:Int?
    var currentPage = 0
    var numberOfFriends = 0
    var order: Order?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.myTable.dataSource = self
        self.myTable.delegate = self
        
        self.userId = fireBaseToken.object(forKey: "FireBaseToken")! as? String
        self.friendsList = CoreDataController.sharedIstance.loadAllFriendsOfUser(idAppUser: self.userId!)
        
        self.loadList()
        
        self.resultSearchController = ({
            // creo un oggetto di tipo UISearchController
            let controller = UISearchController(searchResultsController: nil)
            // remove the  background tableView to show finded elements
            controller.dimsBackgroundDuringPresentation = false
            controller.searchResultsUpdater = self
            controller.searchBar.sizeToFit()
            
            // set searchBar to Table Header View
            self.myTable.tableHeaderView = controller.searchBar

            return controller
        })()
        
        self.myTable.addSubview(refreshControl1)
        self.numAmici.title = String(self.friendsListPaginated!.count)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func contentsFilter(text: String) {
        print("sto filtrando i contenuti")
        listaFiltrata.removeAll(keepingCapacity: true)
        for x in self.friendsList! {
            if x.fullName?.localizedLowercase.range(of: text.localizedLowercase) != nil {
                print("aggiungo \(x.fullName!) alla listaFiltrata")
                listaFiltrata.append(x)
            }
            self.myTable.reloadData()
        }
    }
    
    func updateSearchResults(for: UISearchController){
        print("Sto per iniziare una ricerca di \((resultSearchController?.searchBar.text!)!)")
        self.contentsFilter(text: (resultSearchController?.searchBar.text!)!)
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        guard self.resultSearchController != nil else {
            return 0
        }
        if self.resultSearchController!.isActive {
            return self.listaFiltrata.count
        } else {
            return self.friendsListPaginated!.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let friend: Friend?
        // if searchBar is active, listafiltrata is source data
        if self.resultSearchController!.isActive {
            friend = listaFiltrata[indexPath.row]
        } else {
            // search bar is no active,friendsListPaginated is data source
            friend = self.friendsListPaginated?[indexPath.row]
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "friendsCell", for: indexPath)
        
        (cell as! FirendsListTableViewCell).friendName.text = friend?.fullName
        (cell as! FirendsListTableViewCell).friendImageView.image = UIImage(named: "userDefault")
        (cell as! FirendsListTableViewCell).idFB = friend?.idFB
        (cell as! FirendsListTableViewCell).friendImageUrl = friend?.pictureUrl
        if self.segueFrom == "myDrinks" {
            (cell as! FirendsListTableViewCell).forwardButton.isHidden = false
            (cell as! FirendsListTableViewCell).forwardButton.tag = indexPath.row
            //(cell as! FirendsListTableViewCell).forwardButton.addTarget(self, action: "forwardAction:", for: .touchUpInside)
            (cell as! FirendsListTableViewCell).forwardButton.addTarget(self, action: #selector(forwardAction(_:)), for: .touchUpInside)
        } 
        
        // If this image is already cached, don't re-download
        
        if let pictureUrl = friend?.pictureUrl{
            if let img = imageCache[pictureUrl] {
                (cell as! FirendsListTableViewCell).friendImageView.image = img
            }
            else {
                // The image isn't cached, download the img data
                // We should perform this in a background thread
                
                //let request: NSURLRequest = NSURLRequest(url: url! as URL)
                //let mainQueue = OperationQueue.main
                let request = NSMutableURLRequest(url: NSURL(string: (friend?.pictureUrl)!)! as URL)
                let session = URLSession.shared
                
                let task = session.dataTask(with: request as URLRequest, completionHandler: {data, response, error -> Void in
                    if error == nil {
                        // Convert the downloaded data in to a UIImage object
                        let image = UIImage(data: data!)
                        // Store the image in to our cache
                        self.imageCache[(friend?.pictureUrl)!] = image
                        // Update the cell
                        DispatchQueue.main.async(execute: {
                            if let cellToUpdate = tableView.cellForRow(at: indexPath) {
                                (cellToUpdate as! FirendsListTableViewCell).friendImageView.image = image
                            }
                        })
                    }
                    else {
                        print("Error: \(error!.localizedDescription)")
                    }
                })
                task.resume()
            }
        }else {
            print("Attenzione URL immagine User non presente")
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let thisCell = tableView.cellForRow(at: indexPath)
        if self.segueFrom == "offerView" {
            performSegue(withIdentifier: "unwindToOfferfromListFriend", sender: thisCell)
        }
        
    }
    
    
    @objc func forwardAction(_ sender: UIButton!) {
        performSegue(withIdentifier: "unwindFromFriendsListToMyDrinks", sender: sender)
    }
    
    private func loadList(){
        (page,friendsForPage,lastPageFriends) = calculatePagination()
        if self.currentPage == page {
            self.numberOfFriends = lastPageFriends!
        } else if self.currentPage < page! {
            self.numberOfFriends = friendsForPage!
        } else {return}
        self.currentPage += 1
        self.end += numberOfFriends
        self.start = end - numberOfFriends
        for i in start ..< end {
            //order is != nil when forwar action i called. This code clean from friendsList that friends that has refused the order
            if self.order != nil {
                if (friendsList?[i])?.idFB != order?.userDestination?.idFB {
                    self.friendsListPaginated?.append((friendsList?[i])!)
                }
            }else {
                self.friendsListPaginated?.append((friendsList?[i])!)
            }
        }
    }
    
    private func calculatePagination()->(page:Int?,friendsForPage:Int?,lastPageFriends:Int?){
        
        if let count = self.friendsList?.count  {
            
            switch count {
            case 0...100:
                return (PageSetting.cento.rawValue,count,0)
            case 101...1000:
                let pageI = count/PageSetting.mille.rawValue
                return (pageI, PageSetting.mille.rawValue,count-(PageSetting.mille.rawValue*pageI))
            case 1001...2000:
                let pageI = count/PageSetting.duemila.rawValue
                return (pageI, PageSetting.duemila.rawValue,count-(PageSetting.duemila.rawValue*pageI))
            case 2001...5000:
                let pageI = count/PageSetting.cinquemila.rawValue
                return (pageI,PageSetting.cinquemila.rawValue,count-(PageSetting.cinquemila.rawValue*pageI))
            default:
                break
            }
        }
        return (0,0,0)
    }
    
    lazy var refreshControl1: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(ListaAmiciViewController.handleRefresh(_:)), for: UIControlEvents.valueChanged)
        return refreshControl
    }()
    
    
    @objc func handleRefresh(_ refreshControl: UIRefreshControl) {
        
        self.loadList()
        self.myTable.reloadData()
        refreshControl.endRefreshing()
        self.numAmici.title = String(self.friendsListPaginated!.count)
    }
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let identifier = segue.identifier else {
            return
        }
        
        switch identifier {
        case "unwindToOfferfromListFriend":
            guard let isSenderEmpty = sender else {
                return
            }
            let userDestination = UserDestination(nil,nil,nil,nil,nil)
            userDestination.fullName = (isSenderEmpty as! FirendsListTableViewCell).friendName.text
            userDestination.pictureUrl = (isSenderEmpty as! FirendsListTableViewCell).friendImageUrl
            userDestination.idFB = (isSenderEmpty as! FirendsListTableViewCell).idFB
            Order.sharedIstance.userDestination = userDestination
            break
        case "unwindFromFriendsListToMyDrinks":
            guard let isSenderEmpty = sender else {
                return
            }
            let friend = self.friendsListPaginated?[(isSenderEmpty as! UIButton).tag]
            let userDestination = UserDestination(friend?.fullName,friend?.idFB,friend?.pictureUrl,nil,nil)
            (segue.destination as! MyDrinksViewController).forwardOrder?.userDestination = userDestination
            
            //Order.sharedIstance.userDestination = userDestination
            break
        default:
            break
        }
        
    }
    
    @IBAction func unwindToProfile(_ sender: UIBarButtonItem) {
        if self.segueFrom == "userView" {
            performSegue(withIdentifier: "unwindToProfile", sender: nil)
            
        }else if self.segueFrom == "offerView" {
            performSegue(withIdentifier: "unwindToOfferfromListFriendWithoutValue", sender: nil)
            
        }else if self.segueFrom == "myDrinks" {
            performSegue(withIdentifier: "unwidToMyDrinksWithoutValue", sender: nil)
        }
        
    }
    
}

    

