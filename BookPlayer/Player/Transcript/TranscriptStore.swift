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
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try String(contentsOf: url, encoding: .utf8)
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
        let folder = DataManager.getDocumentsFolderURL().appendingPathComponent(transcriptsFolderName, isDirectory: true)
        return folder.appendingPathComponent("\(sanitized).lrc")
    }

    private func sanitizeFileName(_ name: String) -> String {
        let replaced = name
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
        return replaced
    }
}
