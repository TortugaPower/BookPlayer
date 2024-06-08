// Generated using Sourcery 2.0.2 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT

import Foundation
#if os(iOS) || os(tvOS) || os(watchOS)
import UIKit
import AVFoundation
#elseif os(OSX)
import AppKit
#endif

import Combine
import BookPlayerKit
@testable import BookPlayer
class KeychainServiceProtocolMock: KeychainServiceProtocol {
    //MARK: - setAccessToken

    var setAccessTokenThrowableError: Error?
    var setAccessTokenCallsCount = 0
    var setAccessTokenCalled: Bool {
        return setAccessTokenCallsCount > 0
    }
    var setAccessTokenReceivedToken: String?
    var setAccessTokenReceivedInvocations: [String] = []
    var setAccessTokenClosure: ((String) throws -> Void)?
    func setAccessToken(_ token: String) throws {
        if let error = setAccessTokenThrowableError {
            throw error
        }
        setAccessTokenCallsCount += 1
        setAccessTokenReceivedToken = token
        setAccessTokenReceivedInvocations.append(token)
        try setAccessTokenClosure?(token)
    }
    //MARK: - getAccessToken

    var getAccessTokenThrowableError: Error?
    var getAccessTokenCallsCount = 0
    var getAccessTokenCalled: Bool {
        return getAccessTokenCallsCount > 0
    }
    var getAccessTokenReturnValue: String?
    var getAccessTokenClosure: (() throws -> String?)?
    func getAccessToken() throws -> String? {
        if let error = getAccessTokenThrowableError {
            throw error
        }
        getAccessTokenCallsCount += 1
        if let getAccessTokenClosure = getAccessTokenClosure {
            return try getAccessTokenClosure()
        } else {
            return getAccessTokenReturnValue
        }
    }
    //MARK: - removeAccessToken

    var removeAccessTokenThrowableError: Error?
    var removeAccessTokenCallsCount = 0
    var removeAccessTokenCalled: Bool {
        return removeAccessTokenCallsCount > 0
    }
    var removeAccessTokenClosure: (() throws -> Void)?
    func removeAccessToken() throws {
        if let error = removeAccessTokenThrowableError {
            throw error
        }
        removeAccessTokenCallsCount += 1
        try removeAccessTokenClosure?()
    }
}
class LibraryServiceProtocolMock: LibraryServiceProtocol {
    var metadataUpdatePublisher: AnyPublisher<[String: Any], Never> {
        get { return underlyingMetadataUpdatePublisher }
        set(value) { underlyingMetadataUpdatePublisher = value }
    }
    var underlyingMetadataUpdatePublisher: AnyPublisher<[String: Any], Never>!
    var progressUpdatePublisher: AnyPublisher<[String: Any], Never> {
        get { return underlyingProgressUpdatePublisher }
        set(value) { underlyingProgressUpdatePublisher = value }
    }
    var underlyingProgressUpdatePublisher: AnyPublisher<[String: Any], Never>!
    //MARK: - getLibrary

    var getLibraryCallsCount = 0
    var getLibraryCalled: Bool {
        return getLibraryCallsCount > 0
    }
    var getLibraryReturnValue: Library!
    var getLibraryClosure: (() -> Library)?
    func getLibrary() -> Library {
        getLibraryCallsCount += 1
        if let getLibraryClosure = getLibraryClosure {
            return getLibraryClosure()
        } else {
            return getLibraryReturnValue
        }
    }
    //MARK: - getLibraryReference

    var getLibraryReferenceCallsCount = 0
    var getLibraryReferenceCalled: Bool {
        return getLibraryReferenceCallsCount > 0
    }
    var getLibraryReferenceReturnValue: Library!
    var getLibraryReferenceClosure: (() -> Library)?
    func getLibraryReference() -> Library {
        getLibraryReferenceCallsCount += 1
        if let getLibraryReferenceClosure = getLibraryReferenceClosure {
            return getLibraryReferenceClosure()
        } else {
            return getLibraryReferenceReturnValue
        }
    }
    //MARK: - getLibraryLastItem

    var getLibraryLastItemCallsCount = 0
    var getLibraryLastItemCalled: Bool {
        return getLibraryLastItemCallsCount > 0
    }
    var getLibraryLastItemReturnValue: SimpleLibraryItem?
    var getLibraryLastItemClosure: (() -> SimpleLibraryItem?)?
    func getLibraryLastItem() -> SimpleLibraryItem? {
        getLibraryLastItemCallsCount += 1
        if let getLibraryLastItemClosure = getLibraryLastItemClosure {
            return getLibraryLastItemClosure()
        } else {
            return getLibraryLastItemReturnValue
        }
    }
    //MARK: - getLibraryCurrentTheme

    var getLibraryCurrentThemeCallsCount = 0
    var getLibraryCurrentThemeCalled: Bool {
        return getLibraryCurrentThemeCallsCount > 0
    }
    var getLibraryCurrentThemeReturnValue: SimpleTheme?
    var getLibraryCurrentThemeClosure: (() -> SimpleTheme?)?
    func getLibraryCurrentTheme() -> SimpleTheme? {
        getLibraryCurrentThemeCallsCount += 1
        if let getLibraryCurrentThemeClosure = getLibraryCurrentThemeClosure {
            return getLibraryCurrentThemeClosure()
        } else {
            return getLibraryCurrentThemeReturnValue
        }
    }
    //MARK: - setLibraryTheme

    var setLibraryThemeWithCallsCount = 0
    var setLibraryThemeWithCalled: Bool {
        return setLibraryThemeWithCallsCount > 0
    }
    var setLibraryThemeWithReceivedSimpleTheme: SimpleTheme?
    var setLibraryThemeWithReceivedInvocations: [SimpleTheme] = []
    var setLibraryThemeWithClosure: ((SimpleTheme) -> Void)?
    func setLibraryTheme(with simpleTheme: SimpleTheme) {
        setLibraryThemeWithCallsCount += 1
        setLibraryThemeWithReceivedSimpleTheme = simpleTheme
        setLibraryThemeWithReceivedInvocations.append(simpleTheme)
        setLibraryThemeWithClosure?(simpleTheme)
    }
    //MARK: - setLibraryLastBook

    var setLibraryLastBookWithCallsCount = 0
    var setLibraryLastBookWithCalled: Bool {
        return setLibraryLastBookWithCallsCount > 0
    }
    var setLibraryLastBookWithReceivedRelativePath: String?
    var setLibraryLastBookWithReceivedInvocations: [String?] = []
    var setLibraryLastBookWithClosure: ((String?) -> Void)?
    func setLibraryLastBook(with relativePath: String?) {
        setLibraryLastBookWithCallsCount += 1
        setLibraryLastBookWithReceivedRelativePath = relativePath
        setLibraryLastBookWithReceivedInvocations.append(relativePath)
        setLibraryLastBookWithClosure?(relativePath)
    }
    //MARK: - insertItems

    var insertItemsFromCallsCount = 0
    var insertItemsFromCalled: Bool {
        return insertItemsFromCallsCount > 0
    }
    var insertItemsFromReceivedFiles: [URL]?
    var insertItemsFromReceivedInvocations: [[URL]] = []
    var insertItemsFromReturnValue: [SimpleLibraryItem]!
    var insertItemsFromClosure: (([URL]) -> [SimpleLibraryItem])?
    func insertItems(from files: [URL]) -> [SimpleLibraryItem] {
        insertItemsFromCallsCount += 1
        insertItemsFromReceivedFiles = files
        insertItemsFromReceivedInvocations.append(files)
        if let insertItemsFromClosure = insertItemsFromClosure {
            return insertItemsFromClosure(files)
        } else {
            return insertItemsFromReturnValue
        }
    }
    //MARK: - moveItems

    var moveItemsInsideThrowableError: Error?
    var moveItemsInsideCallsCount = 0
    var moveItemsInsideCalled: Bool {
        return moveItemsInsideCallsCount > 0
    }
    var moveItemsInsideReceivedArguments: (items: [String], relativePath: String?)?
    var moveItemsInsideReceivedInvocations: [(items: [String], relativePath: String?)] = []
    var moveItemsInsideClosure: (([String], String?) throws -> Void)?
    func moveItems(_ items: [String], inside relativePath: String?) throws {
        if let error = moveItemsInsideThrowableError {
            throw error
        }
        moveItemsInsideCallsCount += 1
        moveItemsInsideReceivedArguments = (items: items, relativePath: relativePath)
        moveItemsInsideReceivedInvocations.append((items: items, relativePath: relativePath))
        try moveItemsInsideClosure?(items, relativePath)
    }
    //MARK: - delete

    var deleteModeThrowableError: Error?
    var deleteModeCallsCount = 0
    var deleteModeCalled: Bool {
        return deleteModeCallsCount > 0
    }
    var deleteModeReceivedArguments: (items: [SimpleLibraryItem], mode: DeleteMode)?
    var deleteModeReceivedInvocations: [(items: [SimpleLibraryItem], mode: DeleteMode)] = []
    var deleteModeClosure: (([SimpleLibraryItem], DeleteMode) throws -> Void)?
    func delete(_ items: [SimpleLibraryItem], mode: DeleteMode) throws {
        if let error = deleteModeThrowableError {
            throw error
        }
        deleteModeCallsCount += 1
        deleteModeReceivedArguments = (items: items, mode: mode)
        deleteModeReceivedInvocations.append((items: items, mode: mode))
        try deleteModeClosure?(items, mode)
    }
    //MARK: - fetchContents

    var fetchContentsAtLimitOffsetCallsCount = 0
    var fetchContentsAtLimitOffsetCalled: Bool {
        return fetchContentsAtLimitOffsetCallsCount > 0
    }
    var fetchContentsAtLimitOffsetReceivedArguments: (relativePath: String?, limit: Int?, offset: Int?)?
    var fetchContentsAtLimitOffsetReceivedInvocations: [(relativePath: String?, limit: Int?, offset: Int?)] = []
    var fetchContentsAtLimitOffsetReturnValue: [SimpleLibraryItem]?
    var fetchContentsAtLimitOffsetClosure: ((String?, Int?, Int?) -> [SimpleLibraryItem]?)?
    func fetchContents(at relativePath: String?, limit: Int?, offset: Int?) -> [SimpleLibraryItem]? {
        fetchContentsAtLimitOffsetCallsCount += 1
        fetchContentsAtLimitOffsetReceivedArguments = (relativePath: relativePath, limit: limit, offset: offset)
        fetchContentsAtLimitOffsetReceivedInvocations.append((relativePath: relativePath, limit: limit, offset: offset))
        if let fetchContentsAtLimitOffsetClosure = fetchContentsAtLimitOffsetClosure {
            return fetchContentsAtLimitOffsetClosure(relativePath, limit, offset)
        } else {
            return fetchContentsAtLimitOffsetReturnValue
        }
    }
    //MARK: - fetchIdentifiers

    var fetchIdentifiersCallsCount = 0
    var fetchIdentifiersCalled: Bool {
        return fetchIdentifiersCallsCount > 0
    }
    var fetchIdentifiersReturnValue: [String]!
    var fetchIdentifiersClosure: (() -> [String])?
    func fetchIdentifiers() -> [String] {
        fetchIdentifiersCallsCount += 1
        if let fetchIdentifiersClosure = fetchIdentifiersClosure {
            return fetchIdentifiersClosure()
        } else {
            return fetchIdentifiersReturnValue
        }
    }
    //MARK: - getMaxItemsCount

