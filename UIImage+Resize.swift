//
//  UIImage + Resize.swift
//  MyLocations
//
//  Created by Eduardo Martin Lorenzo on 27/02/2021.
//

import UIKit

// De esta forma se añaden nuevas funciones a los objetos UIImage para esta app
extension UIImage {
    // Permite redimensionar las imagenes
    func resized(withBounds bounds: CGSize) -> UIImage {
        let horizontalRatio = bounds.width / size.width
        let verticalRatio = bounds.height / size.height
        let ratio = min(horizontalRatio, verticalRatio)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        UIGraphicsBeginImageContextWithOptions(newSize, true, 0)
        draw(in: CGRect(origin: CGPoint.zero, size: newSize))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage!
    }
}
