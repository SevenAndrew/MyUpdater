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
    @State private var currentLogMessage: String = ""

    private func setupLogObserver() {
        LogManager.shared.onNewLogEntry = { logEntry in
            self.currentLogMessage = logEntry
            self.refreshLogs()
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Update Manager")
                    .font(.title)
                    .bold()
                
                Spacer()
                
                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Beenden")
            }
            .padding(.bottom, 4)

            VStack(spacing: 8) {
                ProgressView(value: progress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .animation(.easeInOut, value: progress)
                
                HStack {
                    Text("\(Int(progress * 100))%")
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Text(currentStep)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            
            if !prerequisites.success {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Fehlende Voraussetzungen:")
                            .font(.subheadline.bold())
                            .foregroundColor(.red)
                        
                        ForEach(prerequisites.errors, id: \.self) { error in
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 100)
                .padding(8)
                .background(Color(.windowBackgroundColor).opacity(0.5))
                .cornerRadius(8)
            }

            VStack(spacing: 8) {
                if !currentLogMessage.isEmpty {
                    Text(currentLogMessage)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.green)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(8)
                }
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(logMessages.reversed()) { log in
                            Text(log.message)
                                .font(.system(.caption, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .foregroundColor(.white)
                        }
                    }
                    .padding(8)
                }
                .background(Color(white: 0.15))
                .cornerRadius(8)
            }
            .frame(maxHeight: .infinity)

            HStack(spacing: 12) {
                Button(action: startUpdates) {
                    HStack {
                        Image(systemName: "arrow.clockwise.circle.fill")
                        Text("Updates starten")
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.borderedProminent)
                .disabled(isUpdating || !prerequisites.success)
                
                Button(action: openLogFile) {
                    HStack {
                        Image(systemName: "doc.text.fill")
                        Text("Log öffnen")
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(minWidth: 500, minHeight: 400)
        .alert(isPresented: $showUpdateAlert) {
            Alert(title: Text("Update abgeschlossen"),
                  message: Text(updateMessage),
                  dismissButton: .default(Text("OK")))
        }
        .onAppear {
            checkPrerequisites()
            setupLogObserver()
            refreshLogs()
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
                let logs = logContent.components(separatedBy: "\n")
                    .filter { !$0.isEmpty }
                    .map { LogEntry(message: $0, timestamp: Date()) }
                
                logMessages = logs
                if let lastLog = logs.first {
                    currentLogMessage = lastLog.message
                }
            }
        }
    }

    private func openLogFile() {
        Task { @MainActor in
            NSWorkspace.shared.open(URL(fileURLWithPath: logger.getLogFilePath()))
        }
    }
}