    var getMaxItemsCountAtCallsCount = 0
    var getMaxItemsCountAtCalled: Bool {
        return getMaxItemsCountAtCallsCount > 0
    }
    var getMaxItemsCountAtReceivedRelativePath: String?
    var getMaxItemsCountAtReceivedInvocations: [String?] = []
    var getMaxItemsCountAtReturnValue: Int!
    var getMaxItemsCountAtClosure: ((String?) -> Int)?
    func getMaxItemsCount(at relativePath: String?) -> Int {
        getMaxItemsCountAtCallsCount += 1
        getMaxItemsCountAtReceivedRelativePath = relativePath
        getMaxItemsCountAtReceivedInvocations.append(relativePath)
        if let getMaxItemsCountAtClosure = getMaxItemsCountAtClosure {
            return getMaxItemsCountAtClosure(relativePath)
        } else {
            return getMaxItemsCountAtReturnValue
        }
    }
    //MARK: - getLastPlayedItems

    var getLastPlayedItemsLimitCallsCount = 0
    var getLastPlayedItemsLimitCalled: Bool {
        return getLastPlayedItemsLimitCallsCount > 0
    }
    var getLastPlayedItemsLimitReceivedLimit: Int?
    var getLastPlayedItemsLimitReceivedInvocations: [Int?] = []
    var getLastPlayedItemsLimitReturnValue: [SimpleLibraryItem]?
    var getLastPlayedItemsLimitClosure: ((Int?) -> [SimpleLibraryItem]?)?
    func getLastPlayedItems(limit: Int?) -> [SimpleLibraryItem]? {
        getLastPlayedItemsLimitCallsCount += 1
        getLastPlayedItemsLimitReceivedLimit = limit
        getLastPlayedItemsLimitReceivedInvocations.append(limit)
        if let getLastPlayedItemsLimitClosure = getLastPlayedItemsLimitClosure {
            return getLastPlayedItemsLimitClosure(limit)
        } else {
            return getLastPlayedItemsLimitReturnValue
        }
    }
    //MARK: - findBooks

    var findBooksContainingCallsCount = 0
    var findBooksContainingCalled: Bool {
        return findBooksContainingCallsCount > 0
    }
    var findBooksContainingReceivedFileURL: URL?
    var findBooksContainingReceivedInvocations: [URL] = []
    var findBooksContainingReturnValue: [Book]?
    var findBooksContainingClosure: ((URL) -> [Book]?)?
    func findBooks(containing fileURL: URL) -> [Book]? {
        findBooksContainingCallsCount += 1
        findBooksContainingReceivedFileURL = fileURL
        findBooksContainingReceivedInvocations.append(fileURL)
        if let findBooksContainingClosure = findBooksContainingClosure {
            return findBooksContainingClosure(fileURL)
        } else {
            return findBooksContainingReturnValue
        }
    }
    //MARK: - getSimpleItem

    var getSimpleItemWithCallsCount = 0
    var getSimpleItemWithCalled: Bool {
        return getSimpleItemWithCallsCount > 0
    }
    var getSimpleItemWithReceivedRelativePath: String?
    var getSimpleItemWithReceivedInvocations: [String] = []
    var getSimpleItemWithReturnValue: SimpleLibraryItem?
    var getSimpleItemWithClosure: ((String) -> SimpleLibraryItem?)?
    func getSimpleItem(with relativePath: String) -> SimpleLibraryItem? {
        getSimpleItemWithCallsCount += 1
        getSimpleItemWithReceivedRelativePath = relativePath
        getSimpleItemWithReceivedInvocations.append(relativePath)
        if let getSimpleItemWithClosure = getSimpleItemWithClosure {
            return getSimpleItemWithClosure(relativePath)
        } else {
            return getSimpleItemWithReturnValue
        }
    }
    //MARK: - getItems

    var getItemsNotInParentFolderCallsCount = 0
    var getItemsNotInParentFolderCalled: Bool {
        return getItemsNotInParentFolderCallsCount > 0
    }
    var getItemsNotInParentFolderReceivedArguments: (relativePaths: [String], parentFolder: String?)?
    var getItemsNotInParentFolderReceivedInvocations: [(relativePaths: [String], parentFolder: String?)] = []
    var getItemsNotInParentFolderReturnValue: [SimpleLibraryItem]?
    var getItemsNotInParentFolderClosure: (([String], String?) -> [SimpleLibraryItem]?)?
    func getItems(notIn relativePaths: [String], parentFolder: String?) -> [SimpleLibraryItem]? {
        getItemsNotInParentFolderCallsCount += 1
        getItemsNotInParentFolderReceivedArguments = (relativePaths: relativePaths, parentFolder: parentFolder)
        getItemsNotInParentFolderReceivedInvocations.append((relativePaths: relativePaths, parentFolder: parentFolder))
        if let getItemsNotInParentFolderClosure = getItemsNotInParentFolderClosure {
            return getItemsNotInParentFolderClosure(relativePaths, parentFolder)
        } else {
            return getItemsNotInParentFolderReturnValue
        }
    }
    //MARK: - getItemProperty

    var getItemPropertyRelativePathCallsCount = 0
    var getItemPropertyRelativePathCalled: Bool {
        return getItemPropertyRelativePathCallsCount > 0
    }
    var getItemPropertyRelativePathReceivedArguments: (property: String, relativePath: String)?
    var getItemPropertyRelativePathReceivedInvocations: [(property: String, relativePath: String)] = []
    var getItemPropertyRelativePathReturnValue: Any?
    var getItemPropertyRelativePathClosure: ((String, String) -> Any?)?
    func getItemProperty(_ property: String, relativePath: String) -> Any? {
        getItemPropertyRelativePathCallsCount += 1
        getItemPropertyRelativePathReceivedArguments = (property: property, relativePath: relativePath)
        getItemPropertyRelativePathReceivedInvocations.append((property: property, relativePath: relativePath))
        if let getItemPropertyRelativePathClosure = getItemPropertyRelativePathClosure {
            return getItemPropertyRelativePathClosure(property, relativePath)
        } else {
            return getItemPropertyRelativePathReturnValue
        }
    }
    //MARK: - filterContents

    var filterContentsAtQueryScopeLimitOffsetCallsCount = 0
    var filterContentsAtQueryScopeLimitOffsetCalled: Bool {
        return filterContentsAtQueryScopeLimitOffsetCallsCount > 0
    }
    var filterContentsAtQueryScopeLimitOffsetReceivedArguments: (relativePath: String?, query: String?, scope: SimpleItemType, limit: Int?, offset: Int?)?
    var filterContentsAtQueryScopeLimitOffsetReceivedInvocations: [(relativePath: String?, query: String?, scope: SimpleItemType, limit: Int?, offset: Int?)] = []
    var filterContentsAtQueryScopeLimitOffsetReturnValue: [SimpleLibraryItem]?
    var filterContentsAtQueryScopeLimitOffsetClosure: ((String?, String?, SimpleItemType, Int?, Int?) -> [SimpleLibraryItem]?)?
    func filterContents(at relativePath: String?, query: String?, scope: SimpleItemType, limit: Int?, offset: Int?) -> [SimpleLibraryItem]? {
        filterContentsAtQueryScopeLimitOffsetCallsCount += 1
        filterContentsAtQueryScopeLimitOffsetReceivedArguments = (relativePath: relativePath, query: query, scope: scope, limit: limit, offset: offset)
        filterContentsAtQueryScopeLimitOffsetReceivedInvocations.append((relativePath: relativePath, query: query, scope: scope, limit: limit, offset: offset))
        if let filterContentsAtQueryScopeLimitOffsetClosure = filterContentsAtQueryScopeLimitOffsetClosure {
            return filterContentsAtQueryScopeLimitOffsetClosure(relativePath, query, scope, limit, offset)
        } else {
            return filterContentsAtQueryScopeLimitOffsetReturnValue
        }
    }
    //MARK: - findFirstItem

    var findFirstItemInIsUnfinishedCallsCount = 0
    var findFirstItemInIsUnfinishedCalled: Bool {
        return findFirstItemInIsUnfinishedCallsCount > 0
    }
    var findFirstItemInIsUnfinishedReceivedArguments: (parentFolder: String?, isUnfinished: Bool?)?
    var findFirstItemInIsUnfinishedReceivedInvocations: [(parentFolder: String?, isUnfinished: Bool?)] = []
    var findFirstItemInIsUnfinishedReturnValue: SimpleLibraryItem?
    var findFirstItemInIsUnfinishedClosure: ((String?, Bool?) -> SimpleLibraryItem?)?
    func findFirstItem(in parentFolder: String?, isUnfinished: Bool?) -> SimpleLibraryItem? {
        findFirstItemInIsUnfinishedCallsCount += 1
        findFirstItemInIsUnfinishedReceivedArguments = (parentFolder: parentFolder, isUnfinished: isUnfinished)
        findFirstItemInIsUnfinishedReceivedInvocations.append((parentFolder: parentFolder, isUnfinished: isUnfinished))
        if let findFirstItemInIsUnfinishedClosure = findFirstItemInIsUnfinishedClosure {
            return findFirstItemInIsUnfinishedClosure(parentFolder, isUnfinished)
        } else {
            return findFirstItemInIsUnfinishedReturnValue
        }
    }
    //MARK: - findFirstItem

    var findFirstItemInBeforeRankCallsCount = 0
    var findFirstItemInBeforeRankCalled: Bool {
        return findFirstItemInBeforeRankCallsCount > 0
    }
    var findFirstItemInBeforeRankReceivedArguments: (parentFolder: String?, beforeRank: Int16?)?
    var findFirstItemInBeforeRankReceivedInvocations: [(parentFolder: String?, beforeRank: Int16?)] = []
    var findFirstItemInBeforeRankReturnValue: SimpleLibraryItem?
    var findFirstItemInBeforeRankClosure: ((String?, Int16?) -> SimpleLibraryItem?)?
    func findFirstItem(in parentFolder: String?, beforeRank: Int16?) -> SimpleLibraryItem? {
        findFirstItemInBeforeRankCallsCount += 1
        findFirstItemInBeforeRankReceivedArguments = (parentFolder: parentFolder, beforeRank: beforeRank)
        findFirstItemInBeforeRankReceivedInvocations.append((parentFolder: parentFolder, beforeRank: beforeRank))
        if let findFirstItemInBeforeRankClosure = findFirstItemInBeforeRankClosure {
            return findFirstItemInBeforeRankClosure(parentFolder, beforeRank)
        } else {
            return findFirstItemInBeforeRankReturnValue
        }
    }
    //MARK: - findFirstItem

    var findFirstItemInAfterRankIsUnfinishedCallsCount = 0
    var findFirstItemInAfterRankIsUnfinishedCalled: Bool {
        return findFirstItemInAfterRankIsUnfinishedCallsCount > 0
    }
    var findFirstItemInAfterRankIsUnfinishedReceivedArguments: (parentFolder: String?, afterRank: Int16?, isUnfinished: Bool?)?
    var findFirstItemInAfterRankIsUnfinishedReceivedInvocations: [(parentFolder: String?, afterRank: Int16?, isUnfinished: Bool?)] = []
    var findFirstItemInAfterRankIsUnfinishedReturnValue: SimpleLibraryItem?
    var findFirstItemInAfterRankIsUnfinishedClosure: ((String?, Int16?, Bool?) -> SimpleLibraryItem?)?
    func findFirstItem(in parentFolder: String?, afterRank: Int16?, isUnfinished: Bool?) -> SimpleLibraryItem? {
        findFirstItemInAfterRankIsUnfinishedCallsCount += 1
        findFirstItemInAfterRankIsUnfinishedReceivedArguments = (parentFolder: parentFolder, afterRank: afterRank, isUnfinished: isUnfinished)
        findFirstItemInAfterRankIsUnfinishedReceivedInvocations.append((parentFolder: parentFolder, afterRank: afterRank, isUnfinished: isUnfinished))
        if let findFirstItemInAfterRankIsUnfinishedClosure = findFirstItemInAfterRankIsUnfinishedClosure {
            return findFirstItemInAfterRankIsUnfinishedClosure(parentFolder, afterRank, isUnfinished)
        } else {
            return findFirstItemInAfterRankIsUnfinishedReturnValue
        }
    }
    //MARK: - getChapters

