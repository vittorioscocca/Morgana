//
//  InitialSliderViewController.swift
//  MorganaMusic
//
//  Created by Vittorio Scocca on 26/04/17.
//  Copyright © 2017 Vittorio Scocca. All rights reserved.
//

import UIKit

class InitialSliderViewController: UIViewController {
    
    @IBOutlet weak var backImageView: UIImageView!
    @IBOutlet weak var labelTitolo: UILabel!
    @IBOutlet weak var labelSottotitolo: UILabel!
    @IBOutlet weak var pageControl: UIPageControl!

    let array_titoli = [
        "Il Morgana ti offre da bere.",
        "Ovunque ti trovi, noi saremo con te.",
        "Massimizza il tuo profitto. Segui i nostri consigli."
    ]
    
    let array_sottotitoli = [
        "In base ad una classifica mensile offriremo da bere ai migliori clienti",
        "Grazie alla geolocalizzazione potrai salvare il luogo esatto del tuo appuntamento.",
        "É dimostrato, chi scrive e annota gli appuntamenti genera un fatturato maggiore."
    ]
    
    let array_images = ["Intro1", "login", "login"]
    var array_index = 0
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.backImageView.image = UIImage(named: self.array_images[0])
        self.labelTitolo.text! = self.array_titoli[0]
        self.labelSottotitolo.text! = self.array_sottotitoli[0]
        
        self.pageControl.currentPage = 0
        self.pageControl.isEnabled = false
        
        let leftSwipe = UISwipeGestureRecognizer(target: self, action: #selector(InitialSliderViewController.handleSwipes(_:)))
        let rightSwipe = UISwipeGestureRecognizer(target: self, action: #selector(InitialSliderViewController.handleSwipes(_:)))
        
        leftSwipe.direction = .left
        rightSwipe.direction = .right
        
        view.addGestureRecognizer(leftSwipe)
        view.addGestureRecognizer(rightSwipe)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @objc func handleSwipes(_ sender: UISwipeGestureRecognizer) {
        
        switch sender.direction {
        case UISwipeGestureRecognizerDirection.left:
            if self.array_index < self.array_images.count - 1 {
                self.array_index += 1
                self.pageControl.currentPage += 1
            }
            
        case UISwipeGestureRecognizerDirection.right:
            if self.array_index > 0 {
                self.array_index -= 1
                self.pageControl.currentPage -= 1
            }
            
        default:
            break
        }
        self.backImageView.image = UIImage(named: self.array_images[self.array_index])
        self.labelTitolo.text! = self.array_titoli[self.array_index]
        self.labelSottotitolo.text! = self.array_sottotitoli[self.array_index]
        
        self.labelTitolo.transform = CGAffineTransform(translationX: -400, y: 0)
        self.labelSottotitolo.transform = CGAffineTransform(translationX: 400, y: 0)
        self.backImageView.transform = CGAffineTransform(scaleX: 1.4, y: 1.4)
        
        UIView.animate(withDuration: 0.5, animations: { () -> Void in
            self.backImageView.transform = CGAffineTransform.identity
            self.labelTitolo.transform = CGAffineTransform.identity
            self.labelSottotitolo.transform = CGAffineTransform.identity
        })
    }

    @IBAction func skipIntro(_ sender: UIButton) {
        self.performSegue(withIdentifier: "segueToHome", sender: nil)
    
    }
    

    

}
