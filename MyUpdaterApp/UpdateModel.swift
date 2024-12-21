//
//  UpdateModel.swift
//  MyUpdaterApp
//
//  Created by Andreas Sauerwein on 21.12.24.
//

import Foundation

class UpdateModel {
    private func getBrewPath() -> String {
        if FileManager.default.fileExists(atPath: "/opt/homebrew/bin/brew") {
            return "/opt/homebrew/bin/brew"
        }
        return "/usr/local/bin/brew"
    }
    
    private func getCondaPath() -> String? {
        // First try to get conda from PATH
        let process = Process()
        process.launchPath = "/bin/zsh"
        process.arguments = ["-c", "which conda"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !path.isEmpty {
                return path
            }
        } catch {
            print("Error finding conda: \(error)")
        }
        
        // Fallback to known paths
        let paths = [
            "\(NSHomeDirectory())/opt/anaconda3/bin/conda",
            "\(NSHomeDirectory())/opt/miniconda3/bin/conda",
            "/opt/anaconda3/bin/conda",
            "/opt/miniconda3/bin/conda",
            "/usr/local/anaconda3/bin/conda",
            "/usr/local/miniconda3/bin/conda",
            "\(NSHomeDirectory())/anaconda3/bin/conda",
            "\(NSHomeDirectory())/miniconda3/bin/conda",
            "/opt/homebrew/anaconda3/bin/conda",
            "/opt/homebrew/miniconda3/bin/conda",
            "/usr/local/Caskroom/miniconda/base/bin/conda",
            "/usr/local/Caskroom/anaconda/base/bin/conda"
        ]
        
        return paths.first(where: { FileManager.default.fileExists(atPath: $0) })
    }
    
    private func getMasPath() -> String {
        if FileManager.default.fileExists(atPath: "/opt/homebrew/bin/mas") {
            return "/opt/homebrew/bin/mas"
        }
        return "/usr/local/bin/mas"
    }
    
    private func executeCommand(launchPath: String, arguments: [String], environment: [String: String]? = nil, onOutput: @escaping (String) -> Void) {
        let process = Process()
        process.launchPath = launchPath
        process.arguments = arguments
        if let env = environment {
            process.environment = env
        }

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        // Setze einen File Handle Observer für Echtzeit-Output
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.count > 0 {
                if let output = String(data: data, encoding: .utf8) {
                    DispatchQueue.main.async {
                        onOutput(output)
                    }
                }
            }
        }

        do {
            try process.run()
            process.waitUntilExit()
            
            // Cleanup
            pipe.fileHandleForReading.readabilityHandler = nil
        } catch {
            onOutput("Fehler: \(error.localizedDescription)")
        }
    }

    func updateAndUpgradeBrew(password: String, completion: @escaping (String) -> Void) {
        let brewPath = getBrewPath()
        let script = "\(brewPath) update && \(brewPath) upgrade"
        
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        
        executeCommand(launchPath: "/bin/zsh", arguments: ["-c", script], environment: environment) { output in
            LogManager.shared.writeLog(output)
        }
        completion("Homebrew Update abgeschlossen")
    }

    func updateAndUpgradeConda(completion: @escaping (String) -> Void) {
        guard let condaPath = getCondaPath() else {
            completion("Conda nicht gefunden")
            return
        }
        
        // Erstelle ein temporäres Shell-Skript
        let tempScript = """
        #!/bin/zsh
        source ~/.zshrc
        source "$(dirname "$(dirname "\(condaPath)")")/etc/profile.d/conda.sh"
        conda activate base
        conda update --all -y
        """
        
        let tempScriptPath = NSTemporaryDirectory() + "conda_update.sh"
        do {
            try tempScript.write(toFile: tempScriptPath, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tempScriptPath)
            
            let process = Process()
            process.launchPath = "/bin/zsh"
            process.arguments = [tempScriptPath]
            
            // Setze die Umgebungsvariablen
            var environment = ProcessInfo.processInfo.environment
            // Verwende URL für Pfad-Manipulation
            let condaURL = URL(fileURLWithPath: condaPath)
            let condaBasePath = condaURL.deletingLastPathComponent().path
            let condaRootPath = condaURL.deletingLastPathComponent().deletingLastPathComponent().path
            
            environment["PATH"] = "\(condaBasePath):/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
            environment["CONDA_AUTO_ACTIVATE_BASE"] = "true"
            environment["CONDA_PREFIX"] = condaRootPath
            process.environment = environment

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            try process.run()
            process.waitUntilExit()
            
            let output = pipe.fileHandleForReading.readDataToEndOfFile()
            let result = String(data: output, encoding: .utf8) ?? "Keine Ausgabe"
            
            // Lösche das temporäre Skript
            try? FileManager.default.removeItem(atPath: tempScriptPath)
            
            completion(result)
        } catch {
            completion("Fehler beim Ausführen von Conda: \(error.localizedDescription)")
        }
    }

    func updateAppStore(completion: @escaping (String) -> Void) {
        let masPath = getMasPath()
        let script = "\(masPath) upgrade"
        
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        
        executeCommand(launchPath: "/bin/zsh", arguments: ["-c", script], environment: environment) { output in
            LogManager.shared.writeLog(output)
        }
        completion("App Store Update abgeschlossen")
    }
}