    var getChaptersFromCallsCount = 0
    var getChaptersFromCalled: Bool {
        return getChaptersFromCallsCount > 0
    }
    var getChaptersFromReceivedRelativePath: String?
    var getChaptersFromReceivedInvocations: [String] = []
    var getChaptersFromReturnValue: [SimpleChapter]?
    var getChaptersFromClosure: ((String) -> [SimpleChapter]?)?
    func getChapters(from relativePath: String) -> [SimpleChapter]? {
        getChaptersFromCallsCount += 1
        getChaptersFromReceivedRelativePath = relativePath
        getChaptersFromReceivedInvocations.append(relativePath)
        if let getChaptersFromClosure = getChaptersFromClosure {
            return getChaptersFromClosure(relativePath)
        } else {
            return getChaptersFromReturnValue
        }
    }
    //MARK: - createBook

    var createBookFromCallsCount = 0
    var createBookFromCalled: Bool {
        return createBookFromCallsCount > 0
    }
    var createBookFromReceivedUrl: URL?
    var createBookFromReceivedInvocations: [URL] = []
    var createBookFromReturnValue: Book!
    var createBookFromClosure: ((URL) -> Book)?
    func createBook(from url: URL) -> Book {
        createBookFromCallsCount += 1
        createBookFromReceivedUrl = url
        createBookFromReceivedInvocations.append(url)
        if let createBookFromClosure = createBookFromClosure {
            return createBookFromClosure(url)
        } else {
            return createBookFromReturnValue
        }
    }
    //MARK: - loadChaptersIfNeeded

    var loadChaptersIfNeededRelativePathAssetCallsCount = 0
    var loadChaptersIfNeededRelativePathAssetCalled: Bool {
        return loadChaptersIfNeededRelativePathAssetCallsCount > 0
    }
    var loadChaptersIfNeededRelativePathAssetReceivedArguments: (relativePath: String, asset: AVAsset)?
    var loadChaptersIfNeededRelativePathAssetReceivedInvocations: [(relativePath: String, asset: AVAsset)] = []
    var loadChaptersIfNeededRelativePathAssetClosure: ((String, AVAsset) async -> Void)?
    func loadChaptersIfNeeded(relativePath: String, asset: AVAsset) async {
        loadChaptersIfNeededRelativePathAssetCallsCount += 1
        loadChaptersIfNeededRelativePathAssetReceivedArguments = (relativePath: relativePath, asset: asset)
        loadChaptersIfNeededRelativePathAssetReceivedInvocations.append((relativePath: relativePath, asset: asset))
        await loadChaptersIfNeededRelativePathAssetClosure?(relativePath, asset)
    }
    //MARK: - createFolder

    var createFolderWithInsideThrowableError: Error?
    var createFolderWithInsideCallsCount = 0
    var createFolderWithInsideCalled: Bool {
        return createFolderWithInsideCallsCount > 0
    }
    var createFolderWithInsideReceivedArguments: (title: String, relativePath: String?)?
    var createFolderWithInsideReceivedInvocations: [(title: String, relativePath: String?)] = []
    var createFolderWithInsideReturnValue: SimpleLibraryItem!
    var createFolderWithInsideClosure: ((String, String?) throws -> SimpleLibraryItem)?
    func createFolder(with title: String, inside relativePath: String?) throws -> SimpleLibraryItem {
        if let error = createFolderWithInsideThrowableError {
            throw error
        }
        createFolderWithInsideCallsCount += 1
        createFolderWithInsideReceivedArguments = (title: title, relativePath: relativePath)
        createFolderWithInsideReceivedInvocations.append((title: title, relativePath: relativePath))
        if let createFolderWithInsideClosure = createFolderWithInsideClosure {
            return try createFolderWithInsideClosure(title, relativePath)
        } else {
            return createFolderWithInsideReturnValue
        }
    }
    //MARK: - updateFolder

    var updateFolderAtTypeThrowableError: Error?
    var updateFolderAtTypeCallsCount = 0
    var updateFolderAtTypeCalled: Bool {
        return updateFolderAtTypeCallsCount > 0
    }
    var updateFolderAtTypeReceivedArguments: (relativePath: String, type: SimpleItemType)?
    var updateFolderAtTypeReceivedInvocations: [(relativePath: String, type: SimpleItemType)] = []
    var updateFolderAtTypeClosure: ((String, SimpleItemType) throws -> Void)?
    func updateFolder(at relativePath: String, type: SimpleItemType) throws {
        if let error = updateFolderAtTypeThrowableError {
            throw error
        }
        updateFolderAtTypeCallsCount += 1
        updateFolderAtTypeReceivedArguments = (relativePath: relativePath, type: type)
        updateFolderAtTypeReceivedInvocations.append((relativePath: relativePath, type: type))
        try updateFolderAtTypeClosure?(relativePath, type)
    }
    //MARK: - rebuildFolderDetails

    var rebuildFolderDetailsCallsCount = 0
    var rebuildFolderDetailsCalled: Bool {
        return rebuildFolderDetailsCallsCount > 0
    }
    var rebuildFolderDetailsReceivedRelativePath: String?
    var rebuildFolderDetailsReceivedInvocations: [String] = []
    var rebuildFolderDetailsClosure: ((String) -> Void)?
    func rebuildFolderDetails(_ relativePath: String) {
        rebuildFolderDetailsCallsCount += 1
        rebuildFolderDetailsReceivedRelativePath = relativePath
        rebuildFolderDetailsReceivedInvocations.append(relativePath)
        rebuildFolderDetailsClosure?(relativePath)
    }
    //MARK: - recursiveFolderProgressUpdate

    var recursiveFolderProgressUpdateFromCallsCount = 0
    var recursiveFolderProgressUpdateFromCalled: Bool {
        return recursiveFolderProgressUpdateFromCallsCount > 0
    }
    var recursiveFolderProgressUpdateFromReceivedRelativePath: String?
    var recursiveFolderProgressUpdateFromReceivedInvocations: [String] = []
    var recursiveFolderProgressUpdateFromClosure: ((String) -> Void)?
    func recursiveFolderProgressUpdate(from relativePath: String) {
        recursiveFolderProgressUpdateFromCallsCount += 1
        recursiveFolderProgressUpdateFromReceivedRelativePath = relativePath
        recursiveFolderProgressUpdateFromReceivedInvocations.append(relativePath)
        recursiveFolderProgressUpdateFromClosure?(relativePath)
    }
    //MARK: - renameBook

    var renameBookAtWithCallsCount = 0
    var renameBookAtWithCalled: Bool {
        return renameBookAtWithCallsCount > 0
    }
    var renameBookAtWithReceivedArguments: (relativePath: String, newTitle: String)?
    var renameBookAtWithReceivedInvocations: [(relativePath: String, newTitle: String)] = []
    var renameBookAtWithClosure: ((String, String) -> Void)?
    func renameBook(at relativePath: String, with newTitle: String) {
        renameBookAtWithCallsCount += 1
        renameBookAtWithReceivedArguments = (relativePath: relativePath, newTitle: newTitle)
        renameBookAtWithReceivedInvocations.append((relativePath: relativePath, newTitle: newTitle))
        renameBookAtWithClosure?(relativePath, newTitle)
    }
    //MARK: - renameFolder

    var renameFolderAtWithThrowableError: Error?
    var renameFolderAtWithCallsCount = 0
    var renameFolderAtWithCalled: Bool {
        return renameFolderAtWithCallsCount > 0
    }
    var renameFolderAtWithReceivedArguments: (relativePath: String, newTitle: String)?
    var renameFolderAtWithReceivedInvocations: [(relativePath: String, newTitle: String)] = []
    var renameFolderAtWithReturnValue: String!
    var renameFolderAtWithClosure: ((String, String) throws -> String)?
    func renameFolder(at relativePath: String, with newTitle: String) throws -> String {
        if let error = renameFolderAtWithThrowableError {
            throw error
        }
        renameFolderAtWithCallsCount += 1
        renameFolderAtWithReceivedArguments = (relativePath: relativePath, newTitle: newTitle)
        renameFolderAtWithReceivedInvocations.append((relativePath: relativePath, newTitle: newTitle))
        if let renameFolderAtWithClosure = renameFolderAtWithClosure {
            return try renameFolderAtWithClosure(relativePath, newTitle)
        } else {
            return renameFolderAtWithReturnValue
        }
    }
    //MARK: - updateDetails

    var updateDetailsAtDetailsCallsCount = 0
    var updateDetailsAtDetailsCalled: Bool {
        return updateDetailsAtDetailsCallsCount > 0
    }
    var updateDetailsAtDetailsReceivedArguments: (relativePath: String, details: String)?
    var updateDetailsAtDetailsReceivedInvocations: [(relativePath: String, details: String)] = []
    var updateDetailsAtDetailsClosure: ((String, String) -> Void)?
    func updateDetails(at relativePath: String, details: String) {
        updateDetailsAtDetailsCallsCount += 1
        updateDetailsAtDetailsReceivedArguments = (relativePath: relativePath, details: details)
        updateDetailsAtDetailsReceivedInvocations.append((relativePath: relativePath, details: details))
        updateDetailsAtDetailsClosure?(relativePath, details)
    }
    //MARK: - reorderItem

    var reorderItemWithInsideSourceIndexPathDestinationIndexPathCallsCount = 0
    var reorderItemWithInsideSourceIndexPathDestinationIndexPathCalled: Bool {
        return reorderItemWithInsideSourceIndexPathDestinationIndexPathCallsCount > 0
    }
    var reorderItemWithInsideSourceIndexPathDestinationIndexPathReceivedArguments: (relativePath: String, folderRelativePath: String?, sourceIndexPath: IndexPath, destinationIndexPath: IndexPath)?
    var reorderItemWithInsideSourceIndexPathDestinationIndexPathReceivedInvocations: [(relativePath: String, folderRelativePath: String?, sourceIndexPath: IndexPath, destinationIndexPath: IndexPath)] = []
    var reorderItemWithInsideSourceIndexPathDestinationIndexPathClosure: ((String, String?, IndexPath, IndexPath) -> Void)?
    func reorderItem(with relativePath: String, inside folderRelativePath: String?, sourceIndexPath: IndexPath, destinationIndexPath: IndexPath) {
        reorderItemWithInsideSourceIndexPathDestinationIndexPathCallsCount += 1
        reorderItemWithInsideSourceIndexPathDestinationIndexPathReceivedArguments = (relativePath: relativePath, folderRelativePath: folderRelativePath, sourceIndexPath: sourceIndexPath, destinationIndexPath: destinationIndexPath)
        reorderItemWithInsideSourceIndexPathDestinationIndexPathReceivedInvocations.append((relativePath: relativePath, folderRelativePath: folderRelativePath, sourceIndexPath: sourceIndexPath, destinationIndexPath: destinationIndexPath))
        reorderItemWithInsideSourceIndexPathDestinationIndexPathClosure?(relativePath, folderRelativePath, sourceIndexPath, destinationIndexPath)
    }
    //MARK: - sortContents

