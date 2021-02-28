//
//  FirstViewController.swift
//  MyLocations
//
//  Created by Eduardo Martin Lorenzo on 09/02/2021.
//

import UIKit
import CoreLocation
import CoreData
// Para reproducir sonidos
import AudioToolbox

// Para poder hacer uso de los metodos de CoreLocation hay que hacer que CurrentLocationViewController sea delegado de CLLocationManagerDelegate
class CurrentLocationViewController: UIViewController, CLLocationManagerDelegate, CAAnimationDelegate {
    
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var latitudeLabel: UILabel!
    @IBOutlet weak var longitudeLabel: UILabel!
    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var tagButton: UIButton!
    @IBOutlet weak var getButton: UIButton!
    
    @IBOutlet weak var latitudeTextLabel: UILabel!
    @IBOutlet weak var longitudeTextLabel: UILabel!
    @IBOutlet weak var containerView: UIView!
    
    let locationManager = CLLocationManager()
    // Los objetos CLLocation contienen el objeto CLLocationCoordinate2D, que almacena la longitud y la altitud
    var location: CLLocation?
    
    // Para el manejo de errores
    var updatingLocation = false
    var lastLocationError: Error?
    
    // Para obtener una direccion real a partir de las coordenadas de localizacion
    let geocoder = CLGeocoder()
    var placemark: CLPlacemark?
    var performingReverseGeocoding = false // Para controlar si ya se esta realizando un proceso de geocodificacion
    var lastGeocodingError: Error?
    
    var timer: Timer?
    
    var managedObjectContext: NSManagedObjectContext!
    
    var logoVisible = false
    lazy var logoButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setBackgroundImage(UIImage(named: "Logo"), for: .normal)
        button.sizeToFit()
        button.addTarget(self, action: #selector(getLocation), for: .touchUpInside)
        button.center.x = self.view.bounds.midX
        button.center.y = 220
        return button
    }()
    
    var soundID: SystemSoundID = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        updateLabels()
        containerView.isHidden = false
        
