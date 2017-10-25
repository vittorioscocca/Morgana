//
//  FriendsListViewController.swift
//  MorganaMusic
//
//  Created by Vittorio Scocca on 03/05/17.
//  Copyright © 2017 Vittorio Scocca. All rights reserved.
//

import UIKit
import FBSDKLoginKit

//User Facebook Friends List that use the app
class FriendsListViewController: UIViewController,UITableViewDelegate, UITableViewDataSource, UISearchResultsUpdating {

    @IBOutlet weak var myTable: UITableView!
    @IBOutlet weak var numAmici: UIBarButtonItem!
   
    var segueFrom: String?
    
    var resultSearchController: UISearchController?
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
    var defaults = UserDefaults.standard
    var user: User?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.myTable.dataSource = self
        self.myTable.delegate = self
        self.userId = fireBaseToken.object(forKey: "FireBaseToken")! as? String
        self.getFriendsList()
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
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    private func getFriendsList(){
        guard CheckConnection.isConnectedToNetwork() == true else {
            return
        }
        
        //if friends list is 0, load user Facebook friends
        guard self.user?.friends?.count != 0 else {
            self.getFriends(mail: (self.user?.email)!)
            print("chiamata1")
            let date = Date()
            self.defaults.set(date, forKey: "Data")
            return
        }
        
        //if request is > 18000 seconds refresh list friends  with getFriends func
        guard self.refreshUpdateFriendList() else {
            self.updateData()
            return
        }
        self.getFriends(mail: (self.user?.email)!)
        print("chiamata2")
    }
    
    private func updateData(){
        self.friendsList = CoreDataController.sharedIstance.loadAllFriendsOfUser(idAppUser: self.userId!)
        self.user = CoreDataController.sharedIstance.findUserForIdApp(self.user?.idApp)
        self.loadList()
        self.myTable.reloadData()
    }
    
    func getFriends(mail: String){
        print("Update Friends List")
        
        
        CoreDataController.sharedIstance.deleteFriends((self.user?.idApp)!)
        
        let fbToken = UserDefaults.standard
        let fbTokenString = fbToken.object(forKey: "FBToken") as? String
        
        
        let parameters_friend = ["fields" : "name, first_name, last_name, id, email, gender, picture.type(large)"]
        
        FBSDKGraphRequest(graphPath: "me/friends", parameters: parameters_friend, tokenString: fbTokenString, version: nil, httpMethod: "GET").start(completionHandler: {(connection,result, error) -> Void in
            if ((error) != nil)
            {
                // Process error
                print("Error: \(error!)")
                return
            }
            //numbers of total friends
            let newResult = result as! NSDictionary
            let summary = newResult["summary"] as! NSDictionary
            let counts = summary["total_count"] as! NSNumber
            
            print("Totale amici letti:  \(counts)")
            var contFriends = 0
            
            //self.startActivityIndicator("Carico lista amici...")
            let dati: NSArray = newResult.object(forKey: "data") as! NSArray
            
            guard dati.count != 0 else {
                return
            }
            
            for i in 0...(dati.count - 1) {
                contFriends += 1
                let valueDict: NSDictionary = dati[i] as! NSDictionary
                let name = valueDict["name"] as? String
                let idFB = valueDict["id"] as! String
                let firstName = valueDict["first_name"] as! String
                let lastName = valueDict["last_name"] as! String
                
                //let gender = valueDict["gender"] as! String
                let picture = valueDict["picture"] as! NSDictionary
                let data = picture["data"] as? NSDictionary
                let url = data?["url"] as? String
                
                FirebaseData.sharedIstance.readUserIdAppFromIdFB(node: "users", child: "idFB", idFB: idFB, onCompletion: { (error,idApp) in
                    guard error == nil else {
                        print(error!)
                        return
                    }
                    guard idApp != nil else {return}
                    FirebaseData.sharedIstance.readUserCityOfRecidenceFromIdFB(node: "users/\(idApp!)", onCompletion: { (error, cityOfRecidence) in
                        CoreDataController.sharedIstance.addFriendInUser(idAppUser: (self.user?.idApp)!, idFB: idFB, mail: mail, fullName: name, firstName: firstName, lastName: lastName, gender: nil, pictureUrl: url, cityOfRecidence: cityOfRecidence)
                        if i == (dati.count - 1) {
                            self.updateData()
                        }
                    })
                })
                
            }
            print("Aggiornamento elnco amici di Facebook completato!. Inseriti \(contFriends) amici")
            
        })
    }
    
    func refreshUpdateFriendList() -> Bool{
        //create first request Date
        guard  defaults.object(forKey: "Data") != nil else {
            let date = Date()
            self.defaults.set(date, forKey: "Data")
            print("data prima richiesta: ",defaults.object(forKey: "Data")!)
            return true
        }
        
        //current Date
        let currentDate = Date()
        
        
        // difference in seconds from TimeIntervalNow and one date
        let diffTime = (defaults.object(forKey: "Data") as! Date).timeIntervalSinceNow * -1
        print(diffTime)
        
        //if the request is > 1/2 gg (18000 sec) refresh FB Friends List
        //for test: don't insert a value < 5
        if diffTime > 18000 {
            self.defaults.set(currentDate, forKey: "Data")
            return true
        }
        return false
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
        if friend?.cityOfRecidence != nil {
            (cell as! FirendsListTableViewCell).cityOfRecidence.text = friend?.cityOfRecidence
            (cell as! FirendsListTableViewCell).cityOfRecidence.isHidden = false
        }
        
        if self.segueFrom == "myDrinks" {
            (cell as! FirendsListTableViewCell).forwardButton.isHidden = false
            (cell as! FirendsListTableViewCell).forwardButton.tag = indexPath.row
            (cell as! FirendsListTableViewCell).forwardButton.addTarget(self, action: #selector(forwardAction(_:)), for: .touchUpInside)
        } 
        
        // If this image is already cached, don't re-download
        
        CacheImage.getImage(url: friend?.pictureUrl, onCompletion: { (image) in
            guard image != nil else {
                print("immagine utente non reperibile")
                return
            }
            DispatchQueue.main.async(execute: {
                if let cellToUpdate = tableView.cellForRow(at: indexPath) {
                    (cellToUpdate as! FirendsListTableViewCell).friendImageView.image = image
                }
            })
        })
        print("Caricamento tablella ended")
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
        self.friendsListPaginated = []
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
            //order is != nil when forward action is called. This code clean from friendsList  friends that has refused the order
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
        refreshControl.addTarget(self, action: #selector(FriendsListViewController.handleRefresh(_:)), for: UIControlEvents.valueChanged)
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
            (segue.destination as! MyOrderViewController).forwardOrder?.userDestination = userDestination
            
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

    