    var sortContentsAtByCallsCount = 0
    var sortContentsAtByCalled: Bool {
        return sortContentsAtByCallsCount > 0
    }
    var sortContentsAtByReceivedArguments: (relativePath: String?, type: SortType)?
    var sortContentsAtByReceivedInvocations: [(relativePath: String?, type: SortType)] = []
    var sortContentsAtByClosure: ((String?, SortType) -> Void)?
    func sortContents(at relativePath: String?, by type: SortType) {
        sortContentsAtByCallsCount += 1
        sortContentsAtByReceivedArguments = (relativePath: relativePath, type: type)
        sortContentsAtByReceivedInvocations.append((relativePath: relativePath, type: type))
        sortContentsAtByClosure?(relativePath, type)
    }
    //MARK: - updatePlaybackTime

    var updatePlaybackTimeRelativePathTimeDateScheduleSaveCallsCount = 0
    var updatePlaybackTimeRelativePathTimeDateScheduleSaveCalled: Bool {
        return updatePlaybackTimeRelativePathTimeDateScheduleSaveCallsCount > 0
    }
    var updatePlaybackTimeRelativePathTimeDateScheduleSaveReceivedArguments: (relativePath: String, time: Double, date: Date, scheduleSave: Bool)?
    var updatePlaybackTimeRelativePathTimeDateScheduleSaveReceivedInvocations: [(relativePath: String, time: Double, date: Date, scheduleSave: Bool)] = []
    var updatePlaybackTimeRelativePathTimeDateScheduleSaveClosure: ((String, Double, Date, Bool) -> Void)?
    func updatePlaybackTime(relativePath: String, time: Double, date: Date, scheduleSave: Bool) {
        updatePlaybackTimeRelativePathTimeDateScheduleSaveCallsCount += 1
        updatePlaybackTimeRelativePathTimeDateScheduleSaveReceivedArguments = (relativePath: relativePath, time: time, date: date, scheduleSave: scheduleSave)
        updatePlaybackTimeRelativePathTimeDateScheduleSaveReceivedInvocations.append((relativePath: relativePath, time: time, date: date, scheduleSave: scheduleSave))
        updatePlaybackTimeRelativePathTimeDateScheduleSaveClosure?(relativePath, time, date, scheduleSave)
    }
    //MARK: - updateBookSpeed

    var updateBookSpeedAtSpeedCallsCount = 0
    var updateBookSpeedAtSpeedCalled: Bool {
        return updateBookSpeedAtSpeedCallsCount > 0
    }
    var updateBookSpeedAtSpeedReceivedArguments: (relativePath: String, speed: Float)?
    var updateBookSpeedAtSpeedReceivedInvocations: [(relativePath: String, speed: Float)] = []
    var updateBookSpeedAtSpeedClosure: ((String, Float) -> Void)?
    func updateBookSpeed(at relativePath: String, speed: Float) {
        updateBookSpeedAtSpeedCallsCount += 1
        updateBookSpeedAtSpeedReceivedArguments = (relativePath: relativePath, speed: speed)
        updateBookSpeedAtSpeedReceivedInvocations.append((relativePath: relativePath, speed: speed))
        updateBookSpeedAtSpeedClosure?(relativePath, speed)
    }
    //MARK: - getItemSpeed

    var getItemSpeedAtCallsCount = 0
    var getItemSpeedAtCalled: Bool {
        return getItemSpeedAtCallsCount > 0
    }
    var getItemSpeedAtReceivedRelativePath: String?
    var getItemSpeedAtReceivedInvocations: [String] = []
    var getItemSpeedAtReturnValue: Float!
    var getItemSpeedAtClosure: ((String) -> Float)?
    func getItemSpeed(at relativePath: String) -> Float {
        getItemSpeedAtCallsCount += 1
        getItemSpeedAtReceivedRelativePath = relativePath
        getItemSpeedAtReceivedInvocations.append(relativePath)
        if let getItemSpeedAtClosure = getItemSpeedAtClosure {
            return getItemSpeedAtClosure(relativePath)
        } else {
            return getItemSpeedAtReturnValue
        }
    }
    //MARK: - markAsFinished

    var markAsFinishedFlagRelativePathCallsCount = 0
    var markAsFinishedFlagRelativePathCalled: Bool {
        return markAsFinishedFlagRelativePathCallsCount > 0
    }
    var markAsFinishedFlagRelativePathReceivedArguments: (flag: Bool, relativePath: String)?
    var markAsFinishedFlagRelativePathReceivedInvocations: [(flag: Bool, relativePath: String)] = []
    var markAsFinishedFlagRelativePathClosure: ((Bool, String) -> Void)?
    func markAsFinished(flag: Bool, relativePath: String) {
        markAsFinishedFlagRelativePathCallsCount += 1
        markAsFinishedFlagRelativePathReceivedArguments = (flag: flag, relativePath: relativePath)
        markAsFinishedFlagRelativePathReceivedInvocations.append((flag: flag, relativePath: relativePath))
        markAsFinishedFlagRelativePathClosure?(flag, relativePath)
    }
    //MARK: - jumpToStart

    var jumpToStartRelativePathCallsCount = 0
    var jumpToStartRelativePathCalled: Bool {
        return jumpToStartRelativePathCallsCount > 0
    }
    var jumpToStartRelativePathReceivedRelativePath: String?
    var jumpToStartRelativePathReceivedInvocations: [String] = []
    var jumpToStartRelativePathClosure: ((String) -> Void)?
    func jumpToStart(relativePath: String) {
        jumpToStartRelativePathCallsCount += 1
        jumpToStartRelativePathReceivedRelativePath = relativePath
        jumpToStartRelativePathReceivedInvocations.append(relativePath)
        jumpToStartRelativePathClosure?(relativePath)
    }
    //MARK: - getCurrentPlaybackRecord

    var getCurrentPlaybackRecordCallsCount = 0
    var getCurrentPlaybackRecordCalled: Bool {
        return getCurrentPlaybackRecordCallsCount > 0
    }
    var getCurrentPlaybackRecordReturnValue: PlaybackRecord!
    var getCurrentPlaybackRecordClosure: (() -> PlaybackRecord)?
    func getCurrentPlaybackRecord() -> PlaybackRecord {
        getCurrentPlaybackRecordCallsCount += 1
        if let getCurrentPlaybackRecordClosure = getCurrentPlaybackRecordClosure {
            return getCurrentPlaybackRecordClosure()
        } else {
            return getCurrentPlaybackRecordReturnValue
        }
    }
    //MARK: - getPlaybackRecords

    var getPlaybackRecordsFromToCallsCount = 0
    var getPlaybackRecordsFromToCalled: Bool {
        return getPlaybackRecordsFromToCallsCount > 0
    }
    var getPlaybackRecordsFromToReceivedArguments: (startDate: Date, endDate: Date)?
    var getPlaybackRecordsFromToReceivedInvocations: [(startDate: Date, endDate: Date)] = []
    var getPlaybackRecordsFromToReturnValue: [PlaybackRecord]?
    var getPlaybackRecordsFromToClosure: ((Date, Date) -> [PlaybackRecord]?)?
    func getPlaybackRecords(from startDate: Date, to endDate: Date) -> [PlaybackRecord]? {
        getPlaybackRecordsFromToCallsCount += 1
        getPlaybackRecordsFromToReceivedArguments = (startDate: startDate, endDate: endDate)
        getPlaybackRecordsFromToReceivedInvocations.append((startDate: startDate, endDate: endDate))
        if let getPlaybackRecordsFromToClosure = getPlaybackRecordsFromToClosure {
            return getPlaybackRecordsFromToClosure(startDate, endDate)
        } else {
            return getPlaybackRecordsFromToReturnValue
        }
    }
    //MARK: - recordTime

    var recordTimeCallsCount = 0
    var recordTimeCalled: Bool {
        return recordTimeCallsCount > 0
    }
    var recordTimeReceivedPlaybackRecord: PlaybackRecord?
    var recordTimeReceivedInvocations: [PlaybackRecord] = []
    var recordTimeClosure: ((PlaybackRecord) -> Void)?
    func recordTime(_ playbackRecord: PlaybackRecord) {
        recordTimeCallsCount += 1
        recordTimeReceivedPlaybackRecord = playbackRecord
        recordTimeReceivedInvocations.append(playbackRecord)
        recordTimeClosure?(playbackRecord)
    }
    //MARK: - getTotalListenedTime

    var getTotalListenedTimeCallsCount = 0
    var getTotalListenedTimeCalled: Bool {
        return getTotalListenedTimeCallsCount > 0
    }
    var getTotalListenedTimeReturnValue: TimeInterval!
    var getTotalListenedTimeClosure: (() -> TimeInterval)?
    func getTotalListenedTime() -> TimeInterval {
        getTotalListenedTimeCallsCount += 1
        if let getTotalListenedTimeClosure = getTotalListenedTimeClosure {
            return getTotalListenedTimeClosure()
        } else {
            return getTotalListenedTimeReturnValue
        }
    }
    //MARK: - getBookmarks

    var getBookmarksOfRelativePathCallsCount = 0
    var getBookmarksOfRelativePathCalled: Bool {
        return getBookmarksOfRelativePathCallsCount > 0
    }
    var getBookmarksOfRelativePathReceivedArguments: (type: BookmarkType, relativePath: String)?
    var getBookmarksOfRelativePathReceivedInvocations: [(type: BookmarkType, relativePath: String)] = []
    var getBookmarksOfRelativePathReturnValue: [SimpleBookmark]?
    var getBookmarksOfRelativePathClosure: ((BookmarkType, String) -> [SimpleBookmark]?)?
    func getBookmarks(of type: BookmarkType, relativePath: String) -> [SimpleBookmark]? {
        getBookmarksOfRelativePathCallsCount += 1
        getBookmarksOfRelativePathReceivedArguments = (type: type, relativePath: relativePath)
        getBookmarksOfRelativePathReceivedInvocations.append((type: type, relativePath: relativePath))
        if let getBookmarksOfRelativePathClosure = getBookmarksOfRelativePathClosure {
            return getBookmarksOfRelativePathClosure(type, relativePath)
        } else {
            return getBookmarksOfRelativePathReturnValue
        }
    }
    //MARK: - getBookmark

    var getBookmarkAtRelativePathTypeCallsCount = 0
    var getBookmarkAtRelativePathTypeCalled: Bool {
        return getBookmarkAtRelativePathTypeCallsCount > 0
    }
    var getBookmarkAtRelativePathTypeReceivedArguments: (time: Double, relativePath: String, type: BookmarkType)?
    var getBookmarkAtRelativePathTypeReceivedInvocations: [(time: Double, relativePath: String, type: BookmarkType)] = []
    var getBookmarkAtRelativePathTypeReturnValue: SimpleBookmark?
    var getBookmarkAtRelativePathTypeClosure: ((Double, String, BookmarkType) -> SimpleBookmark?)?
    func getBookmark(at time: Double, relativePath: String, type: BookmarkType) -> SimpleBookmark? {
        getBookmarkAtRelativePathTypeCallsCount += 1
        getBookmarkAtRelativePathTypeReceivedArguments = (time: time, relativePath: relativePath, type: type)
        getBookmarkAtRelativePathTypeReceivedInvocations.append((time: time, relativePath: relativePath, type: type))
        if let getBookmarkAtRelativePathTypeClosure = getBookmarkAtRelativePathTypeClosure {
            return getBookmarkAtRelativePathTypeClosure(time, relativePath, type)
        } else {
            return getBookmarkAtRelativePathTypeReturnValue
        }
    }
    //MARK: - createBookmark