        loadSoundEffect("Sound.caf")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Se quiere esconder el titulo que da el navigation controller en esta pantalla
        navigationController?.isNavigationBarHidden = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Como se ha ocultado el titulo del navigation controller al aparecer esta pantalla tambien se oculta en todas las pantallas siguientes en la pila del navigation controller, asi que para que aparezca el titulo en las demas se debe poner a false cuando esta pantalla, CurrentLocation, vaya a desaparecer
        navigationController?.isNavigationBarHidden = false
    }
    
    func updateLabels() {
        if let location = location {
            latitudeLabel.text = String(format: "%.8f", location.coordinate.latitude)
            longitudeLabel.text = String(format: "%.8f", location.coordinate.longitude)
            
            tagButton.isHidden = false
            messageLabel.text = ""
            
            if let placemark = placemark {
                addressLabel.text = string(from: placemark)
            } else if performingReverseGeocoding{
                addressLabel.text = "Searching for Address..."
            } else if lastGeocodingError != nil {
                addressLabel.text = "Error Finding Address"
            } else {
                addressLabel.text = "No Address Found"
            }
            
            latitudeTextLabel.isHidden = false
            longitudeTextLabel.isHidden = false
            
            if logoVisible {
                hideLogoView()
            }
        } else {
            latitudeLabel.text = ""
            longitudeLabel.text = ""
            addressLabel.text = ""
            tagButton.isHidden = true
            
            let statusMessage: String
            if let error = lastLocationError as NSError? {
                if error.domain == kCLErrorDomain && error.code == CLError.denied.rawValue {
                    statusMessage = "Location Services Disabled"
                } else {
                    statusMessage = "Error Getting Location"
                }
                // En este if se comprueba que no este deshabilitada la localizacion en el propio dispositivo
            } else if !CLLocationManager.locationServicesEnabled() {
                statusMessage = "Location Services Disabled"
            } else if updatingLocation {
                statusMessage = "Searching..."
            } else {
                statusMessage = ""
                showLogoView()
            }
            messageLabel.text = statusMessage
            
            latitudeTextLabel.isHidden =  true
            longitudeTextLabel.isHidden = true
        }
        
        configureGetButton()
    }
    
    func showLogoView() {
        if !logoVisible {
            logoVisible = true
            containerView.isHidden = true
            view.addSubview(logoButton)
        }
    }
    
    func hideLogoView() {
        if !logoVisible { return }
        
        logoVisible = false
        containerView.isHidden = false
        containerView.center.x = view.bounds.size.width * 2
        containerView.center.y = 40 + containerView.bounds.size.height / 2
        
        let centerX = view.bounds.midX
        
        let panelMover = CABasicAnimation(keyPath: "position")
        panelMover.isRemovedOnCompletion = false
        panelMover.fillMode = CAMediaTimingFillMode.forwards
        panelMover.duration = 0.6
        panelMover.fromValue = NSValue(cgPoint: containerView.center)
        panelMover.toValue = NSValue(cgPoint: CGPoint(x: centerX, y: containerView.center.y))
        panelMover.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeOut)
        panelMover.delegate = self
        containerView.layer.add(panelMover, forKey: "panelMover")
        
        let logoMover = CABasicAnimation(keyPath: "position")
        logoMover.isRemovedOnCompletion = false
        logoMover.fillMode = CAMediaTimingFillMode.forwards
        logoMover.duration = 0.5
        logoMover.fromValue = NSValue(cgPoint: logoButton.center)
        logoMover.toValue = NSValue(cgPoint: CGPoint(x: -centerX, y: logoButton.center.y))
        logoMover.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeIn)
        logoButton.layer.add(logoMover, forKey: "logoMover")
        
        let logoRotator = CABasicAnimation(keyPath: "transform.rotation.z")
        logoRotator.isRemovedOnCompletion = false
        logoRotator.fillMode = CAMediaTimingFillMode.forwards
        logoRotator.duration = 0.5
        logoRotator.fromValue = 0.0
        logoRotator.toValue = -2 * Double.pi
        logoRotator.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeIn)
        logoButton.layer.add(logoRotator, forKey: "logoRotator")
    }
    
    // MARK:- Actions
    @IBAction func getLocation() {
        // Bloque de codigo para pedir permisos de ubicacion. Tambien hay que añadir una clave en Info.plist (Privacy - Location When In Use Usage Description)
        let authStatus = locationManager.authorizationStatus
        if authStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
            return
        }
        
        if authStatus == .denied || authStatus == .restricted {
            showLocationServicesDeniedAlert()
            return
        }
        
        if updatingLocation {
            stopLocationManager()
        } else {
            location = nil
            lastLocationError = nil
            placemark = nil
            lastGeocodingError = nil
            startLocationManager()
        }
        updateLabels()
    }
    
    // MARK:- CLLocationManagerDelegate
    // Esta funcion se ejecutara cuando se intente conseguir la ubicacion pero se hayan rechazado los permisos
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("didFailWithError \(error.localizedDescription)")
        
        // Si el error es que todavia no ha encontrado la ubicacion entonces lo unico que hace es seguir intentandolo
        if (error as NSError).code == CLError.locationUnknown.rawValue {
            return
        }
        
        // Pero si llegamos a aqui es que el error es mas grave
        lastLocationError = error
        // Hay que parar la busqueda de la ubicacion para evitar gastar bateria innecesariamente
        stopLocationManager()
        updateLabels()
    }
    
    // Este metodo se llama de forma constante mientras que el movil este buscando la ubicacion
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        print("Llega una nueva ubicacion porque se esta buscando constantemente")
        // locations.last permite coger el ultimo valor del array. Hay que coger el ultimo porque sera la ubicacion mas precisa que devuelve el dispositivo
        let newLocation = locations.last!
        print("didUpdateLocations \(newLocation)")
        
        // Se deben ignorar las ubicaciones almacenadas en cache durante mucho tiempo (5 segundos es suficiente tiempo)
        if newLocation.timestamp.timeIntervalSinceNow < -5 {
            return
        }
        
        // Si la precision horizontal es menor que 0 entonces la ubicacion encontrada no vale
        if newLocation.horizontalAccuracy < 0 {
            return
        }
        
        // greatestFiniteMagnitude devuelve el valor maximo que puede tener un Double
        var distance = CLLocationDistance(Double.greatestFiniteMagnitude)
        // Se va a utilizar distance para verificar si se ha encontrado una localizacion mas exacta a la anterior
        if let location = location {
            distance = newLocation.distance(from: location)
        }
        
        
        if location == nil || location!.horizontalAccuracy > newLocation.horizontalAccuracy {
            location = newLocation
            // En caso de que se haya producido un error porque no se encontraba la ubicacion pero al dar un paso se llame a este metodo y si haya ubicacion, es conveniente borrar el ultimo error de localizacion
            lastLocationError = nil
            
            // Si la precision de la nueva ubicacion es igual o mejor que la precision deseada entonces ya podemos dejar de buscar la ubicacion. Para que una ubicacion sea MEJOR debe ser MENOR, por eso el '<='
            if newLocation.horizontalAccuracy <= locationManager.desiredAccuracy {
                print("*** We're done! - Se para la busqueda de nuevas ubicaciones")
                stopLocationManager()
                
                if distance > 0 {
                    // Se pone a false porque se ha encontrado una ubicacion mas exacta y se quiere parar (para volver a lanzar) el proceso de geocodificacion, si es que se estaba realizando
                    performingReverseGeocoding = false
                }
            }
            updateLabels()
            
            // Si no se esta realizando ya un proceso de geocodificacion...
            if !performingReverseGeocoding {
                print("***Se va a geocodificar")
                performingReverseGeocoding = true
                // Se usa un closure, el completionHandler, que se ejecutara cuando se haya obtenido la direccion del proceso de geocodificacion
                geocoder.reverseGeocodeLocation(newLocation, completionHandler: {
                    placemarks, error in
                    self.lastGeocodingError = error
                    // Si el error es nil, entonces desempaquetamos placemarks en p SIEMPRE Y CUANDO p (es decir, placemarks) no este vacio
                    if error == nil, let p = placemarks, !p.isEmpty {
                        if self.placemark == nil {
                            print("First Time!")
                            self.playSoundEffect()
                        }
                        // Guarda en placemark la ultima direccion encontrada (es un array)
                        self.placemark = p.last!
                    } else {
                        self.placemark = nil
                    }
                    
                    self.performingReverseGeocoding = false
                    self.updateLabels()
                })
            }
        } else if distance < 1 {
            let timeInterval = newLocation.timestamp.timeIntervalSince(location!.timestamp)
            // Si han pasado 10 segundos y la ubicacion encontrada no es mejor que la anterior entonces se deduce que ya no se va a encontrar una ubicacion mas precisa
            if timeInterval > 10 {
                print("*** Force done!")
                stopLocationManager()
                updateLabels()
            }
        }
    }
    
    // MARK:- Helper Methods
    func showLocationServicesDeniedAlert() {
        let alert = UIAlertController(title: "Location Services Disabled", message: "Please enable location services for this app in Settings.", preferredStyle: .alert)
        
        let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        alert.addAction(okAction)
        present(alert, animated: true, completion: nil)
    }
    
    func configureGetButton() {
        let spinnerTag = 1000
        
        if updatingLocation {
            getButton.setTitle("Stop", for: .normal)
            
            if view.viewWithTag(spinnerTag) == nil {
                let spinner = UIActivityIndicatorView(style: .white)
                spinner.center = messageLabel.center
                spinner.center.y += spinner.bounds.size.height/2 + 25
                spinner.startAnimating()
                spinner.tag = spinnerTag
                containerView.addSubview(spinner)
            }
        } else {
            getButton.setTitle("Get My Location", for: .normal)
            
            if let spinner = view.viewWithTag(spinnerTag) {
                spinner.removeFromSuperview()
            }
        }
    }
    
    func startLocationManager() {
        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            locationManager.startUpdatingLocation()
            updatingLocation = true
            
            // El timer se ejecutara a los 60 segundos llamando al metodo didTimeOut(). #selector es un elemento de Objective-C
            timer = Timer.scheduledTimer(timeInterval: 60, target: self, selector: #selector(didTimeOut), userInfo: nil, repeats: false)
        }
    }
    
    func stopLocationManager() {
        if updatingLocation {
            locationManager.stopUpdatingLocation()
            locationManager.delegate = nil
            updatingLocation = false
            
            if let timer = timer {
                // Para cancelar el temporizador
                timer.invalidate()
            }
        }
    }
    
    // Es necesario usar @objc para que sea accesible desde Objective-C, porque el timer lo necesita por ser usado con el #selector()
    @objc func didTimeOut() {
        // Si el timer ha llegado al final (60 segundos) entonces se va a parar el proceso de busqueda de ubicacion y se va a guardar un error
        print("*** Time out")
        if location == nil {
            stopLocationManager()
            // Se le pone code: 1 porque sera el codigo de error, para poder encontrarlo si hay muchos errores personalizados en la app
            lastLocationError = NSError(domain: "MyLocationsErrorDomain", code: 1, userInfo: nil)
            updateLabels()
        }
    }
    
    // Este metodo sirve para convertir la direccion dada por el proceso de geocodificacion en un string
    func string(from placemark: CLPlacemark) -> String {
        var linea1 = ""
        
        linea1.add(text: placemark.subThoroughfare)
        linea1.add(text: placemark.thoroughfare, separatedBy: " ")
        
        var linea2 = ""
        linea2.add(text: placemark.locality)
        linea2.add(text: placemark.administrativeArea, separatedBy: " ")
        linea2.add(text: placemark.postalCode, separatedBy: " ")
        
        linea1.add(text: linea2, separatedBy: "\n")
        return linea1
    }
    
    // MARK:- Animation Delegate Methods
    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        containerView.layer.removeAllAnimations()
        containerView.center.x = view.bounds.size.width / 2
        containerView.center.y = 40 + containerView.bounds.size.height / 2
        logoButton.layer.removeAllAnimations()
        logoButton.removeFromSuperview()
    }
    
    // MARK:- Sound effects
    func loadSoundEffect(_ name: String) {
        if let path = Bundle.main.path(forResource: name, ofType: nil) {
            let fileURL = URL(fileURLWithPath: path, isDirectory: false)
            let error = AudioServicesCreateSystemSoundID(fileURL as CFURL, &soundID)
            if error != kAudioServicesNoError {
                print("Error code \(error) loading sound: \(path)")
            }
        }
    }
    
    func unloadSoundEffect() {
        AudioServicesDisposeSystemSoundID(soundID)
        soundID = 0
    }
    
    func playSoundEffect() {
        AudioServicesPlaySystemSound(soundID)
    }
    
    // MARK:- Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "TagLocation" {
            let controller = segue.destination as! LocationDetailsViewController
            // Se le pasa a las variables coordinate y placemark de LocationDetailsViewController los valores de este controlador, a traves de la segue
            if let coordinate = location?.coordinate {
                controller.coordinate = coordinate
            }
            // Como placemark es opcional en ambos controladores, no es necesario desempaquetarla
            controller.placemark = placemark
            
            // Necesario para que LocationDetailsViewController pueda guardar datos en SQLite con CoreData
            controller.managedObjectContext = managedObjectContext
        }
    }


}
