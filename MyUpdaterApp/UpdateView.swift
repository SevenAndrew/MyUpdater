//
//  UpdateView.swift
//  MyUpdaterApp
//
//  Created by Andreas Sauerwein on 21.12.24.
//

import Cocoa

class UpdateView {
    func showResult(_ message: String) {
        print(message)
    }

    func promptForPassword() async -> String? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Passwort erforderlich"
                alert.informativeText = "Bitte gib dein Administrator-Passwort ein."
                alert.alertStyle = .informational
                alert.addButton(withTitle: "OK")
                alert.addButton(withTitle: "Abbrechen")

                let passwordField = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
                alert.accessoryView = passwordField

                if alert.runModal() == .alertFirstButtonReturn {
                    continuation.resume(returning: passwordField.stringValue)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
