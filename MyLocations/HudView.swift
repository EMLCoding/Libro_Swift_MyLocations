//
//  HudView.swift
//  MyLocations
//
//  Created by Eduardo Martin Lorenzo on 23/02/2021.
//

// Se va a crear una VISTA PROPIA para mostrar una cuadrado en el centro de la pantalla con un check y un texto
import UIKit

class HudView: UIView {
    var text = ""
    
    // Esto es un constructor de conveniencia
    class func hud(inView view: UIView, animated: Bool) -> HudView {
        // HudView(frame:) es un metodo heredado de UIView y permite crear una instancia de HudView
        let hudView = HudView(frame: view.bounds)
        hudView.isOpaque = false
        
        // Agrega esta vista como una subvista de la vista padre, que sera la que se pase como parametro de entrada del constructor de conveniencia, por lo que cubrira toda la pantalla
        view.addSubview(hudView)
        // Esto hace que el usuario no pueda interactuar con la pantalla mientras esta vista este visible
        view.isUserInteractionEnabled = false
        
        hudView.show(animated: animated)
        
        return hudView
    }
    
    // Este metodo se invoca siempre que se va a dibujar la vista
    override func draw(_ rect: CGRect) {
        // Al trabajar con Core Graphics se debe usar CGFloat para valores decimales
        let boxWidth: CGFloat = 96
        let boxHeight: CGFloat = 96
        
        // Sirve para colocar el cuadrado en el centro de la pantalla
        // bounds.size coge automaticamente el tamaño de la vista en la que estamos
        let boxRect = CGRect(x: round((bounds.size.width - boxWidth) / 2), y: round((bounds.size.height - boxHeight) / 2), width: boxWidth, height: boxHeight)
        
        // Permite dibujar un rectangulo con esquinas redondeadas
        let roundedRect = UIBezierPath(roundedRect: boxRect, cornerRadius: 10)
        
        // Rellena la vista con un color
        UIColor(white: 0.3, alpha: 0.8).setFill()
        roundedRect.fill()
        
        // Dibuja el check
        if let image = UIImage(named: "Checkmark") {
            let imagePoint = CGPoint(x: center.x - round(image.size.width / 2), y: center.y - round(image.size.height / 2) - boxHeight / 8)
            image.draw(at: imagePoint)
        }
        
        // Dibuja el texto
        // Primero se crea un diccionario de atributos para el texto
        let attribs = [
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 16),
            NSAttributedString.Key.foregroundColor: UIColor.white]
        
        // Se guarda el tamaño del texto, que sera un objeto CGSize
        let textSize = text.size(withAttributes: attribs)
        
        let textPoint = CGPoint(x: center.x - round(textSize.width / 2), y: center.y - round(textSize.height / 2) + boxHeight / 4)
        
        text.draw(at: textPoint, withAttributes: attribs)
    }
    
    // MARK:- Public Methods
    func show(animated: Bool) {
        if animated {
            // 1: Configura el estado inicial de la vista antes de que inicie la animacion
            alpha = 0 // Vista completamente transparente
            transform = CGAffineTransform(scaleX: 1.3, y: 1.3) // La vista se escala para ser un poco mas grande de lo que debe
            
            // 2: Se inicia la animacion
            // Es una animacion del tipo "spring" que permite que la animacion tenga un efecto "rebote"
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: [], animations: {
                // 3: Se modifican las propiedades durante la animacion para hacer el efecto
                self.alpha = 1
                self.transform = CGAffineTransform.identity // Devuelve al tamaño real la view
            }, completion: nil)
        }
    }
    
    func hide() {
        superview?.isUserInteractionEnabled = true
        removeFromSuperview()
    }
}
