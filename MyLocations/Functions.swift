//
//  Functions.swift
//  MyLocations
//
//  Created by Eduardo Martin Lorenzo on 23/02/2021.
//

import Foundation

// Se usa un framework llamado Grand Central Dispatch (GCD) que se usa para manejar tareas asincronas
// @escaping es necesaria para closures que no se ejecutan de inmediato, como esto que es asincrono
func afterDelay(_ seconds: Double, run: @escaping () -> Void) {
    DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: run)
}

// Para obtener la carpeta donde se guardan los datos de SQLite. Devuelve la ruta al directorio de documentos de la app
let applicationDocumentsDirectory: URL = {
    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    
    return paths[0]
}()

// Para mostrar mensajes de error a los usuarios
let CoreDataSaveFailedNotification = Notification.Name("CoreDataSaveFailedNotification")
func fatalCoreDataError(_ error: Error) {
    print("*** Fatal error: \(error)")
    NotificationCenter.default.post(name: CoreDataSaveFailedNotification, object: nil)
}

