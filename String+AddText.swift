//
//  String+AddText.swift
//  MyLocations
//
//  Created by Eduardo Martin Lorenzo on 27/02/2021.
//

import UIKit

extension String {
    // como String es un struct es necesario usar "mutating". Esto indica que este metodo solo se podra usar con los String tipo "var"
    mutating func add(text: String?, separatedBy separator: String = "") {
        if let text = text {
            if !isEmpty {
                self += separator
            }
            self += text
        }
    }
}