    var createBookmarkAtRelativePathTypeCallsCount = 0
    var createBookmarkAtRelativePathTypeCalled: Bool {
        return createBookmarkAtRelativePathTypeCallsCount > 0
    }
    var createBookmarkAtRelativePathTypeReceivedArguments: (time: Double, relativePath: String, type: BookmarkType)?
    var createBookmarkAtRelativePathTypeReceivedInvocations: [(time: Double, relativePath: String, type: BookmarkType)] = []
    var createBookmarkAtRelativePathTypeReturnValue: SimpleBookmark?
    var createBookmarkAtRelativePathTypeClosure: ((Double, String, BookmarkType) -> SimpleBookmark?)?
    func createBookmark(at time: Double, relativePath: String, type: BookmarkType) -> SimpleBookmark? {
        createBookmarkAtRelativePathTypeCallsCount += 1
        createBookmarkAtRelativePathTypeReceivedArguments = (time: time, relativePath: relativePath, type: type)
        createBookmarkAtRelativePathTypeReceivedInvocations.append((time: time, relativePath: relativePath, type: type))
        if let createBookmarkAtRelativePathTypeClosure = createBookmarkAtRelativePathTypeClosure {
            return createBookmarkAtRelativePathTypeClosure(time, relativePath, type)
        } else {
            return createBookmarkAtRelativePathTypeReturnValue
        }
    }
    //MARK: - addNote

    var addNoteBookmarkCallsCount = 0
    var addNoteBookmarkCalled: Bool {
        return addNoteBookmarkCallsCount > 0
    }
    var addNoteBookmarkReceivedArguments: (note: String, bookmark: SimpleBookmark)?
    var addNoteBookmarkReceivedInvocations: [(note: String, bookmark: SimpleBookmark)] = []
    var addNoteBookmarkClosure: ((String, SimpleBookmark) -> Void)?
    func addNote(_ note: String, bookmark: SimpleBookmark) {
        addNoteBookmarkCallsCount += 1
        addNoteBookmarkReceivedArguments = (note: note, bookmark: bookmark)
        addNoteBookmarkReceivedInvocations.append((note: note, bookmark: bookmark))
        addNoteBookmarkClosure?(note, bookmark)
    }
    //MARK: - deleteBookmark

    var deleteBookmarkCallsCount = 0
    var deleteBookmarkCalled: Bool {
        return deleteBookmarkCallsCount > 0
    }
    var deleteBookmarkReceivedBookmark: SimpleBookmark?
    var deleteBookmarkReceivedInvocations: [SimpleBookmark] = []
    var deleteBookmarkClosure: ((SimpleBookmark) -> Void)?
    func deleteBookmark(_ bookmark: SimpleBookmark) {
        deleteBookmarkCallsCount += 1
        deleteBookmarkReceivedBookmark = bookmark
        deleteBookmarkReceivedInvocations.append(bookmark)
        deleteBookmarkClosure?(bookmark)
    }
}
class PlaybackServiceProtocolMock: PlaybackServiceProtocol {
    //MARK: - updatePlaybackTime

    var updatePlaybackTimeItemTimeCallsCount = 0
    var updatePlaybackTimeItemTimeCalled: Bool {
        return updatePlaybackTimeItemTimeCallsCount > 0
    }
    var updatePlaybackTimeItemTimeReceivedArguments: (item: PlayableItem, time: Double)?
    var updatePlaybackTimeItemTimeReceivedInvocations: [(item: PlayableItem, time: Double)] = []
    var updatePlaybackTimeItemTimeClosure: ((PlayableItem, Double) -> Void)?
    func updatePlaybackTime(item: PlayableItem, time: Double) {
        updatePlaybackTimeItemTimeCallsCount += 1
        updatePlaybackTimeItemTimeReceivedArguments = (item: item, time: time)
        updatePlaybackTimeItemTimeReceivedInvocations.append((item: item, time: time))
        updatePlaybackTimeItemTimeClosure?(item, time)
    }
    //MARK: - getPlayableItem

    var getPlayableItemBeforeParentFolderCallsCount = 0
    var getPlayableItemBeforeParentFolderCalled: Bool {
        return getPlayableItemBeforeParentFolderCallsCount > 0
    }
    var getPlayableItemBeforeParentFolderReceivedArguments: (relativePath: String, parentFolder: String?)?
    var getPlayableItemBeforeParentFolderReceivedInvocations: [(relativePath: String, parentFolder: String?)] = []
    var getPlayableItemBeforeParentFolderReturnValue: PlayableItem?
    var getPlayableItemBeforeParentFolderClosure: ((String, String?) -> PlayableItem?)?
    func getPlayableItem(before relativePath: String, parentFolder: String?) -> PlayableItem? {
        getPlayableItemBeforeParentFolderCallsCount += 1
        getPlayableItemBeforeParentFolderReceivedArguments = (relativePath: relativePath, parentFolder: parentFolder)
        getPlayableItemBeforeParentFolderReceivedInvocations.append((relativePath: relativePath, parentFolder: parentFolder))
        if let getPlayableItemBeforeParentFolderClosure = getPlayableItemBeforeParentFolderClosure {
            return getPlayableItemBeforeParentFolderClosure(relativePath, parentFolder)
        } else {
            return getPlayableItemBeforeParentFolderReturnValue
        }
    }
    //MARK: - getPlayableItem

    var getPlayableItemAfterParentFolderAutoplayedRestartFinishedCallsCount = 0
    var getPlayableItemAfterParentFolderAutoplayedRestartFinishedCalled: Bool {
        return getPlayableItemAfterParentFolderAutoplayedRestartFinishedCallsCount > 0
    }
    var getPlayableItemAfterParentFolderAutoplayedRestartFinishedReceivedArguments: (relativePath: String, parentFolder: String?, autoplayed: Bool, restartFinished: Bool)?
    var getPlayableItemAfterParentFolderAutoplayedRestartFinishedReceivedInvocations: [(relativePath: String, parentFolder: String?, autoplayed: Bool, restartFinished: Bool)] = []
    var getPlayableItemAfterParentFolderAutoplayedRestartFinishedReturnValue: PlayableItem?
    var getPlayableItemAfterParentFolderAutoplayedRestartFinishedClosure: ((String, String?, Bool, Bool) -> PlayableItem?)?
    func getPlayableItem(after relativePath: String, parentFolder: String?, autoplayed: Bool, restartFinished: Bool) -> PlayableItem? {
        getPlayableItemAfterParentFolderAutoplayedRestartFinishedCallsCount += 1
        getPlayableItemAfterParentFolderAutoplayedRestartFinishedReceivedArguments = (relativePath: relativePath, parentFolder: parentFolder, autoplayed: autoplayed, restartFinished: restartFinished)
        getPlayableItemAfterParentFolderAutoplayedRestartFinishedReceivedInvocations.append((relativePath: relativePath, parentFolder: parentFolder, autoplayed: autoplayed, restartFinished: restartFinished))
        if let getPlayableItemAfterParentFolderAutoplayedRestartFinishedClosure = getPlayableItemAfterParentFolderAutoplayedRestartFinishedClosure {
            return getPlayableItemAfterParentFolderAutoplayedRestartFinishedClosure(relativePath, parentFolder, autoplayed, restartFinished)
        } else {
            return getPlayableItemAfterParentFolderAutoplayedRestartFinishedReturnValue
        }
    }
    //MARK: - getFirstPlayableItem

    var getFirstPlayableItemInIsUnfinishedThrowableError: Error?
    var getFirstPlayableItemInIsUnfinishedCallsCount = 0
    var getFirstPlayableItemInIsUnfinishedCalled: Bool {
        return getFirstPlayableItemInIsUnfinishedCallsCount > 0
    }
    var getFirstPlayableItemInIsUnfinishedReceivedArguments: (folder: SimpleLibraryItem, isUnfinished: Bool?)?
    var getFirstPlayableItemInIsUnfinishedReceivedInvocations: [(folder: SimpleLibraryItem, isUnfinished: Bool?)] = []
    var getFirstPlayableItemInIsUnfinishedReturnValue: PlayableItem?
    var getFirstPlayableItemInIsUnfinishedClosure: ((SimpleLibraryItem, Bool?) throws -> PlayableItem?)?
    func getFirstPlayableItem(in folder: SimpleLibraryItem, isUnfinished: Bool?) throws -> PlayableItem? {
        if let error = getFirstPlayableItemInIsUnfinishedThrowableError {
            throw error
        }
        getFirstPlayableItemInIsUnfinishedCallsCount += 1
        getFirstPlayableItemInIsUnfinishedReceivedArguments = (folder: folder, isUnfinished: isUnfinished)
        getFirstPlayableItemInIsUnfinishedReceivedInvocations.append((folder: folder, isUnfinished: isUnfinished))
        if let getFirstPlayableItemInIsUnfinishedClosure = getFirstPlayableItemInIsUnfinishedClosure {
            return try getFirstPlayableItemInIsUnfinishedClosure(folder, isUnfinished)
        } else {
            return getFirstPlayableItemInIsUnfinishedReturnValue
        }
    }
    //MARK: - getPlayableItem

    var getPlayableItemFromThrowableError: Error?
    var getPlayableItemFromCallsCount = 0
    var getPlayableItemFromCalled: Bool {
        return getPlayableItemFromCallsCount > 0
    }
    var getPlayableItemFromReceivedItem: SimpleLibraryItem?
    var getPlayableItemFromReceivedInvocations: [SimpleLibraryItem] = []
    var getPlayableItemFromReturnValue: PlayableItem!
    var getPlayableItemFromClosure: ((SimpleLibraryItem) throws -> PlayableItem)?
    func getPlayableItem(from item: SimpleLibraryItem) throws -> PlayableItem {
        if let error = getPlayableItemFromThrowableError {
            throw error
        }
        getPlayableItemFromCallsCount += 1
        getPlayableItemFromReceivedItem = item
        getPlayableItemFromReceivedInvocations.append(item)
        if let getPlayableItemFromClosure = getPlayableItemFromClosure {
            return try getPlayableItemFromClosure(item)
        } else {
            return getPlayableItemFromReturnValue
        }
    }
    //MARK: - getNextChapter

    var getNextChapterFromAfterCallsCount = 0
    var getNextChapterFromAfterCalled: Bool {
        return getNextChapterFromAfterCallsCount > 0
    }
    var getNextChapterFromAfterReceivedArguments: (item: PlayableItem, chapter: PlayableChapter)?
    var getNextChapterFromAfterReceivedInvocations: [(item: PlayableItem, chapter: PlayableChapter)] = []
    var getNextChapterFromAfterReturnValue: PlayableChapter?
    var getNextChapterFromAfterClosure: ((PlayableItem, PlayableChapter) -> PlayableChapter?)?
    func getNextChapter(from item: PlayableItem, after chapter: PlayableChapter) -> PlayableChapter? {
        getNextChapterFromAfterCallsCount += 1
        getNextChapterFromAfterReceivedArguments = (item: item, chapter: chapter)
        getNextChapterFromAfterReceivedInvocations.append((item: item, chapter: chapter))
        if let getNextChapterFromAfterClosure = getNextChapterFromAfterClosure {
            return getNextChapterFromAfterClosure(item, chapter)
        } else {
            return getNextChapterFromAfterReturnValue
        }
    }
    //MARK: - markStaleProgress

    var markStaleProgressFolderPathCallsCount = 0
    var markStaleProgressFolderPathCalled: Bool {
        return markStaleProgressFolderPathCallsCount > 0
    }
    var markStaleProgressFolderPathReceivedFolderPath: String?
    var markStaleProgressFolderPathReceivedInvocations: [String] = []
    var markStaleProgressFolderPathClosure: ((String) -> Void)?
    func markStaleProgress(folderPath: String) {
        markStaleProgressFolderPathCallsCount += 1
        markStaleProgressFolderPathReceivedFolderPath = folderPath
        markStaleProgressFolderPathReceivedInvocations.append(folderPath)
        markStaleProgressFolderPathClosure?(folderPath)
    }
    //MARK: - processFoldersStaleProgress

