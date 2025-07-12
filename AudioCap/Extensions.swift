//
//  Extensions.swift
//  AudioCap
//
//  Created by Ankit Maloo on 6/20/25.
//


import Foundation

extension URL {
    /// A shared, safe URL for the application's support directory.
    static var applicationSupport: URL? {
        do {
            let appSupport = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true // Ensure the directory is created if it doesn't exist
            )
            print("Application Support Directory: \(appSupport.path)")
            
            let subdir = appSupport.appending(path: "AudioCap", directoryHint: .isDirectory)
            print("Subdirectory: \(subdir.path)")
            
            // We need to manually create the subdirectory if it's not there
            if !FileManager.default.fileExists(atPath: subdir.path) {
                print("Creating subdirectory: \(subdir.path)")
                try FileManager.default.createDirectory(at: subdir, withIntermediateDirectories: true)
                print("Subdirectory created successfully.")
            } else {
                print("Subdirectory already exists: \(subdir.path)")
            }
            
            return subdir
            
        } catch {
            // If anything goes wrong, log the error and return nil
            print("Failed to get or create application support directory: \(error)")
            return nil
        }
    }
}