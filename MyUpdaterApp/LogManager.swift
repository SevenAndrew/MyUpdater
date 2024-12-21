//
//  LogManager.swift
//  MyUpdaterApp
//
//  Created by Andreas Sauerwein on 21.12.24.
//

import Foundation

class LogManager {
    static let shared = LogManager()
    private let logFileURL: URL

    private init() {
        let fileManager = FileManager.default
        let logDirectory = fileManager.homeDirectoryForCurrentUser.appendingPathComponent("MyUpdaterLogs")
        if !fileManager.fileExists(atPath: logDirectory.path) {
            try? fileManager.createDirectory(at: logDirectory, withIntermediateDirectories: true)
        }
        logFileURL = logDirectory.appendingPathComponent("update_log.txt")
    }

    func writeLog(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
        let logEntry = "[\(timestamp)] \(message)\n"
        if let data = logEntry.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFileURL.path) {
                if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: logFileURL)
            }
        }
    }

    func getLogFilePath() -> String {
        return logFileURL.path
    }
}
