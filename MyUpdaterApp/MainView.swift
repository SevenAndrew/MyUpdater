//
//  MainView.swift
//  MyUpdaterApp
//
//  Created by Andreas Sauerwein on 21.12.24.
//

import Foundation
import SwiftUI

struct LogEntry: Identifiable, Hashable {
    let id = UUID()
    let message: String
    let timestamp: Date
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: LogEntry, rhs: LogEntry) -> Bool {
        lhs.id == rhs.id
    }
}

struct MainView: View {
    @State private var isUpdating = false
    @State private var logMessages: [LogEntry] = []
    @State private var updateMessage: String = ""
    @State private var showUpdateAlert = false
    @State private var progress: Double = 0.0
    @State private var currentStep: String = "Warten auf Start..."
    private let totalSteps: Double = 3.0
    private let controller = UpdateController()
    private let logger = LogManager.shared
    @State private var prerequisites: (success: Bool, errors: [String]) = (true, [])

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Update Manager")
                    .font(.largeTitle)
                    .bold()
                
                Spacer()
                
                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Beenden")
            }
            .padding(.bottom, 10)

            VStack(spacing: 10) {
                ProgressView(value: progress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: Color.blue))
                    .animation(.easeInOut, value: progress)

                Text("\(Int(progress * 100))% abgeschlossen")
                    .font(.headline)
                    .foregroundColor(.gray)

                Text(currentStep)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal)

            if !prerequisites.success {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Fehlende Voraussetzungen:")
                        .font(.headline)
                        .foregroundColor(.red)
                    
                    ForEach(prerequisites.errors, id: \.self) { error in
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
                .padding()
                .background(Color(white: 0.95))
                .cornerRadius(8)
                .padding(.horizontal)
            }

            Button(action: startUpdates) {
                Text("Updates starten")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(isUpdating ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .disabled(isUpdating || !prerequisites.success)
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 8) {
                Text("Logs:")
                    .font(.headline)
                    .padding(.horizontal)

                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(logMessages) { log in
                            Text(log.message)
                                .font(.system(.body, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .foregroundColor(.white)
                        }
                    }
                    .padding()
                }
                .background(Color(white: 0.2))
                .cornerRadius(8)
            }
            .frame(maxHeight: .infinity)

            Button(action: openLogFile) {
                Text("Log-Datei öffnen")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding(.horizontal)
        }
        .padding()
        .frame(minWidth: 600, minHeight: 400, maxHeight: .infinity)
        .alert(isPresented: $showUpdateAlert) {
            Alert(title: Text("Update abgeschlossen"),
                  message: Text(updateMessage),
                  dismissButton: .default(Text("OK")))
        }
        .onAppear {
            checkPrerequisites()
        }
    }

    private func checkPrerequisites() {
        prerequisites = controller.checkPrerequisites()
    }

    private func startUpdates() {
        Task { @MainActor in
            prerequisites = controller.checkPrerequisites()
            guard prerequisites.success else {
                return
            }
            
            isUpdating = true
            updateMessage = ""
            progress = 0.0
            currentStep = "Starte Updates..."

            controller.performUpdates { success, errors in
                self.progress = 1.0
                self.currentStep = success ? "Alle Updates erfolgreich abgeschlossen." : "Fehler während der Updates."
                if success {
                    self.updateMessage = "Alle Updates wurden erfolgreich abgeschlossen."
                } else {
                    self.updateMessage = "Fehler aufgetreten:\n" + errors.joined(separator: "\n")
                }
                self.refreshLogs()
                self.showUpdateAlert = true
                self.isUpdating = false
            } progressHandler: { step, stepDescription in
                self.progress = Double(step) / self.totalSteps
                self.currentStep = stepDescription
            }
        }
    }

    private func refreshLogs() {
        Task { @MainActor in
            if let logContent = try? String(contentsOfFile: logger.getLogFilePath(), encoding: .utf8) {
                logMessages = logContent
                    .components(separatedBy: "\n")
                    .filter { !$0.isEmpty }
                    .map { LogEntry(message: $0, timestamp: Date()) }
            }
        }
    }

    private func openLogFile() {
        Task { @MainActor in
            NSWorkspace.shared.open(URL(fileURLWithPath: logger.getLogFilePath()))
        }
    }
}
