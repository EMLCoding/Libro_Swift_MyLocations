//
//  MyTabBarController.swift
//  MyLocations
//
//  Created by Eduardo Martin Lorenzo on 27/02/2021.
//

import UIKit

class MyTabBarController: UITabBarController {
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override var childForStatusBarStyle: UIViewController? {
        return nil
    }
}
