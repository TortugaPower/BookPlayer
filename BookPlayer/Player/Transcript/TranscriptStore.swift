//
//  TranscriptStore.swift
//  BookPlayer
//
//  Created by Codex on 3/2/26.
//

import BookPlayerKit
import Foundation

struct TranscriptStore {
    private let transcriptsFolderName = "Transcripts"

    func loadTranscript(for relativePath: String) throws -> String? {
        let url = transcriptURL(for: relativePath)
        if FileManager.default.fileExists(atPath: url.path) {
            return try String(contentsOf: url, encoding: .utf8)
        }

        let legacyURL = legacyTranscriptURL(for: relativePath)
        guard FileManager.default.fileExists(atPath: legacyURL.path) else { return nil }

        let contents = try String(contentsOf: legacyURL, encoding: .utf8)
        try saveTranscript(contents, for: relativePath)
        try? FileManager.default.removeItem(at: legacyURL)
        removeLegacyFolderIfEmpty()
        return contents
    }

    func saveTranscript(_ contents: String, for relativePath: String) throws {
        let url = transcriptURL(for: relativePath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )
        try contents.write(to: url, atomically: true, encoding: .utf8)
        url.disableFileProtection()
    }

    private func transcriptURL(for relativePath: String) -> URL {
        let sanitized = sanitizeFileName(relativePath)
        let folder = applicationSupportFolder().appendingPathComponent(transcriptsFolderName, isDirectory: true)
        return folder.appendingPathComponent("\(sanitized).lrc")
    }

    private func legacyTranscriptURL(for relativePath: String) -> URL {
        let sanitized = sanitizeFileName(relativePath)
        let folder = DataManager.getDocumentsFolderURL().appendingPathComponent(transcriptsFolderName, isDirectory: true)
        return folder.appendingPathComponent("\(sanitized).lrc")
    }

    private func applicationSupportFolder() -> URL {
        let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        return (urls.first ?? FileManager.default.temporaryDirectory)
            .appendingPathComponent("BookPlayer", isDirectory: true)
    }

    private func removeLegacyFolderIfEmpty() {
        let legacyFolder = DataManager.getDocumentsFolderURL().appendingPathComponent(transcriptsFolderName, isDirectory: true)
        guard let contents = try? FileManager.default.contentsOfDirectory(at: legacyFolder, includingPropertiesForKeys: nil), contents.isEmpty else { return }
        try? FileManager.default.removeItem(at: legacyFolder)
    }

    private func sanitizeFileName(_ name: String) -> String {
        let replaced = name
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
        return replaced
    }
}
