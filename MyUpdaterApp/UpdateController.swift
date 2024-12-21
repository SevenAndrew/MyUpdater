//
//  UpdateController.swift
//  MyUpdaterApp
//
//  Created by Andreas Sauerwein on 21.12.24.
//

import Foundation

class UpdateController {
    private let model = UpdateModel()
    private let view = UpdateView()
    private let logger = LogManager.shared

    func checkPrerequisites() -> (success: Bool, errors: [String]) {
        var errors: [String] = []
        
        // Check if Homebrew is installed
        if !FileManager.default.fileExists(atPath: "/opt/homebrew/bin/brew") &&
           !FileManager.default.fileExists(atPath: "/usr/local/bin/brew") {
            errors.append("Homebrew ist nicht installiert.\nInstallation: https://brew.sh")
        }
        
        // Check if Conda is installed
        let condaPaths = [
            "\(NSHomeDirectory())/opt/anaconda3/bin/conda",
            "\(NSHomeDirectory())/opt/miniconda3/bin/conda",
            "/opt/anaconda3/bin/conda",
            "/opt/miniconda3/bin/conda",
            "/usr/local/anaconda3/bin/conda",
            "/usr/local/miniconda3/bin/conda",
            "\(NSHomeDirectory())/anaconda3/bin/conda",
            "\(NSHomeDirectory())/miniconda3/bin/conda",
            // Homebrew Installationspfade
            "/opt/homebrew/anaconda3/bin/conda",
            "/opt/homebrew/miniconda3/bin/conda",
            "/usr/local/Caskroom/miniconda/base/bin/conda",
            "/usr/local/Caskroom/anaconda/base/bin/conda"
        ]
        
        // Zusätzlich PATH durchsuchen
        let condaInPath = Process.run(path: "/bin/zsh", arguments: ["-c", "which conda"]) { process in
            return process.terminationStatus == 0
        }
        
        if !condaPaths.contains(where: { FileManager.default.fileExists(atPath: $0) }) && !condaInPath {
            errors.append("Conda ist nicht installiert.\nInstallation Miniconda: https://docs.conda.io/projects/miniconda/en/latest/\nInstallation Anaconda: https://www.anaconda.com/download")
        }
        
        // Check if mas-cli is installed
        if !FileManager.default.fileExists(atPath: "/opt/homebrew/bin/mas") &&
           !FileManager.default.fileExists(atPath: "/usr/local/bin/mas") {
            errors.append("mas-cli ist nicht installiert.\nInstallation mit Terminal-Befehl: brew install mas")
        }
        
        return (errors.isEmpty, errors)
    }
    
    func performUpdates(completion: @escaping (Bool, [String]) -> Void, progressHandler: @escaping (Int, String) -> Void) {
        // Check prerequisites first
        let prerequisites = checkPrerequisites()
        if !prerequisites.success {
            completion(false, prerequisites.errors)
            return
        }
        
        Task {
            var errors: [String] = []
            var success = true
            let steps = [
                (step: 1, description: "Homebrew Update & Upgrade"),
                (step: 2, description: "Conda Update & Upgrade"),
                (step: 3, description: "App Store Updates")
            ]

            if let password = await view.promptForPassword() {
                let group = DispatchGroup()
                
                for (step, description) in steps {
                    group.enter()
                    progressHandler(step, description)
                    
                    switch step {
                    case 1:
                        self.model.updateAndUpgradeBrew(password: password) { result in
                            if result.contains("Error") || result.contains("failed") {
                                success = false
                                errors.append("Homebrew: \(result)")
                            }
                            self.logger.writeLog("Homebrew Update & Upgrade:\n\(result)")
                            group.leave()
                        }
                    case 2:
                        self.model.updateAndUpgradeConda { result in
                            if result.contains("Error") || result.contains("failed") {
                                success = false
                                errors.append("Conda: \(result)")
                            }
                            self.logger.writeLog("Conda Update & Upgrade:\n\(result)")
                            group.leave()
                        }
                    case 3:
                        self.model.updateAppStore { result in
                            if result.contains("Error") || result.contains("failed") {
                                success = false
                                errors.append("App Store: \(result)")
                            }
                            self.logger.writeLog("App Store Update:\n\(result)")
                            group.leave()
                        }
                    default:
                        group.leave()
                    }
                }
                
                group.notify(queue: .main) {
                    completion(success, errors)
                }
            } else {
                await MainActor.run {
                    self.logger.writeLog("Benutzer hat die Updates abgebrochen.")
                    completion(false, ["Benutzer hat die Updates abgebrochen."])
                }
            }
        }
    }
}

// Hilfsfunktion zum Ausführen von Shell-Befehlen
extension Process {
    static func run(path: String, arguments: [String], handler: (Process) -> Bool) -> Bool {
        let process = Process()
        process.launchPath = path
        process.arguments = arguments
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            return handler(process)
        } catch {
            return false
        }
    }
}