    var processFoldersStaleProgressCallsCount = 0
    var processFoldersStaleProgressCalled: Bool {
        return processFoldersStaleProgressCallsCount > 0
    }
    var processFoldersStaleProgressReturnValue: Bool!
    var processFoldersStaleProgressClosure: (() -> Bool)?
    func processFoldersStaleProgress() -> Bool {
        processFoldersStaleProgressCallsCount += 1
        if let processFoldersStaleProgressClosure = processFoldersStaleProgressClosure {
            return processFoldersStaleProgressClosure()
        } else {
            return processFoldersStaleProgressReturnValue
        }
    }
}
class PlayerManagerProtocolMock: PlayerManagerProtocol {
    var currentItem: PlayableItem?
    var currentSpeed: Float {
        get { return underlyingCurrentSpeed }
        set(value) { underlyingCurrentSpeed = value }
    }
    var underlyingCurrentSpeed: Float!
    var isPlaying: Bool {
        get { return underlyingIsPlaying }
        set(value) { underlyingIsPlaying = value }
    }
    var underlyingIsPlaying: Bool!
    var syncProgressDelegate: PlaybackSyncProgressDelegate?
    //MARK: - load

    var loadAutoplayCallsCount = 0
    var loadAutoplayCalled: Bool {
        return loadAutoplayCallsCount > 0
    }
    var loadAutoplayReceivedArguments: (item: PlayableItem, autoplay: Bool)?
    var loadAutoplayReceivedInvocations: [(item: PlayableItem, autoplay: Bool)] = []
    var loadAutoplayClosure: ((PlayableItem, Bool) -> Void)?
    func load(_ item: PlayableItem, autoplay: Bool) {
        loadAutoplayCallsCount += 1
        loadAutoplayReceivedArguments = (item: item, autoplay: autoplay)
        loadAutoplayReceivedInvocations.append((item: item, autoplay: autoplay))
        loadAutoplayClosure?(item, autoplay)
    }
    //MARK: - hasLoadedBook

    var hasLoadedBookCallsCount = 0
    var hasLoadedBookCalled: Bool {
        return hasLoadedBookCallsCount > 0
    }
    var hasLoadedBookReturnValue: Bool!
    var hasLoadedBookClosure: (() -> Bool)?
    func hasLoadedBook() -> Bool {
        hasLoadedBookCallsCount += 1
        if let hasLoadedBookClosure = hasLoadedBookClosure {
            return hasLoadedBookClosure()
        } else {
            return hasLoadedBookReturnValue
        }
    }
    //MARK: - playPreviousItem

    var playPreviousItemCallsCount = 0
    var playPreviousItemCalled: Bool {
        return playPreviousItemCallsCount > 0
    }
    var playPreviousItemClosure: (() -> Void)?
    func playPreviousItem() {
        playPreviousItemCallsCount += 1
        playPreviousItemClosure?()
    }
    //MARK: - playNextItem

    var playNextItemAutoPlayedShouldAutoplayCallsCount = 0
    var playNextItemAutoPlayedShouldAutoplayCalled: Bool {
        return playNextItemAutoPlayedShouldAutoplayCallsCount > 0
    }
    var playNextItemAutoPlayedShouldAutoplayReceivedArguments: (autoPlayed: Bool, shouldAutoplay: Bool)?
    var playNextItemAutoPlayedShouldAutoplayReceivedInvocations: [(autoPlayed: Bool, shouldAutoplay: Bool)] = []
    var playNextItemAutoPlayedShouldAutoplayClosure: ((Bool, Bool) -> Void)?
    func playNextItem(autoPlayed: Bool, shouldAutoplay: Bool) {
        playNextItemAutoPlayedShouldAutoplayCallsCount += 1
        playNextItemAutoPlayedShouldAutoplayReceivedArguments = (autoPlayed: autoPlayed, shouldAutoplay: shouldAutoplay)
        playNextItemAutoPlayedShouldAutoplayReceivedInvocations.append((autoPlayed: autoPlayed, shouldAutoplay: shouldAutoplay))
        playNextItemAutoPlayedShouldAutoplayClosure?(autoPlayed, shouldAutoplay)
    }
    //MARK: - play

    var playCallsCount = 0
    var playCalled: Bool {
        return playCallsCount > 0
    }
    var playClosure: (() -> Void)?
    func play() {
        playCallsCount += 1
        playClosure?()
    }
    //MARK: - playPause

    var playPauseCallsCount = 0
    var playPauseCalled: Bool {
        return playPauseCallsCount > 0
    }
    var playPauseClosure: (() -> Void)?
    func playPause() {
        playPauseCallsCount += 1
        playPauseClosure?()
    }
    //MARK: - pause

    var pauseCallsCount = 0
    var pauseCalled: Bool {
        return pauseCallsCount > 0
    }
    var pauseClosure: (() -> Void)?
    func pause() {
        pauseCallsCount += 1
        pauseClosure?()
    }
    //MARK: - stop

    var stopCallsCount = 0
    var stopCalled: Bool {
        return stopCallsCount > 0
    }
    var stopClosure: (() -> Void)?
    func stop() {
        stopCallsCount += 1
        stopClosure?()
    }
    //MARK: - rewind

    var rewindCallsCount = 0
    var rewindCalled: Bool {
        return rewindCallsCount > 0
    }
    var rewindClosure: (() -> Void)?
    func rewind() {
        rewindCallsCount += 1
        rewindClosure?()
    }
    //MARK: - forward

    var forwardCallsCount = 0
    var forwardCalled: Bool {
        return forwardCallsCount > 0
    }
    var forwardClosure: (() -> Void)?
    func forward() {
        forwardCallsCount += 1
        forwardClosure?()
    }
    //MARK: - jumpTo

    var jumpToRecordBookmarkCallsCount = 0
    var jumpToRecordBookmarkCalled: Bool {
        return jumpToRecordBookmarkCallsCount > 0
    }
    var jumpToRecordBookmarkReceivedArguments: (time: Double, recordBookmark: Bool)?
    var jumpToRecordBookmarkReceivedInvocations: [(time: Double, recordBookmark: Bool)] = []
    var jumpToRecordBookmarkClosure: ((Double, Bool) -> Void)?
    func jumpTo(_ time: Double, recordBookmark: Bool) {
        jumpToRecordBookmarkCallsCount += 1
        jumpToRecordBookmarkReceivedArguments = (time: time, recordBookmark: recordBookmark)
        jumpToRecordBookmarkReceivedInvocations.append((time: time, recordBookmark: recordBookmark))
        jumpToRecordBookmarkClosure?(time, recordBookmark)
    }
    //MARK: - jumpToChapter

    var jumpToChapterCallsCount = 0
    var jumpToChapterCalled: Bool {
        return jumpToChapterCallsCount > 0
    }
    var jumpToChapterReceivedChapter: PlayableChapter?
    var jumpToChapterReceivedInvocations: [PlayableChapter] = []
    var jumpToChapterClosure: ((PlayableChapter) -> Void)?
    func jumpToChapter(_ chapter: PlayableChapter) {
        jumpToChapterCallsCount += 1
        jumpToChapterReceivedChapter = chapter
        jumpToChapterReceivedInvocations.append(chapter)
        jumpToChapterClosure?(chapter)
    }
    //MARK: - markAsCompleted

    var markAsCompletedCallsCount = 0
    var markAsCompletedCalled: Bool {
        return markAsCompletedCallsCount > 0
    }
    var markAsCompletedReceivedFlag: Bool?
    var markAsCompletedReceivedInvocations: [Bool] = []
    var markAsCompletedClosure: ((Bool) -> Void)?
    func markAsCompleted(_ flag: Bool) {
        markAsCompletedCallsCount += 1
        markAsCompletedReceivedFlag = flag
        markAsCompletedReceivedInvocations.append(flag)
        markAsCompletedClosure?(flag)
    }
    //MARK: - setSpeed

    var setSpeedCallsCount = 0
    var setSpeedCalled: Bool {
        return setSpeedCallsCount > 0
    }
    var setSpeedReceivedNewValue: Float?
    var setSpeedReceivedInvocations: [Float] = []
    var setSpeedClosure: ((Float) -> Void)?
    func setSpeed(_ newValue: Float) {
        setSpeedCallsCount += 1
        setSpeedReceivedNewValue = newValue
        setSpeedReceivedInvocations.append(newValue)
        setSpeedClosure?(newValue)
    }
    //MARK: - setBoostVolume

    var setBoostVolumeCallsCount = 0
    var setBoostVolumeCalled: Bool {
        return setBoostVolumeCallsCount > 0
    }
    var setBoostVolumeReceivedNewValue: Bool?
    var setBoostVolumeReceivedInvocations: [Bool] = []
    var setBoostVolumeClosure: ((Bool) -> Void)?
    func setBoostVolume(_ newValue: Bool) {
        setBoostVolumeCallsCount += 1
        setBoostVolumeReceivedNewValue = newValue
        setBoostVolumeReceivedInvocations.append(newValue)
        setBoostVolumeClosure?(newValue)
    }
    //MARK: - currentSpeedPublisher

    var currentSpeedPublisherCallsCount = 0
    var currentSpeedPublisherCalled: Bool {
        return currentSpeedPublisherCallsCount > 0
    }
    var currentSpeedPublisherReturnValue: AnyPublisher<Float, Never>!
    var currentSpeedPublisherClosure: (() -> AnyPublisher<Float, Never>)?
    func currentSpeedPublisher() -> AnyPublisher<Float, Never> {
        currentSpeedPublisherCallsCount += 1
        if let currentSpeedPublisherClosure = currentSpeedPublisherClosure {
            return currentSpeedPublisherClosure()
        } else {
            return currentSpeedPublisherReturnValue
        }
    }
    //MARK: - isPlayingPublisher

    var isPlayingPublisherCallsCount = 0
    var isPlayingPublisherCalled: Bool {
        return isPlayingPublisherCallsCount > 0
    }
    var isPlayingPublisherReturnValue: AnyPublisher<Bool, Never>!
    var isPlayingPublisherClosure: (() -> AnyPublisher<Bool, Never>)?
    func isPlayingPublisher() -> AnyPublisher<Bool, Never> {
        isPlayingPublisherCallsCount += 1
        if let isPlayingPublisherClosure = isPlayingPublisherClosure {
            return isPlayingPublisherClosure()
        } else {
            return isPlayingPublisherReturnValue
        }
    }
    //MARK: - currentItemPublisher

    var currentItemPublisherCallsCount = 0
    var currentItemPublisherCalled: Bool {
        return currentItemPublisherCallsCount > 0
    }
    var currentItemPublisherReturnValue: AnyPublisher<PlayableItem?, Never>!
    var currentItemPublisherClosure: (() -> AnyPublisher<PlayableItem?, Never>)?
    func currentItemPublisher() -> AnyPublisher<PlayableItem?, Never> {
        currentItemPublisherCallsCount += 1
        if let currentItemPublisherClosure = currentItemPublisherClosure {
            return currentItemPublisherClosure()
        } else {
            return currentItemPublisherReturnValue
        }
    }
}
class ShakeMotionServiceProtocolMock: ShakeMotionServiceProtocol {
    //MARK: - observeFirstShake

