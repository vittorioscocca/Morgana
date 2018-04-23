//
//  MapViewController.swift
//  MorganaMusic
//
//  Created by Vittorio Scocca on 13/08/17.
//  Copyright © 2017 Vittorio Scocca. All rights reserved.
//

import UIKit
import MapKit

class MapViewController: UIViewController, CLLocationManagerDelegate {

    @IBOutlet weak var myMap: MKMapView!
    @IBOutlet var menuButton: UIBarButtonItem!
    
    private var locationManager = CLLocationManager()
    private var userLocation: CLLocationCoordinate2D?
    private var merchantLocation: CLLocationCoordinate2D?
    private var merchantCoordinate: (latitude:CLLocationDegrees? ,longitude:CLLocationDegrees?)
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if revealViewController() != nil {
            menuButton.target = revealViewController()
            menuButton.action = #selector(SWRevealViewController.revealToggle(_:))
            view.addGestureRecognizer(self.revealViewController().panGestureRecognizer())
        }
        self.initializeLocationManager()
        self.setUserAndMerchantPosition()
       
    }

    private func initializeLocationManager(){
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    
    private func setUserAndMerchantPosition(){
        //if we have the coordinates from manager
        if let location = locationManager.location?.coordinate{
            
            userLocation = CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
            
            let region = MKCoordinateRegion(center: userLocation!, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
            
            myMap.setRegion(region, animated: true)
            let annotion = MKPointAnnotation()
            annotion.coordinate = userLocation!
            annotion.title = "Your Position"
            myMap.addAnnotation(annotion)
            
        }
        
        self.readMerchantLocationFromFireBase(onCompletion:  { (coordinates) in
            
            if coordinates.latitude != nil  && coordinates.longitude != nil {
                self.merchantLocation = CLLocationCoordinate2D(latitude: coordinates.latitude!, longitude: coordinates.longitude!)
                let annotion = MKPointAnnotation()
                annotion.coordinate = self.merchantLocation!
                annotion.title = "Morgana Music Club"
                self.myMap.addAnnotation(annotion)
            }
        })
        
    }
    
//    //continuos updating locations
//    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
//
//
//        /*if we have the coordinates from manager
//        if let location = locationManager.location?.coordinate{
//
//            userLocation = CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
//
//
//            let region = MKCoordinateRegion(center: userLocation!, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
//            myMap.setRegion(region, animated: true)
//            let annotion = MKPointAnnotation()
//            annotion.coordinate = userLocation!
//            annotion.title = "Your Position"
//            myMap.addAnnotation(annotion)
//
//        }*/
//
//        self.readMerchantLocationFromFireBase(onCompletion:  { (localCoordinates) in
//            if let location = self.locationManager.location?.coordinate,
//                localCoordinates.latitude != nil  && localCoordinates.longitude != nil
//            {
//                let userLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
//                let merchantLocation = CLLocation(latitude: localCoordinates.latitude!, longitude: localCoordinates.longitude!)
//                let distanceInMeters = userLocation.distance(from: merchantLocation)
//                if distanceInMeters < 5 {
//                    print("****** SI sei vicino")
//                }else {
//                    print("****** Troppo Lontano")
//                }
//            }
//
//
//            /*
//            let annotion = MKPointAnnotation()
//            annotion.coordinate = self.merchantLocation!
//            annotion.title = "Morgana Music Club"
//            self.myMap.addAnnotation(annotion)*/
//
//        })
//
//    }
    // manual merchant check-in
    @IBAction func onCheckIn(_ sender: UIButton) {
        readMerchantLocationFromFireBase(onCompletion:  { (localCoordinates) in
            if let location = self.locationManager.location?.coordinate,
                localCoordinates.latitude != nil  && localCoordinates.longitude != nil
            {
                let userLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
                let merchantLocation = CLLocation(latitude: localCoordinates.latitude!, longitude: localCoordinates.longitude!)
                let distanceInMeters = userLocation.distance(from: merchantLocation)
                if distanceInMeters < 5 {
                    print("****** SI sei vicino")
                }else {
                    print("****** Troppo Lontano")
                }
            }
        })
            
    }
    
    
    private func readMerchantLocationFromFireBase (onCompletion: @escaping( (latitude:CLLocationDegrees? ,longitude:CLLocationDegrees?)) -> ()){
        var coordinates: (latitude:CLLocationDegrees? ,longitude:CLLocationDegrees?)
        FireBaseAPI.readNodeOnFirebaseWithOutAutoId(node: "merchant/mr001", onCompletion:{ (error,dictionary) in
            guard error == nil else {
                return
            }
            guard dictionary != nil else {
                return
            }
            for (chiave,valore) in dictionary! {
                switch chiave {
                case "latitude":
                    coordinates.latitude = valore as? CLLocationDegrees
                    
                    break
                case "longitude":
                    coordinates.longitude = valore as? CLLocationDegrees
                    break
                default:
                    break
                }
            }
            onCompletion(coordinates)
        })
    }
    

    
}
