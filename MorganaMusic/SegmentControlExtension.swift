//
//  SegmentControlExtension.swift
//  MorganaMusic
//
//  Created by Vittorio Scocca on 13/07/17.
//  Copyright © 2017 Vittorio Scocca. All rights reserved.
//

import Foundation

extension UISegmentedControl {
    
    func removeBorders() {
        setBackgroundImage(imageWithColor(color: UIColor.clear), for: .normal, barMetrics: .default)
        setBackgroundImage(imageWithColor(color: tintColor!), for: .selected, barMetrics: .default)
        
        setDividerImage(imageWithColor(color: UIColor.clear), forLeftSegmentState: .normal, rightSegmentState: .normal, barMetrics: .default)
    }
    
    // create a 1x1 image with this color
    private func imageWithColor(color: UIColor) -> UIImage {
        let rect = CGRect(x: 0.0, y: 0.0, width:  1.0, height: 1.0)
        UIGraphicsBeginImageContext(rect.size)
        let context = UIGraphicsGetCurrentContext()
        context?.setFillColor(color.cgColor);
        context?.fill(rect);
        let image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        return image!
    }
    func addUnderlineForSelectedSegment(underlineWidth: CGFloat){
        //removeBorders()
        
        //let underlineWidth: CGFloat = (self.bounds.size.width - 15.0) / CGFloat(self.numberOfSegments)
        
        let underlineHeight: CGFloat = 2.0
        let underlineXPosition = CGFloat(selectedSegmentIndex) * underlineWidth
        let underLineYPosition = self.bounds.size.height - 2.0
        let underlineFrame = CGRect(x: underlineXPosition, y: underLineYPosition, width: underlineWidth, height: underlineHeight)
        let underline = UIView(frame: underlineFrame)
        underline.backgroundColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
        underline.tag = 1
        self.addSubview(underline)
    }
    
    func changeUnderlinePosition(){
        guard let underline = self.viewWithTag(1) else {return}
        let underlineFinalXPosition = (self.bounds.width / CGFloat(self.numberOfSegments)) * CGFloat(selectedSegmentIndex)
        UIView.animate(withDuration: 0.2, animations: {
            underline.frame.origin.x = underlineFinalXPosition
        })
    }
}