    var observeFirstShakeCompletionCallsCount = 0
    var observeFirstShakeCompletionCalled: Bool {
        return observeFirstShakeCompletionCallsCount > 0
    }
    var observeFirstShakeCompletionReceivedCompletion: (() -> Void)?
    var observeFirstShakeCompletionReceivedInvocations: [(() -> Void)] = []
    var observeFirstShakeCompletionClosure: ((@escaping () -> Void) -> Void)?
    func observeFirstShake(completion: @escaping () -> Void) {
        observeFirstShakeCompletionCallsCount += 1
        observeFirstShakeCompletionReceivedCompletion = completion
        observeFirstShakeCompletionReceivedInvocations.append(completion)
        observeFirstShakeCompletionClosure?(completion)
    }
    //MARK: - stopMotionUpdates

    var stopMotionUpdatesCallsCount = 0
    var stopMotionUpdatesCalled: Bool {
        return stopMotionUpdatesCallsCount > 0
    }
    var stopMotionUpdatesClosure: (() -> Void)?
    func stopMotionUpdates() {
        stopMotionUpdatesCallsCount += 1
        stopMotionUpdatesClosure?()
    }
}
class SpeedServiceProtocolMock: SpeedServiceProtocol {
    //MARK: - setSpeed

    var setSpeedRelativePathCallsCount = 0
    var setSpeedRelativePathCalled: Bool {
        return setSpeedRelativePathCallsCount > 0
    }
    var setSpeedRelativePathReceivedArguments: (newValue: Float, relativePath: String?)?
    var setSpeedRelativePathReceivedInvocations: [(newValue: Float, relativePath: String?)] = []
    var setSpeedRelativePathClosure: ((Float, String?) -> Void)?
    func setSpeed(_ newValue: Float, relativePath: String?) {
        setSpeedRelativePathCallsCount += 1
        setSpeedRelativePathReceivedArguments = (newValue: newValue, relativePath: relativePath)
        setSpeedRelativePathReceivedInvocations.append((newValue: newValue, relativePath: relativePath))
        setSpeedRelativePathClosure?(newValue, relativePath)
    }
    //MARK: - getSpeed

    var getSpeedRelativePathCallsCount = 0
    var getSpeedRelativePathCalled: Bool {
        return getSpeedRelativePathCallsCount > 0
    }
    var getSpeedRelativePathReceivedRelativePath: String?
    var getSpeedRelativePathReceivedInvocations: [String?] = []
    var getSpeedRelativePathReturnValue: Float!
    var getSpeedRelativePathClosure: ((String?) -> Float)?
    func getSpeed(relativePath: String?) -> Float {
        getSpeedRelativePathCallsCount += 1
        getSpeedRelativePathReceivedRelativePath = relativePath
        getSpeedRelativePathReceivedInvocations.append(relativePath)
        if let getSpeedRelativePathClosure = getSpeedRelativePathClosure {
            return getSpeedRelativePathClosure(relativePath)
        } else {
            return getSpeedRelativePathReturnValue
        }
    }
}
class SyncServiceProtocolMock: SyncServiceProtocol {
    var isActive: Bool {
        get { return underlyingIsActive }
        set(value) { underlyingIsActive = value }
    }
    var underlyingIsActive: Bool!
    var downloadCompletedPublisher: PassthroughSubject<(String, String, String?), Never> {
        get { return underlyingDownloadCompletedPublisher }
        set(value) { underlyingDownloadCompletedPublisher = value }
    }
    var underlyingDownloadCompletedPublisher: PassthroughSubject<(String, String, String?), Never>!
    var downloadProgressPublisher: PassthroughSubject<(String, String, String?, Double), Never> {
        get { return underlyingDownloadProgressPublisher }
        set(value) { underlyingDownloadProgressPublisher = value }
    }
    var underlyingDownloadProgressPublisher: PassthroughSubject<(String, String, String?, Double), Never>!
    var downloadErrorPublisher: PassthroughSubject<(String, Error), Never> {
        get { return underlyingDownloadErrorPublisher }
        set(value) { underlyingDownloadErrorPublisher = value }
    }
    var underlyingDownloadErrorPublisher: PassthroughSubject<(String, Error), Never>!
    //MARK: - queuedJobsCount

    var queuedJobsCountCallsCount = 0
    var queuedJobsCountCalled: Bool {
        return queuedJobsCountCallsCount > 0
    }
    var queuedJobsCountReturnValue: Int!
    var queuedJobsCountClosure: (() async -> Int)?
    func queuedJobsCount() async -> Int {
        queuedJobsCountCallsCount += 1
        if let queuedJobsCountClosure = queuedJobsCountClosure {
            return await queuedJobsCountClosure()
        } else {
            return queuedJobsCountReturnValue
        }
    }
    //MARK: - observeTasksCount

    var observeTasksCountCallsCount = 0
    var observeTasksCountCalled: Bool {
        return observeTasksCountCallsCount > 0
    }
    var observeTasksCountReturnValue: AnyPublisher<Int, Never>!
    var observeTasksCountClosure: (() -> AnyPublisher<Int, Never>)?
    func observeTasksCount() -> AnyPublisher<Int, Never> {
        observeTasksCountCallsCount += 1
        if let observeTasksCountClosure = observeTasksCountClosure {
            return observeTasksCountClosure()
        } else {
            return observeTasksCountReturnValue
        }
    }
    //MARK: - canSyncListContents

    var canSyncListContentsAtIgnoreLastTimestampCallsCount = 0
    var canSyncListContentsAtIgnoreLastTimestampCalled: Bool {
        return canSyncListContentsAtIgnoreLastTimestampCallsCount > 0
    }
    var canSyncListContentsAtIgnoreLastTimestampReceivedArguments: (relativePath: String?, ignoreLastTimestamp: Bool)?
    var canSyncListContentsAtIgnoreLastTimestampReceivedInvocations: [(relativePath: String?, ignoreLastTimestamp: Bool)] = []
    var canSyncListContentsAtIgnoreLastTimestampReturnValue: Bool!
    var canSyncListContentsAtIgnoreLastTimestampClosure: ((String?, Bool) async -> Bool)?
    func canSyncListContents(at relativePath: String?, ignoreLastTimestamp: Bool) async -> Bool {
        canSyncListContentsAtIgnoreLastTimestampCallsCount += 1
        canSyncListContentsAtIgnoreLastTimestampReceivedArguments = (relativePath: relativePath, ignoreLastTimestamp: ignoreLastTimestamp)
        canSyncListContentsAtIgnoreLastTimestampReceivedInvocations.append((relativePath: relativePath, ignoreLastTimestamp: ignoreLastTimestamp))
        if let canSyncListContentsAtIgnoreLastTimestampClosure = canSyncListContentsAtIgnoreLastTimestampClosure {
            return await canSyncListContentsAtIgnoreLastTimestampClosure(relativePath, ignoreLastTimestamp)
        } else {
            return canSyncListContentsAtIgnoreLastTimestampReturnValue
        }
    }
    //MARK: - syncListContents

    var syncListContentsAtThrowableError: Error?
    var syncListContentsAtCallsCount = 0
    var syncListContentsAtCalled: Bool {
        return syncListContentsAtCallsCount > 0
    }
    var syncListContentsAtReceivedRelativePath: String?
    var syncListContentsAtReceivedInvocations: [String?] = []
    var syncListContentsAtClosure: ((String?) async throws -> Void)?
    func syncListContents(at relativePath: String?) async throws {
        if let error = syncListContentsAtThrowableError {
            throw error
        }
        syncListContentsAtCallsCount += 1
        syncListContentsAtReceivedRelativePath = relativePath
        syncListContentsAtReceivedInvocations.append(relativePath)
        try await syncListContentsAtClosure?(relativePath)
    }
    //MARK: - syncLibraryContents

    var syncLibraryContentsThrowableError: Error?
    var syncLibraryContentsCallsCount = 0
    var syncLibraryContentsCalled: Bool {
        return syncLibraryContentsCallsCount > 0
    }
    var syncLibraryContentsClosure: (() async throws -> Void)?
    func syncLibraryContents() async throws {
        if let error = syncLibraryContentsThrowableError {
            throw error
        }
        syncLibraryContentsCallsCount += 1
        try await syncLibraryContentsClosure?()
    }
    //MARK: - syncBookmarksList

    var syncBookmarksListRelativePathThrowableError: Error?
    var syncBookmarksListRelativePathCallsCount = 0
    var syncBookmarksListRelativePathCalled: Bool {
        return syncBookmarksListRelativePathCallsCount > 0
    }
    var syncBookmarksListRelativePathReceivedRelativePath: String?
    var syncBookmarksListRelativePathReceivedInvocations: [String] = []
    var syncBookmarksListRelativePathReturnValue: [SimpleBookmark]?
    var syncBookmarksListRelativePathClosure: ((String) async throws -> [SimpleBookmark]?)?
    func syncBookmarksList(relativePath: String) async throws -> [SimpleBookmark]? {
        if let error = syncBookmarksListRelativePathThrowableError {
            throw error
        }
        syncBookmarksListRelativePathCallsCount += 1
        syncBookmarksListRelativePathReceivedRelativePath = relativePath
        syncBookmarksListRelativePathReceivedInvocations.append(relativePath)
        if let syncBookmarksListRelativePathClosure = syncBookmarksListRelativePathClosure {
            return try await syncBookmarksListRelativePathClosure(relativePath)
        } else {
            return syncBookmarksListRelativePathReturnValue
        }
    }
    //MARK: - fetchSyncedIdentifiers

    var fetchSyncedIdentifiersThrowableError: Error?
    var fetchSyncedIdentifiersCallsCount = 0
    var fetchSyncedIdentifiersCalled: Bool {
        return fetchSyncedIdentifiersCallsCount > 0
    }
    var fetchSyncedIdentifiersReturnValue: [String]!
    var fetchSyncedIdentifiersClosure: (() async throws -> [String])?
    func fetchSyncedIdentifiers() async throws -> [String] {
        if let error = fetchSyncedIdentifiersThrowableError {
            throw error
        }
        fetchSyncedIdentifiersCallsCount += 1
        if let fetchSyncedIdentifiersClosure = fetchSyncedIdentifiersClosure {
            return try await fetchSyncedIdentifiersClosure()
        } else {
            return fetchSyncedIdentifiersReturnValue
        }
    }
    //MARK: - getRemoteFileURLs

    var getRemoteFileURLsOfTypeThrowableError: Error?
    var getRemoteFileURLsOfTypeCallsCount = 0
    var getRemoteFileURLsOfTypeCalled: Bool {
        return getRemoteFileURLsOfTypeCallsCount > 0
    }
    var getRemoteFileURLsOfTypeReceivedArguments: (relativePath: String, type: SimpleItemType)?
    var getRemoteFileURLsOfTypeReceivedInvocations: [(relativePath: String, type: SimpleItemType)] = []
    var getRemoteFileURLsOfTypeReturnValue: [RemoteFileURL]!
    var getRemoteFileURLsOfTypeClosure: ((String, SimpleItemType) async throws -> [RemoteFileURL])?
    func getRemoteFileURLs(of relativePath: String, type: SimpleItemType) async throws -> [RemoteFileURL] {
        if let error = getRemoteFileURLsOfTypeThrowableError {
            throw error
        }
        getRemoteFileURLsOfTypeCallsCount += 1
        getRemoteFileURLsOfTypeReceivedArguments = (relativePath: relativePath, type: type)
        getRemoteFileURLsOfTypeReceivedInvocations.append((relativePath: relativePath, type: type))
        if let getRemoteFileURLsOfTypeClosure = getRemoteFileURLsOfTypeClosure {
            return try await getRemoteFileURLsOfTypeClosure(relativePath, type)
        } else {
            return getRemoteFileURLsOfTypeReturnValue
        }
    }
    //MARK: - downloadRemoteFiles

