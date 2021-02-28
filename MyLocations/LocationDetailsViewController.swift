//
//  LocationDetailsViewController.swift
//  MyLocations
//
//  Created by Eduardo Martin Lorenzo on 13/02/2021.
//

import UIKit
import CoreLocation
import CoreData

// Esto es un closure. Para convertir una fecha en un string hay que utilizar un objeto DateFormatter, sin embargo, este objeto consume muchos recursos cada vez que se crea. Por ello se hace de esta forma (mas optimizada que la forma usada en la app Checklists).
// Se creara el objeto DateFormatter una vez y solo la primera vez que se requiera (se llama 'carga diferida') y las siguientes veces que se necesite no se tendra que crear un nuevo objeto. Este uso es privado, unico para LocationDetailsViewController
private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
}()

class LocationDetailsViewController: UITableViewController {
    
    @IBOutlet weak var descriptionTextView: UITextView!
    @IBOutlet weak var categoryLabel: UILabel!
    @IBOutlet weak var latitudeLabel: UILabel!
    @IBOutlet weak var longitudeLabel: UILabel!
    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var addPhotoLabel: UILabel!
    @IBOutlet weak var imageHeight: NSLayoutConstraint!
    
    // CLLocationCoordinate2D es un struct. Este struct tiene dos variables, latitude y longitude, del tipo CLLocationDegrees. Estos tipos son exactamente iguales que el tipo Double
    // Los structs son mas livianos que las clases
    var coordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)
    var placemark: CLPlacemark?
    
    var categoryName = "No Category"
    
    // Necesario para usar Core Data y SQLite
    var managedObjectContext: NSManagedObjectContext!
    
    var date = Date()
    
    var locationToEdit: Location? {
        // El codigo del didSet se ejecuta cada vez que se modifica el valor de la variable locationToEdit
        didSet {
            if let location = locationToEdit {
                descriptionText = location.locationDescription
                categoryName = location.category
                date = location.date!
                coordinate = CLLocationCoordinate2DMake(location.latitude, location.longitude)
                placemark = location.placemark
            }
        }
    }
    var descriptionText = ""
    
    var image: UIImage?
    
    var observer: Any!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let location = locationToEdit {
            title = "Edit Location"
            
            if location.hasPhoto {
                if let theImage = location.photoImage {
                    show(image: theImage)
                }
            }
        }
        
        descriptionTextView.text = descriptionText
        categoryLabel.text = categoryName
        latitudeLabel.text = String(format: "%.8f", coordinate.latitude)
        longitudeLabel.text = String(format: "%.8f", coordinate.longitude)
        
        if let placemark = placemark {
            addressLabel.text = string(from:placemark)
        } else {
            addressLabel.text = "No address found"
        }
        
        dateLabel.text = format(date: date)
        
        // Para esconder el teclado
        // El #selector indica que se llame al metodo hideKeyboard al detectar el gesto
        // UITapGestureRecognizer recoge gestos de toques simples en la pantalla
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(hideKeyboard))
        gestureRecognizer.cancelsTouchesInView = false
        tableView.addGestureRecognizer(gestureRecognizer)
        
        listenForBackgroundNotification()
    }
    
    deinit {
        print("*** deinit \(self)")
        // Esto solo es necesario para iOS 9.0 o anteriores. Evita que el notificationCenter siga enviando eventos cuando esta pantalla ya no esta activa
        NotificationCenter.default.removeObserver(observer!)
    }
    
    // MARK:- Actions
    @IBAction func done() {
        let hudView = HudView.hud(inView: navigationController!.view, animated: true)
        
        let location: Location
        if let temp = locationToEdit {
            hudView.text = "Updated"
            location = temp
        } else {
            hudView.text = "Tagged"
            location = Location(context: managedObjectContext)
            location.photoID = nil
        }
        
        location.locationDescription = descriptionTextView.text
        location.category = categoryName
        location.latitude = coordinate.latitude
        location.longitude = coordinate.longitude
        location.date = date
        location.placemark = placemark
        
        // Guardar la imagen
        if let image = image {
            // 1: Si no existe una imagen todavia coge el siguiente id para esta foto
            if !location.hasPhoto {
                location.photoID = Location.nextPhotoID() as NSNumber
            }
            // 2: Comprime la imagen y lo devuelve como un objeto data (masa de datos binarios)
            if let data = image.jpegData(compressionQuality: 0.5) {
                // 3: Guarda el objeto data en la ruta proporcionada
                do {
                    try data.write(to: location.photoURL, options: .atomic)
                } catch {
                    print("Error writing fil: \(error)")
                }
            }
        }
        
        do {
            try managedObjectContext.save()
            // El contenido entre llaves es el contenido del closure de afterDelay en Functions.swift. Se puede poner asi porque el closure es el ultimo parametro de entrada de la funcion afterDelay
            afterDelay(0.6) {
                hudView.hide()
                // Volver a la pantalla anterior
                self.navigationController?.popViewController(animated: true)
            }
        } catch {
            fatalCoreDataError(error)
        }
    }
    
    @IBAction func cancel() {
        print("Cancelar")
        // Volver a la pantalla anterior
        navigationController?.popViewController(animated: true)
    }
    
    // Este tipo de metodos son conocidos como "unwind segue". Es una forma de que la pantalla CategoryPickerViewController vuelva a LocationDetailsViewController sin tener que usar un protocolo delegado.
    // Para hacer la conexion se ha arrastrado desde la celda de CategoryPickerScene hasta el iconito superior que pone Exit
    @IBAction func categoryPickerDidPickCategory(_ segue: UIStoryboardSegue) {
        let controller = segue.source as! CategoryPickerViewController
        categoryName = controller.selectedCategoryName
        categoryLabel.text = categoryName
    }
    
    // MARK:- Helper Methods
    func string(from placemark: CLPlacemark) -> String {
        var text = ""
        
        text.add(text: placemark.subThoroughfare)
        text.add(text: placemark.thoroughfare, separatedBy: " ")
        text.add(text: placemark.locality, separatedBy: ", ")
        text.add(text: placemark.administrativeArea, separatedBy: ", ")
        text.add(text: placemark.postalCode, separatedBy: " ")
        text.add(text: placemark.country, separatedBy: ", ")
        
        return text
    }
    
    func format(date: Date) -> String {
        // Se llama al closure del principio del archivo
        return dateFormatter.string(from: date)
    }
    
    // Permite ocultar el teclado si se ha tocado en cualquier otro sitio que no sea la primera celda
    @objc func hideKeyboard(_ gestureRecognizer: UIGestureRecognizer) {
        // Devuelve un objeto CGPoint con las coordenadas X e Y del punto de la pantalla que se ha tocado, siendo la vista una TableView
        let point = gestureRecognizer.location(in: tableView)
        // Devuelve el indexPath de la tableView para conocer la celda que se ha tocado
        let indexPath = tableView.indexPathForRow(at: point)
        
        // Si se ha tocado dentro de la tableView y la primera seccion o la primera celda entonces no se hace nada
        if indexPath != nil && indexPath!.section == 0 && indexPath!.row == 0 {
            return
        }
        
        // En cualquier otro caso le quitamos el foco al descriptionTextView
        descriptionTextView.resignFirstResponder()
        
        // Nota: En el propio Main.storyboard, en la TableView de esta pantalla, se ha establecido el atributo Keyboard = dismiss on drag, para que se oculte el teclado al hacer scroll en la pantalla
    }
    
    func show(image: UIImage) {
        imageView.image = image
        imageView.isHidden = false
        addPhotoLabel.text = ""
        imageHeight.constant = 260
        tableView.reloadData()
    }
    
    // Para poder controlar cuando la app pasa a segundo plano y eliminar el ImagePicker de la pantalla
    func listenForBackgroundNotification() {
        observer = NotificationCenter.default.addObserver(forName: UIScene.didEnterBackgroundNotification, object: nil, queue: OperationQueue.main) {
            [weak self] _ in
            
            // Explicacion de weak self: Los closures mantienen vivos aquellas variables locales que cogen. En este caso el closure coge "self", es decir, este ViewController, por lo que aun que nos vayamos de esta pantalla en la app, el viewController seguira vivo y consumira memoria. Para evitar esto hay que hacer una lista de captura [weak x], que en este caso sera [weak self], para que cuando no estemos en esta pantalla el closure permita que self muera y por lo tanto el viewController muera
            
            if let weakSelf = self {
                // Si se esta mostrando la alerta de elegir entre camara o biblioteca de fotos, o el ImagePicker, entonces los oculta. Se utiliza "presentedViewController" porque estas dos cosas son como "modals" que estan por encima del ViewController
                if weakSelf.presentedViewController != nil {
                    weakSelf.dismiss(animated: false, completion: nil)
                }
                weakSelf.descriptionTextView.resignFirstResponder()
            }
        }
    }
    
    // MARK:- Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "PickCategory" {
            let controller = segue.destination as! CategoryPickerViewController
            controller.selectedCategoryName = categoryName
        }
    }
    
    // MARK:- Table View Delegates
    // Este metodo se utiliza para limitar el toque a las dos primeras secciones de celdas, es decir, solo las celdas que pertenecen a las dos primeras secciones detectaran que han sido tocadas por el usuario
    override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        if indexPath.section == 0 || indexPath.section == 1 {
            return indexPath
        } else {
            return nil
        }
    }
    
    // Este metodo detecta que celda se ha tocado
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 0 && indexPath.row == 0 {
            // Si se toca la celda de la descripcion entonces se abre el teclado
            descriptionTextView.becomeFirstResponder()
        } else if indexPath.section == 1 && indexPath.row == 0 {
            tableView.deselectRow(at: indexPath, animated: true) // Para evitar que la celda se quede marcada con un color grisaceo
            pickPhoto()
        }
    }
    
    // Este metodo se llama cuando una celda se va a volver visible
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let selection = UIView(frame: CGRect.zero)
        selection.backgroundColor = UIColor(white: 1.0, alpha: 0.3)
        cell.selectedBackgroundView = selection
    }
}

