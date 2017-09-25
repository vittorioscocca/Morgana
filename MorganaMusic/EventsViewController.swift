//
//  ViewController.swift
//  WKWebView
//
//  Created by Vittorio Scocca on 22/02/17.
//  Copyright © 2017 Vittorio Scocca. All rights reserved.
//

import UIKit
import WebKit //approfondimento https://developer.apple.com/reference/webkit/wkwebview

class EventsViewController: UIViewController, UITextFieldDelegate{

    @IBOutlet var myTextField_field: UITextField!
    @IBOutlet var myProgressView: UIProgressView!
    @IBOutlet var myView: UIView!
    
    var webView: WKWebView!
    var urlNavigazione: [String] = []
   
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.myTextField_field.frame.size.width = self.view.frame.width
        // creo l'oggetto WKWebView con le stesse dimensioni della myView
        self.webView = WKWebView(frame: self.view.frame)
        
        self.webView.navigationDelegate = self as? WKNavigationDelegate
        
        // aggiungo come subview la webView alla myView
        self.myView.addSubview(self.webView)
        self.myTextField_field.delegate = TextFieldController.singleton
        
        self.setWebView()
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        
        self.setWebView()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(true)
        
        self.webView?.removeObserver(self, forKeyPath: "estimatedProgress")
    }
    
    private func setWebView(){
        self.webView.addObserver(self, forKeyPath: "estimatedProgress", options: .new, context: nil)
        
        
        self.loadURL("www.facebook.com/pg/morganamusiclub/events/?ref=page_internal") // invoco la funzione loadURL e richiedo la visualizzazione del sito di partenza
        self.myTextField_field.text = "https://goo.gl/1CSLF4"
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    func loadURL(_ fromString: String) {
        var url: URL?
        url = URL(string: "http://" + fromString) // creo un URL partendo dalla stringa
        let request = URLRequest(url: url!) // creo la richiesta da far effettuare alla webview
        self.webView.load(request) // performo la richiesta
    }
    
    // Funzione per utilizzare la field per ricerche su google,il parametro è il testo da cercare su google. Es: xcoding.it swift
    func searchOnGoogle(_ fromString: String) {
        let stringArray = fromString.components(separatedBy: " ")
        let searchString = stringArray.joined(separator: "+")
        let url = URL(string: "https://www.google.com/search?q=" + searchString)
        let request = URLRequest(url: url!)
        self.webView.load(request) // performo la richiesta
        
    }
    
    //metodo per il controllo degli Observer:
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if (keyPath == "estimatedProgress") {
            myProgressView.isHidden = webView.estimatedProgress == 1
            myProgressView.setProgress(abs(Float(webView.estimatedProgress)), animated: true)
        }
        if self.webView.url?.absoluteString != "https://m.www.facebook.com/pg/morganamusiclub/events/?ref=page_internal" {
            self.myTextField_field.text = self.webView.url?.absoluteString
        }
    }
    
    
    @IBAction func goToHOme(_ sender: UIBarButtonItem) {
        self.loadURL("www.facebook.com/pg/morganamusiclub/events/?ref=page_internal")
        
    }
    
    
    
    @IBAction func textField_DidEnd(_ sender: UITextField) {
    
        guard let testo = sender.text else {return}
        
        // se l'utente inserisce una stringa che comincia per "www" allora vuole collegarsi ad un sito web
        if testo.hasPrefix("www") {
            self.loadURL(testo)
        } else {
            // altrimenti sta provando a cercare su google
            self.searchOnGoogle(testo)
        }
    
    }
   
    @IBAction func refreshAction(_ sender: UIBarButtonItem) {
        self.webView.reload()
    }
    
    @IBAction func urlPrecedente_pressed(_ sender: UIBarButtonItem) {
        guard  self.webView.canGoBack else{
          return
        }
        self.webView.goBack()
    }
    
    
}