    var downloadRemoteFilesForThrowableError: Error?
    var downloadRemoteFilesForCallsCount = 0
    var downloadRemoteFilesForCalled: Bool {
        return downloadRemoteFilesForCallsCount > 0
    }
    var downloadRemoteFilesForReceivedItem: SimpleLibraryItem?
    var downloadRemoteFilesForReceivedInvocations: [SimpleLibraryItem] = []
    var downloadRemoteFilesForClosure: ((SimpleLibraryItem) async throws -> Void)?
    func downloadRemoteFiles(for item: SimpleLibraryItem) async throws {
        if let error = downloadRemoteFilesForThrowableError {
            throw error
        }
        downloadRemoteFilesForCallsCount += 1
        downloadRemoteFilesForReceivedItem = item
        downloadRemoteFilesForReceivedInvocations.append(item)
        try await downloadRemoteFilesForClosure?(item)
    }
    //MARK: - scheduleUpload

    var scheduleUploadItemsCallsCount = 0
    var scheduleUploadItemsCalled: Bool {
        return scheduleUploadItemsCallsCount > 0
    }
    var scheduleUploadItemsReceivedItems: [SimpleLibraryItem]?
    var scheduleUploadItemsReceivedInvocations: [[SimpleLibraryItem]] = []
    var scheduleUploadItemsClosure: (([SimpleLibraryItem]) async -> Void)?
    func scheduleUpload(items: [SimpleLibraryItem]) async {
        scheduleUploadItemsCallsCount += 1
        scheduleUploadItemsReceivedItems = items
        scheduleUploadItemsReceivedInvocations.append(items)
        await scheduleUploadItemsClosure?(items)
    }
    //MARK: - scheduleDelete

    var scheduleDeleteModeCallsCount = 0
    var scheduleDeleteModeCalled: Bool {
        return scheduleDeleteModeCallsCount > 0
    }
    var scheduleDeleteModeReceivedArguments: (items: [SimpleLibraryItem], mode: DeleteMode)?
    var scheduleDeleteModeReceivedInvocations: [(items: [SimpleLibraryItem], mode: DeleteMode)] = []
    var scheduleDeleteModeClosure: (([SimpleLibraryItem], DeleteMode) -> Void)?
    func scheduleDelete(_ items: [SimpleLibraryItem], mode: DeleteMode) {
        scheduleDeleteModeCallsCount += 1
        scheduleDeleteModeReceivedArguments = (items: items, mode: mode)
        scheduleDeleteModeReceivedInvocations.append((items: items, mode: mode))
        scheduleDeleteModeClosure?(items, mode)
    }
    //MARK: - scheduleMove

    var scheduleMoveItemsToCallsCount = 0
    var scheduleMoveItemsToCalled: Bool {
        return scheduleMoveItemsToCallsCount > 0
    }
    var scheduleMoveItemsToReceivedArguments: (items: [String], parentFolder: String?)?
    var scheduleMoveItemsToReceivedInvocations: [(items: [String], parentFolder: String?)] = []
    var scheduleMoveItemsToClosure: (([String], String?) -> Void)?
    func scheduleMove(items: [String], to parentFolder: String?) {
        scheduleMoveItemsToCallsCount += 1
        scheduleMoveItemsToReceivedArguments = (items: items, parentFolder: parentFolder)
        scheduleMoveItemsToReceivedInvocations.append((items: items, parentFolder: parentFolder))
        scheduleMoveItemsToClosure?(items, parentFolder)
    }
    //MARK: - scheduleRenameFolder

    var scheduleRenameFolderAtNameCallsCount = 0
    var scheduleRenameFolderAtNameCalled: Bool {
        return scheduleRenameFolderAtNameCallsCount > 0
    }
    var scheduleRenameFolderAtNameReceivedArguments: (relativePath: String, name: String)?
    var scheduleRenameFolderAtNameReceivedInvocations: [(relativePath: String, name: String)] = []
    var scheduleRenameFolderAtNameClosure: ((String, String) -> Void)?
    func scheduleRenameFolder(at relativePath: String, name: String) {
        scheduleRenameFolderAtNameCallsCount += 1
        scheduleRenameFolderAtNameReceivedArguments = (relativePath: relativePath, name: name)
        scheduleRenameFolderAtNameReceivedInvocations.append((relativePath: relativePath, name: name))
        scheduleRenameFolderAtNameClosure?(relativePath, name)
    }
    //MARK: - scheduleSetBookmark

    var scheduleSetBookmarkRelativePathTimeNoteCallsCount = 0
    var scheduleSetBookmarkRelativePathTimeNoteCalled: Bool {
        return scheduleSetBookmarkRelativePathTimeNoteCallsCount > 0
    }
    var scheduleSetBookmarkRelativePathTimeNoteReceivedArguments: (relativePath: String, time: Double, note: String?)?
    var scheduleSetBookmarkRelativePathTimeNoteReceivedInvocations: [(relativePath: String, time: Double, note: String?)] = []
    var scheduleSetBookmarkRelativePathTimeNoteClosure: ((String, Double, String?) -> Void)?
    func scheduleSetBookmark(relativePath: String, time: Double, note: String?) {
        scheduleSetBookmarkRelativePathTimeNoteCallsCount += 1
        scheduleSetBookmarkRelativePathTimeNoteReceivedArguments = (relativePath: relativePath, time: time, note: note)
        scheduleSetBookmarkRelativePathTimeNoteReceivedInvocations.append((relativePath: relativePath, time: time, note: note))
        scheduleSetBookmarkRelativePathTimeNoteClosure?(relativePath, time, note)
    }
    //MARK: - scheduleDeleteBookmark

    var scheduleDeleteBookmarkCallsCount = 0
    var scheduleDeleteBookmarkCalled: Bool {
        return scheduleDeleteBookmarkCallsCount > 0
    }
    var scheduleDeleteBookmarkReceivedBookmark: SimpleBookmark?
    var scheduleDeleteBookmarkReceivedInvocations: [SimpleBookmark] = []
    var scheduleDeleteBookmarkClosure: ((SimpleBookmark) -> Void)?
    func scheduleDeleteBookmark(_ bookmark: SimpleBookmark) {
        scheduleDeleteBookmarkCallsCount += 1
        scheduleDeleteBookmarkReceivedBookmark = bookmark
        scheduleDeleteBookmarkReceivedInvocations.append(bookmark)
        scheduleDeleteBookmarkClosure?(bookmark)
    }
    //MARK: - scheduleUploadArtwork

    var scheduleUploadArtworkRelativePathCallsCount = 0
    var scheduleUploadArtworkRelativePathCalled: Bool {
        return scheduleUploadArtworkRelativePathCallsCount > 0
    }
    var scheduleUploadArtworkRelativePathReceivedRelativePath: String?
    var scheduleUploadArtworkRelativePathReceivedInvocations: [String] = []
    var scheduleUploadArtworkRelativePathClosure: ((String) -> Void)?
    func scheduleUploadArtwork(relativePath: String) {
        scheduleUploadArtworkRelativePathCallsCount += 1
        scheduleUploadArtworkRelativePathReceivedRelativePath = relativePath
        scheduleUploadArtworkRelativePathReceivedInvocations.append(relativePath)
        scheduleUploadArtworkRelativePathClosure?(relativePath)
    }
    //MARK: - getAllQueuedJobs

    var getAllQueuedJobsCallsCount = 0
    var getAllQueuedJobsCalled: Bool {
        return getAllQueuedJobsCallsCount > 0
    }
    var getAllQueuedJobsReturnValue: [SyncTaskReference]!
    var getAllQueuedJobsClosure: (() async -> [SyncTaskReference])?
    func getAllQueuedJobs() async -> [SyncTaskReference] {
        getAllQueuedJobsCallsCount += 1
        if let getAllQueuedJobsClosure = getAllQueuedJobsClosure {
            return await getAllQueuedJobsClosure()
        } else {
            return getAllQueuedJobsReturnValue
        }
    }
    //MARK: - cancelAllJobs

    var cancelAllJobsCallsCount = 0
    var cancelAllJobsCalled: Bool {
        return cancelAllJobsCallsCount > 0
    }
    var cancelAllJobsClosure: (() -> Void)?
    func cancelAllJobs() {
        cancelAllJobsCallsCount += 1
        cancelAllJobsClosure?()
    }
    //MARK: - cancelDownload

    var cancelDownloadOfThrowableError: Error?
    var cancelDownloadOfCallsCount = 0
    var cancelDownloadOfCalled: Bool {
        return cancelDownloadOfCallsCount > 0
    }
    var cancelDownloadOfReceivedItem: SimpleLibraryItem?
    var cancelDownloadOfReceivedInvocations: [SimpleLibraryItem] = []
    var cancelDownloadOfClosure: ((SimpleLibraryItem) throws -> Void)?
    func cancelDownload(of item: SimpleLibraryItem) throws {
        if let error = cancelDownloadOfThrowableError {
            throw error
        }
        cancelDownloadOfCallsCount += 1
        cancelDownloadOfReceivedItem = item
        cancelDownloadOfReceivedInvocations.append(item)
        try cancelDownloadOfClosure?(item)
    }
    //MARK: - getDownloadState

    var getDownloadStateForCallsCount = 0
    var getDownloadStateForCalled: Bool {
        return getDownloadStateForCallsCount > 0
    }
    var getDownloadStateForReceivedItem: SimpleLibraryItem?
    var getDownloadStateForReceivedInvocations: [SimpleLibraryItem] = []
    var getDownloadStateForReturnValue: DownloadState!
    var getDownloadStateForClosure: ((SimpleLibraryItem) -> DownloadState)?
    func getDownloadState(for item: SimpleLibraryItem) -> DownloadState {
        getDownloadStateForCallsCount += 1
        getDownloadStateForReceivedItem = item
        getDownloadStateForReceivedInvocations.append(item)
        if let getDownloadStateForClosure = getDownloadStateForClosure {
            return getDownloadStateForClosure(item)
        } else {
            return getDownloadStateForReturnValue
        }
    }
    //MARK: - hasUploadTask

    var hasUploadTaskForCallsCount = 0
    var hasUploadTaskForCalled: Bool {
        return hasUploadTaskForCallsCount > 0
    }
    var hasUploadTaskForReceivedRelativePath: String?
    var hasUploadTaskForReceivedInvocations: [String] = []
    var hasUploadTaskForReturnValue: Bool!
    var hasUploadTaskForClosure: ((String) async -> Bool)?
    func hasUploadTask(for relativePath: String) async -> Bool {
        hasUploadTaskForCallsCount += 1
        hasUploadTaskForReceivedRelativePath = relativePath
        hasUploadTaskForReceivedInvocations.append(relativePath)
        if let hasUploadTaskForClosure = hasUploadTaskForClosure {
            return await hasUploadTaskForClosure(relativePath)
        } else {
            return hasUploadTaskForReturnValue
        }
    }
    //MARK: - setLibraryLastBook

    var setLibraryLastBookWithCallsCount = 0
    var setLibraryLastBookWithCalled: Bool {
        return setLibraryLastBookWithCallsCount > 0
    }
    var setLibraryLastBookWithReceivedRelativePath: String?
    var setLibraryLastBookWithReceivedInvocations: [String?] = []
    var setLibraryLastBookWithClosure: ((String?) async -> Void)?
    func setLibraryLastBook(with relativePath: String?) async {
        setLibraryLastBookWithCallsCount += 1
        setLibraryLastBookWithReceivedRelativePath = relativePath
        setLibraryLastBookWithReceivedInvocations.append(relativePath)
        await setLibraryLastBookWithClosure?(relativePath)
    }
}