extension LocationDetailsViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    // MARK:- Image Helper Methods
    func takePhotoWithCamera() {
        let imagePicker = MyImagePickerController()
        imagePicker.sourceType = .camera
        imagePicker.delegate = self
        imagePicker.allowsEditing = true
        imagePicker.view.tintColor = view.tintColor
        present(imagePicker, animated: true, completion: nil)
    }
    
    func choosePhotoFromLibrary() {
        let imagePicker = MyImagePickerController()
        imagePicker.sourceType = .photoLibrary
        imagePicker.delegate = self
        imagePicker.allowsEditing = true
        imagePicker.view.tintColor = view.tintColor
        present(imagePicker, animated: true, completion: nil)
    }
    
    func pickPhoto() {
        // Comprueba si el dispositivo tiene camara
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            showPhotoMenu()
        } else {
            choosePhotoFromLibrary()
        }
    }
    
    // Muestra una alerta al usuario para que pueda elegir entre tomar una foto nueva o elegirla de la biblioteca (o cancelar)
    func showPhotoMenu() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        // El "handler" determina la accion al pulsar sobre la opcion
        let actCancel = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alert.addAction(actCancel)
        
        let actPhoto = UIAlertAction(title: "Take Photo", style: .default, handler: {_ in self.takePhotoWithCamera()})
        alert.addAction(actPhoto)
        
        let actLibrary = UIAlertAction(title: "Choose From Library", style: .default, handler: {_ in self.choosePhotoFromLibrary()})
        alert.addAction(actLibrary)
        
        present(alert, animated: true, completion: nil)
    }
    // MARK:- Image Picker Delegates
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        image = info[UIImagePickerController.InfoKey.editedImage] as? UIImage
        
        if let theImage = image {
            show(image: theImage)
        }
        
        dismiss(animated: true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
    
    
}
