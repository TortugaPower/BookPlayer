# BookPlayer (iOS / watchOS)

Open-source audiobook player for iOS and watchOS. Swift, **hybrid UIKit-Coordinators + SwiftUI (MVVM)**.
Companion to the Android app; both share the **BookPlayer backend** (auth, per-user cloud sync, subscriptions).
Handles **offline audio playback, background/lock-screen playback, cloud sync, auth, and paid entitlements** —
so the highest-severity defects are in **memory/concurrency, player & AVAudioSession lifecycle, thread-correct
persistence, and auth/entitlement handling**. Default branch: **`develop`**.

> This file is the **architecture & conventions ground truth**. It is read by human reviewers and by the
> automated PR reviewer (`.github/workflows/claude-review.yml`, which loads `.github/claude/review-guide.md`
> as its rubric and this file as the codebase reference). Keep it accurate; a stale claim here becomes a bad
> review. When you change an invariant described here, update this file in the same PR.

---

## ⚠️ Repo layout gotcha (read this first)

The on-disk tree is deeply misleading. Before judging *where* code should live, know this:

- **Main app source lives under the nested `BookPlayer/BookPlayer/`** directory: `Player/`, `Settings/`,
  `Profile/`, `Library/`, `Search/`, `Import/`, `Loading/`, `SecondOnboarding/`, `Coordinators/`, `Services/`,
  `Utils/`, `AppIntents/`, and the media-server integrations `Jellyfin/`, `AudiobookShelf/`, `Hardcover/`.
- **The `BookPlayerKit` framework compiles the top-level `Shared/` folder.** The `BookPlayerKit/` directory
  itself only holds `BookPlayerKit.h` + `Info.plist`. Everything cross-target lives in `Shared/` and is `public`.
- **`Shared/` is compiled into BOTH `BookPlayerKit` (iOS) and `BookPlayerWatchKit` (watchOS).** Every file in
  `Shared/` therefore has **two** `PBXBuildFile` entries — one per framework. Adding a `Shared/` file to only
  one target breaks the watch build.
- **The top-level `Player/`, `Services/`, `Coordinators/`, `Library/` folders are EMPTY STUBS — ignore them.
  Never add files there.** Real code is under `BookPlayer/BookPlayer/…` or `Shared/`.
- **Dead code to ignore:** `BookPlayer/RootViewController.swift` references `BaseViewController`/`BaseViewModel`,
  which **do not exist** in the repo — it is orphaned, not part of the live SwiftUI flow.

---

## Targets & dependency rule

Nine native targets in `BookPlayer.xcodeproj` (no `Package.swift`, no app `.xcworkspace`):

| Target | Product / type | Role | Source |
|---|---|---|---|
| `BookPlayer` | "Audiobook Player" · app | iOS app | `BookPlayer/BookPlayer/…` |
| `BookPlayerKit` | framework (iOS) | Shared framework | top-level `Shared/` |
| `BookPlayerWatchKit` | framework (watchOS) | Shared framework | top-level `Shared/` (same files) |
| `BookPlayerWatch` | app (watchOS) | Watch app | `BookPlayerWatch/` |
| `BookPlayerWidgetsPhone` | app-extension | iOS widgets | `BookPlayerWidgets/` (`Phone/` + `Shared/`) |
| `BookPlayerWidgetsWatch` | app-extension | watchOS widgets/complications | `BookPlayerWidgets/Shared/` |
| `BookPlayerIntents` | app-extension | **legacy SiriKit** `INExtension` | `BookPlayerIntents/` |
| `BookPlayerShareExtension` | app-extension | Share-sheet import | `BookPlayerShareExtension/` |
| `BookPlayerTests` | "Audiobook PlayerTests" · unit-test | Unit + perf tests | `BookPlayerTests/` |

**Dependency rule:** app → `BookPlayerKit` (`import BookPlayerKit`). `Shared/` must **not** import app-layer
types — that breaks the framework boundary and is a 🔴 finding. Watch/shared code selects the framework with:

```swift
#if os(watchOS)
import BookPlayerWatchKit
#else
import BookPlayerKit
#endif
```

Do **not** "fix" or collapse these conditional imports — they are the mechanism that lets one shared codebase
compile for both platforms. `BookPlayerIntents` (SiriKit `Intents`) is **legacy** and distinct from the modern
App Intents in the top-level `BookPlayer/BookPlayer/AppIntents/` folder — don't conflate them.

### Dependencies (SPM, declared inside `project.pbxproj`)

RevenueCat (`purchases-ios`, ~5.33), Sentry (`sentry-cocoa`, **exact 8.36.0**), Kingfisher (~7.9),
JellyfinAPI (`jellyfin-sdk-swift`, ~0.4), MarqueeLabel (~4.0.5), DeviceKit (~5.1),
IDZSwiftCommonCrypto (~0.13.1), Themeable (~3.0), ZipArchive (~2.3), DirectoryWatcher (~2.8.6).
`BlurHashDecode.swift` is vendored (SwiftLint-excluded). RevenueCat + Kingfisher link into the **frameworks**;
most others link into the **app**. SwiftLint runs as a build-phase run-script; **Sourcery is run manually** (not
a build phase) and its output is committed.

---

## Build, CI & tooling (what the tools own — don't hand-police it)

- **CI** (`.github/workflows/ci.yml`): runner `macos-26`, **Xcode 26.4**, `build-for-testing` then
  `test-without-building` with the **`Unit Tests`** test plan, `-only-testing:BookPlayerTests`, simulator
  `iPhone 17`. It first copies `Debug.template.xcconfig` → `Debug.xcconfig`. Triggers on push to `main`/`develop`
  and PRs to `develop`.
- **Lint/format is enforced by tools — do NOT flag style they own.** `.swiftlint.yml` **disables**: `line_length`,
  `identifier_name`, `type_name`, `type_body_length`, `file_length`, `nesting`, `force_try`, `trailing_comma`,
  `trailing_newline`, `trailing_whitespace`, `switch_case_alignment`, `private_over_fileprivate`, `opening_brace`,
  `large_tuple`, `orphaned_doc_comment`, `todo`. Excludes `BookPlayer/Generated/AutoMockable.generated.swift`,
  `BookPlayerTests`, `BlurHashDecode.swift`.
- **SwiftFormat** (`.swiftformat`): 4-space indent, explicit `self` (`--self insert`), `--wraparguments afterfirst`,
  `--ifdef noindent`. A second Apple `swift-format` config (`.swift-format`) says 2-space / 120-col. **The two
  formatters disagree on indentation — do not flag indentation width.**
- **`force_try` / `try!` is allowed by lint in general.** Only flag it on **untrusted/remote/decoded data**
  (network, JSON, S3, server payloads), where a bad payload crashes the app.

---

## Architecture

### Boot sequence (UIKit → SwiftUI handoff)

1. `BookPlayer/AppDelegate.swift` (`@UIApplicationMain`): registers defaults, notification observers,
   background-refresh tasks, `MPRemoteCommandCenter` targets, RevenueCat, Sentry, and calls
   `AppServices.shared.setupCoreServices()` (async DI). It does **not** create the window (scene-based).
2. `BookPlayer/SceneDelegate.swift`: strongly owns `startingNavigationController` and a
   `LoadingCoordinator`; builds the `UIWindow`, calls `coordinator.start()`, sets the nav controller as root.
3. `LoadingViewController` → `LoadingViewModel.initializeDataIfNeeded()` → `DataInitializerCoordinator`
   (`@MainActor`) awaits `AppServices.shared.setupCoreServicesTask`, handles CoreData errors / backup restore,
   runs one-time first-launch defaults, then fires `onFinish`.
4. `LoadingCoordinator.didFinishLoadingSequence()` force-unwraps `AppServices.shared.coreServices!`, builds
   `MainCoordinator`, retains it, and calls `start()`.
5. `MainCoordinator.start()` hosts SwiftUI `MainView` inside `AppHostingViewController` (a `UIHostingController`
   subclass that only overrides orientation) and **modally presents it full-screen** over the loading nav
   controller. `MainView` is a `TabView` (Library / Profile / Settings [+ iOS 26 Search]) with a mini-player
   overlay and a `.fullScreenCover` for the player.

**Invariant:** the strong chain `SceneDelegate → LoadingCoordinator.mainCoordinator → MainCoordinator` is the
only thing keeping `MainCoordinator` alive — don't sever it. Boot ordering matters: several call sites
force-unwrap `AppServices.shared.coreServices!`, relying on `DataInitializerCoordinator` having awaited setup
first. Reordering boot risks a launch crash.

### Dependency injection — `BookPlayer/Utils/AppServices.swift`

- `@MainActor final class AppServices` with `static let shared` + `private init()`. Owns the async
  `setupCoreServicesTask`, the `DatabaseInitializer`, and a shared `PlayerState`.
- `CoreServices` (`BookPlayer/Utils/CoreServices.swift`) is a struct of exactly **10 services**: `accountService`,
  `dataManager`, `hardcoverService`, `libraryService`, `playbackService`, `playerLoaderService`, `playerManager`,
  `preferencesService` (`PreferencesSyncService`), `syncService`, `watchService` (`PhoneWatchConnectivityService`).
- **Two-step `init()` + `setup(...)` DI pattern:** services are created empty then configured, e.g.
  ```swift
  let service = LibraryService()
  service.setup(dataManager: dataManager, audioMetadataService: audioMetadataService)
  ```
  A new service should follow this pattern and be wired through `AppServices`/`CoreServices` — not instantiated
  ad hoc in a view. (`PlayerManager` and `PhoneWatchConnectivityService` take everything via `init`.)
- **Services → coordinators:** `CoreServices` is passed whole into `MainCoordinator.init(...)`, which also builds
  coordinator-scoped services (`ImportManager`, `ListSyncRefreshService`, `SingleFileDownloadService`,
  `JellyfinConnectionService`, `AudiobookShelfConnectionService`).
- **Services → SwiftUI:** `ObservableObject`s (`playerManager`, `importManager`, `singleFileDownloadService`,
  `listSyncRefreshService`) via `.environmentObject`; the rest via `.environment(\.key, …)`. The environment keys
  live in `BookPlayer/Utils/Extensions/Environment+BookPlayer.swift` (`@Entry`). **Each `@Entry` default is a
  throwaway placeholder (an un-`setup()` service).** A view that reads the environment default instead of the
  injected instance silently gets a non-functional service — verify real injection by `MainCoordinator`.
- **App Intents DI:** only `playerLoaderService` and `libraryService` are registered via
  `AppDependencyManager.shared.add(...)` in `setupCoreServices()`. The **extension** targets consume them with
  `@Dependency` (under `#if !MAIN_APP`); the **main app** instead resolves via
  `await AppServices.shared.awaitCoreServices()`. A new `@Dependency` type must be `add()`-ed or intents trap.

### Coordinators — `BookPlayer/Coordinators/`

- `@MainActor protocol Coordinator: AnyObject { var flow: BPCoordinatorPresentationFlow; func start() }`.
- `BPCoordinatorPresentationFlow` has three concrete variants (factory sugar in parens): `BPPushPresentationFlow`
  (`.pushFlow`), `BPModalPresentationFlow` (`.modalFlow`), `BPModalOnlyPresentationFlow` (`.modalOnlyFlow`, whose
  `navigationController` getter is a `fatalError` trap). All back-references (`navigationController`,
  `presentingController`) are **`unowned`** — presenting a flow whose presenter was dismissed crashes.
- Live coordinators: `MainCoordinator` (the SwiftUI bridge — a `NSObject`, **not** `Coordinator`-conforming,
  also `PurchasesDelegate`/`Themeable`/`AlertPresenter`), `LoadingCoordinator`, `DataInitializerCoordinator`,
  `ImportCoordinator`, `SecondOnboardingCoordinator`, `SupportFlowCoordinator`. **`LibraryListCoordinator` /
  `PlayerCoordinator` / `ItemListCoordinator` no longer exist** — those flows are SwiftUI now.
- `MainCoordinator.importCoordinator` is **`weak`** — the presented VC/flow must retain the import coordinator.
- Keep new coordinators and view models `@MainActor`.

### ViewModels

- **SwiftUI-era (dominant):** `@MainActor class XViewModel: XViewModelProtocol` where the protocol is
  `@MainActor …: ObservableObject`. VMs live **next to their view** in the feature folder. **Services are
  constructor-injected**, sourced from the view's `@Environment`. Navigation uses `var onTransition:
  BPTransition<Routes>?` with a nested `enum Routes` (`BPTransition<T> = (T) -> Void`).
- **UIKit-era (legacy, mostly `Loading*`):** `MVVMControllerProtocol` + `@MainActor ViewModelProtocol` with a
  `weak var coordinator`. The generic `BaseViewController`/`BaseViewModel` base classes are **not in the repo**.

### NotificationCenter cross-cutting bus

Custom `Notification.Name`s (namespaced with the bundle id at runtime) are the app ⇄ `BookPlayerKit` ⇄ Watch ⇄
CarPlay event bus. Declared in `Shared/Extensions/Notification+BookPlayerKit.swift` (framework-wide):
`.chapterChange`, `.bookReady`, `.bookPlayed`, `.bookPaused`, `.bookEnd`, `.bookPlaying`, `.accountUpdate`,
`.logout`, `.messageReceived`, `.folderProgressUpdated`, `.uploadProgressUpdated`, `.uploadCompleted`,
`.listeningProgressChanged`; and app-internal ones in `BookPlayer/Utils/Extensions/Notification+BookPlayer.swift`.

- **`PlayerManager` is the dominant publisher** of playback events; `PhoneWatchConnectivityService` and
  `CarPlayManager` are the dominant cross-target subscribers; `AccountService` is the auth/account hub.
- **`.logout`** (posted by `AccountService.logout()`) fans out teardown to `SyncService`,
  `PreferencesSyncService`, and Watch/Profile views. **`.accountUpdate`** propagates subscription state.
- Because these names cross target/process boundaries, **renaming a name or its raw string silently breaks
  cross-process delivery** — treat renames as behavior changes.

---

## Persistence — CoreData **and** SwiftData (two stores, two locations)

### Library data = CoreData — `Shared/CoreData/`

- **Store lives in the App Group container:** `containerURL(forSecurityApplicationGroupIdentifier:
  Constants.ApplicationGroupIdentifier)! + "BookPlayer.sqlite"` (shared with widgets/watch/extension). The
  force-unwrap crashes if the App Group entitlement is misconfigured.
- `CoreDataStack.swift`: `shouldInferMappingModelAutomatically = false` (migrations are **manual**),
  `shouldMigrateStoreAutomatically = true`. `viewContext` for UI reads; a **single cached** lazy
  `backgroundContext` for background work — both `automaticallyMergesChangesFromParent = true`. `DataManager` is
  the facade (`getContext()`, `getBackgroundContext()`, `saveSyncContext`, debounced `scheduleSaveContext`).
- **`saveContext` `fatalError`s on any save failure** — feeding it inconsistent state (e.g. a unique-constraint
  conflict) is a hard crash. **No merge policy is set anywhere** → the default `NSErrorMergePolicy` turns write
  conflicts into crashes rather than reconciling them.
- **Never pass an `NSManagedObject` across threads/contexts or out of a service.** Convert to a thread-safe value
  snapshot first (`Shared/CoreData/Lightweight-Models/`): `SimpleLibraryItem`, `SimpleChapter`, `SimpleBookmark`,
  `SimpleTheme`, `SimpleAccount`, `SimplePlaybackRecord`, `SimpleHardcoverBook`, `SimpleItemType`, `LibraryItemRef`,
  `PlayableChapter`. **`PlayableItem` is the one exception — a `final class: NSObject` (mutable, `Codable`), not
  an immutable struct** — scrutinize its mutation/threading.
- Entities (`Shared/CoreData/Backed-Models/`): abstract `LibraryItem` (its `encode`/`init(from:)` `fatalError` —
  concrete subclasses `Book`/`Folder` must be used), plus `Library`, `Bookmark`, `Chapter`, `Account`, `Theme`,
  `PlaybackRecord`, `HardcoverBook`. `ItemType: Int16 { folder, bound, book }`.
- **Migration is manual and staged** (`Shared/CoreData/Migrations/DataMigrationManager.swift` + `DBVersion.swift`,
  currently `v1…v11`, current model `Audiobook Player 11`). It migrates **one version at a time** using explicit
  `.xcmappingmodel`s where present (`v1→v2 … v3→v4`, `v7→v8 … v10→v11`; the v4–v7 hops rely on inference). A model
  change requires: **(1)** new `.xcdatamodel` version + bump `.xccurrentversion`; **(2)** new `DBVersion` case +
  `model()`; **(3)** a mapping model registered in `mappingModelName()` (inference is OFF, so anything
  non-trivial fails without one); **(4)** any custom data population added to the post-migration step; **(5)**
  bundled resources. `DatabaseInitializer` + `DatabaseBackupService` are the only safety net for a failed
  migration (the migrator deletes the old store before moving the new one into place — interruption = data loss).

### Sync task queue = SwiftData — `Shared/SwiftData/`

- `TasksDataManager.swift` owns the `ModelContainer`. **Store is `applicationSupportDirectory/bp-synctasks.sqlite`
  — the app-support dir, NOT the App Group**, separate from the CoreData store. CloudKit disabled.
  `container = try! ModelContainer(...)` — **`try!` crashes on any container/migration failure.**
- Versioned schema: `SchemaV1` (10 models) → `SchemaV2` (11 models, adds `MatchUuidsTaskModel` + a `uuid` field).
  App code always uses the V2 typealiases. `@Model` types: `SyncTasksContainer`, `SyncTaskReferenceModel`
  (`@Attribute(.unique) id`), and per-job payload models.
- `MigrationPlan.swift` (`SchemaMigrationPlan`) has a **custom `v1ToV2` stage that reads UUIDs out of the CoreData
  `LibraryItem` table** — it requires `MigrationPlan.injectedCoreDataContext` to be set first, else
  **`fatalError`**. This is the one coupling between the two stores; set it before the `ModelContainer` is built.
- **`ModelContext` is per-actor and not `Sendable`.** All task-queue reads/writes go through
  `public actor SyncTasksStorage: ModelActor` (`Shared/Services/Sync/SyncTasksStorage.swift`) with a single
  confined `ModelContext`. Do not share/pass a `ModelContext` across actors or threads.
- **Realm is gone** (Realm → SwiftData migration is complete). Only inert remnants remain
  (`DataManager.getSyncTasksRealmURL()` is dead; a stale comment in `LibraryService`). Don't reintroduce it.

---

## Player · audio · sleep timer — `BookPlayer/Player/`

`PlayerManager.swift` is `final class PlayerManager: NSObject, PlayerManagerProtocol, ObservableObject` (~1500
lines). It is the highest-risk file in the app.

- **Exactly one `AVPlayer` at a time** (`var audioPlayer`). It is **recreated** via `setupPlayerInstance()` on
  `mediaServicesWereReset` and on `.failed` status. Recreation must re-add the 1-second periodic time observer
  (removed first, or it leaks onto an orphaned player) and re-bind the time-control passthrough.
- **Named single-purpose cancellables**, each `.cancel()`'d before rebind (distinct from the multi-sink
  `disposeBag`): `timeControlSubscription` (bridges the recreatable player's `timeControlStatus` into a stable
  `CurrentValueSubject` so `isPlaying` observers survive recreation), `playableChapterSubscription`,
  `isPlayingSubscription`, `nowPlayingClaimSubscription`. Match this pattern; don't convert a named rebind-able
  subscription into a `disposeBag` entry.
- **Invariant — every `currentItem` reassignment must be followed by `bindPlayableChapterSubscription`** (3 call
  sites: `load`, `loadRemoteURLAsset`, `reloadCurrentItem`). Missing it silently breaks the end-of-chapter sleep
  timer and the Now Playing chapter title (the `.chapterChange` notification is posted from that sink).
- **KVO on `AVPlayerItem.status`** is balanced via `observeStatus` didSet + a `hasObserverRegistered` guard;
  nulling the player item resets the guard. An imbalance crashes on `removeObserver`.
- **AVAudioSession:** activated in `play()` (`.playback` / `.spokenAudio`); deactivated ~0.1s after `.paused`
  (delay avoids clipping). Interruption observer is **kept** on `.began` (so `.ended`+`.shouldResume` can resume)
  and removed on user pause/stop. `mediaServicesWereReset` re-applies the category and recreates the player.
  **Session-activation failure `fatalError`s in production** (only downgraded to a Sentry capture on TestFlight) —
  a real crash surface.
- **Background task pairing** lives in `AppServices.loadAndKeepAlive(...)`:
  `beginBackgroundTask(withName: "streaming-playback")` must be matched by `endBackgroundTask` on **all three
  paths** — error, success, and the expiration handler — guarded by the `.invalid` sentinel to avoid a
  double-end. Any new begin without a matching end on every path (incl. errors) is a 🔴 leak/expiration crash.
- **`MPRemoteCommandCenter`** targets are wired **once** in `AppDelegate.setupMPRemoteCommands()`
  (play/pause/toggle, skip fwd/back, change-position); re-adding targets duplicates actions.
  `MPNowPlayingInfoCenter` is pushed after every relevant mutation.
- `SleepTimer.swift` is a **singleton** (`.shared`) with `@Published state` (`.off / .countdown / .endOfChapter`).
  Countdown uses a `Timer.publish` subscription; `.endOfChapter` observes `.chapterChange`/`.bookEnd`. `reset()`
  cancels the subscription and removes observers, and `setTimer` always resets first. It emits three publishers
  consumed by `PlayerManager` (threshold volume-fade, end→pause, turned-on→`.sleep` bookmark; shake-to-resume via
  `ShakeMotionService`).
- Related services (protocols marked `/// sourcery: AutoMockable`): `SpeedService` (per-book vs global speed),
  `ShakeMotionService`, `PlayerLoaderService`, `WidgetReloadService`. `PlayerManagerProtocol` is AutoMockable but
  its mock does **not** reproduce `ObservableObject`/`@Published` — Combine-dependent tests need the concrete class.

---

## Networking · sync · downloads — `Shared/Network/`, `Shared/Services/Sync/`

- `NetworkClient.swift` (URLSession): base URL from Info.plist config (`scheme`/`domain`/`port`). **Bearer token
  pulled from Keychain (`.token`) per request** — but only when `useKeychain == true` (the default). Errors map
  to `BookPlayerError` (`4xx` decode `ErrorResponse` → `.networkError`/`.networkErrorWithCode`, `5xx` →
  `.networkError`). Decoder is `.iso8601`.
- **The bearer token must never be attached to S3/presigned or third-party (Jellyfin/ABS/Hardcover) URLs.**
  Uploads to S3 presigned PUTs use `useKeychain: false` (the URL carries its own auth); media-server calls use
  their own connection tokens. Any new `request(url:...)` must set `useKeychain` deliberately — the default
  `true` attaches the JWT to whatever host is passed.
- **Background `URLSession`s** (`Shared/Network/BPURLSession.swift`): two sessions (`.background` and
  `.background.cellular`) chosen by the `allowCellularData` default; downloads via `BPDownloadURLSession`.
- `SyncService.swift` is `@Observable`. **`isActive` is `public private(set)` and must be mutated only via
  `updateSyncEnabled(_:)` / `logout()`** (both hop to `@MainActor`). It is driven by `.logout` (→ teardown, clears
  scheduled-contents flag, resets jobs) and `.accountUpdate` (→ `updateSyncEnabled(hasSyncEnabled())`)
  notifications. A `teardownTask` is **awaited** at the top of the sync-contents entry points so a fast
  logout→login can't let a late `resetAllJobs()` wipe freshly-scheduled jobs — preserve this ordering. Every
  `schedule*` method short-circuits on `guard isActive`.
- **Sync = the `pro` entitlement only** (see below). Job types (`SyncJobType`): `upload, update, move,
  renameFolder, delete, shallowDelete, setBookmark, deleteBookmark, uploadArtwork, matchUuid`.
- **Download verification:** `verifyDownloadedFile` rejects truncated files by comparing `AVURLAsset` duration to
  the stored duration (tolerance `max(2, expected*0.02)`); completion is broadcast only after verification.
  Don't skip it — it prevents promoting a truncated book.

---

## Auth · secrets · Keychain · subscriptions

### Secrets / config: xcconfig → Info.plist → `Configuration`

- `BuildConfiguration/*.xcconfig` define `BP_*` keys; `Info.plist` substitutes them (`$(BP_…)`);
  `Shared/Configuration.swift` (`ConfigurationKeys`) reads them. **`Bundle.configurationValue(for:)` uses `try!`
  — a missing key crashes at launch.** Keys: API scheme/domain/port, bundle id, RevenueCat key, Sentry DSN,
  `BP_MOCKED_BEARER_TOKEN`.
- **`Debug.xcconfig` and `Release.xcconfig` are gitignored and hold the working-tree real values —
  never commit or overwrite them.** Nuance a reviewer should know: `Debug.xcconfig` is untracked and holds real
  prod secrets; `Release.xcconfig` is *also* gitignored **but is already tracked** with placeholder values
  (`replace.me`) — CI (`ci_scripts/ci_post_clone.sh`) rewrites it from Xcode Cloud env vars at build time. A new
  secret must be added to **the template (`Debug.template.xcconfig`) + the CI script + `Info.plist` +
  `ConfigurationKeys`** in lockstep, never inlined — or the `try!` crashes Release builds. Hardcoded API keys /
  tokens / Sentry DSN / RevenueCat key are a 🔴 finding.
- **Test-account backdoor:** `AccountService.loginTestAccount(...)` hardcodes a real Apple userId/email and sets
  `hasSubscription = true`, reached via `BP_MOCKED_BEARER_TOKEN`. It must stay inert (empty token) in production.

### Keychain — `Shared/Services/KeychainService.swift`

- `kSecClassGenericPassword`, service = the bundle identifier, accessibility
  **`kSecAttrAccessibleAfterFirstUnlock`** (so background sync/downloads work while locked). Stores JWT `.token`,
  `.jellyfinConnection`, `.audiobookshelfConnection`, `.hardcoverToken`.
- **Correction to older docs: the Keychain is NOT scoped via an App Group / `kSecAttrAccessGroup`** — there is no
  access group set; sharing relies on the default app access group. (The App Group
  `group.$(BP_BUNDLE_IDENTIFIER).files` is used for `UserDefaults.sharedDefaults` and file storage, **not** the
  Keychain.)
- Every mutation emits `valueUpdatedPublisher.send((key, deleted:))`; `HardcoverService` observes it to
  start/stop tracking on token changes.

### Subscriptions & entitlements — `Shared/Services/Account/AccountService.swift`

- RevenueCat entitlements `AccessLevel { free, plus, pro }`. `hasSyncEnabled()` = `pro` entitlement active;
  `hasPlusAccess()` = `plus` OR `pro` (with a local `donationMade` fallback when cached info is nil).
- **These are client-side cached RevenueCat reads — UX gating only.** Never let `hasSyncEnabled()`/`isActive`
  become the sole gate for a server-billed resource; the server validates the entitlement. Purchases are guarded
  by `AppEnvironment.isPurchaseEnabled` (disabled on TestFlight).
- `login(...)` stores the JWT then `Purchases.logIn(revenuecatId ?? appleUserId)` (server's RC id wins).
  `logout()` removes the token, resets the account, `Purchases.logOut`, and posts `.logout`.
- Auth entry points: Apple/Google sign-in (`Profile/Login/`), Passkeys/WebAuthn (`Profile/Passkey/`, relying
  party `bookplayer.app`, endpoints `/v1/passkey/*`), Watch credential transfer.

---

## Media-server integrations

All three store secrets in the **Keychain** (never `UserDefaults`), persist custom headers alongside connection
data, and share the error type `MediaServerIntegration/IntegrationError.swift` (note `sessionExpired(serverName:)`
+ `isSessionExpired`). Jellyfin & AudiobookShelf share the `MediaServerIntegration/` protocol + UI layer.

- **Session-expiry contract:** a 401/403 from an **authenticated** call maps to `sessionExpired(serverName:)` (a
  recoverable "sign in again" path that **preserves** the connection). Pre-sign-in probes (`findServer`/`ping`)
  must **bypass** this mapping — otherwise an unrelated saved server gets mis-thrown into re-auth, and users land
  in the duplicate-connection trap.
- **Jellyfin** (`Jellyfin/`, `@MainActor @Observable JellyfinConnectionService`, backed by `jellyfin-sdk-swift`):
  add-server validates via a transient `PendingServer` **without mutating the live `client`**; `rebuildClient` is
  the single client-construction choke point and must forward `customHeaders`; the `JellyfinHeaderInjector` must
  **never overwrite `Authorization`** (so Cloudflare-Access headers can't clobber the token). Downloads are
  delegated to `SingleFileDownloadService`.
- **AudiobookShelf** (`AudiobookShelf/`, `@MainActor @Observable`, hand-rolled URLSession): `Authorization: Bearer`
  applied *after* custom headers; re-auth/delete fire a fire-and-forget `/logout` to avoid orphan tokens; image
  URLs keep the token in the header (Kingfisher `requestModifier`), not the URL, so a rotated token can't poison
  the disk cache. **URL-encoding footgun:** the `filter` param is manually percent-encoded (`+`→`%2B`, `/`→`%2F`)
  because ABS/Express corrupts `+` in a query value — don't route it through `URLQueryItem`.
- **Hardcover** (`Hardcover/`, `@Observable HardcoverService`, GraphQL): two-way **reading-progress** sync, not a
  media server. Status `HardcoverBook.Status { local=0, library=1, reading=2, read=3 }`; **only 1/2/3 are ever
  POSTed** (`.local` is a local-only marker). Monotonic guards prevent backwards writes; auto-match on import has
  explicit duplicate detection; API failures are log-and-swallowed so a Hardcover outage never blocks local
  playback. Token is Keychain `.hardcoverToken`; no token → subscriptions torn down.

---

## Import · library · search · settings

- **Import** (`Import/`): files enter from the document picker / drag-drop, the **share extension** (writes into
  the App Group folder, picked up by a `DirectoryWatcher`), URL-open/intents, and remote downloads — all
  converging on `ImportManager` (`ObservableObject`). `ImportOperation` (async `Operation`, thread-safe via a
  barrier `lockQueue`) detects folder organization, handles zip/lpf (SSZipArchive), collision-safe-copies into the
  Processed folder, and uses balanced `start/stopAccessingSecurityScopedResource`. **A copy failure
  `SentrySDK.capture`s then `fatalError`s** — an intentional but real crash surface for bad imports. Book/folder
  records are created via `LibraryService.createBook/createFolder`; artwork is extracted lazily by
  `ArtworkService`, not inline. App-managed source files are removed after copy.
- **Library** (`Library/ItemList/…`, backed by `Shared/Services/LibraryService.swift`): the main list, folders,
  and drag-drop reordering. **Ordering model (query-time sort):** `orderRank` means ONLY the user's custom
  arrangement (written by drag/reverse/Custom-freeze/one-shot sorts and by sync; never by an automatic sort).
  An automatic sticky sort is applied at fetch time — `resolveSortDescriptors` in `LibraryService` maps the
  location's effective sort to `SortType.sortDescriptors` (`localizedStandardCompare:` + `orderRank` tie-break);
  sync may overwrite ranks freely — the rendered order only follows ranks where the effective sort resolves to
  rank order: Custom, `.unresolved`/bound locations, and any target with no `preferencesService` wired.
  **watchOS is such a target** (only the iOS app assigns `preferencesService`), so the watch renders rank order
  for a folder the phone renders rule-sorted — a known, deliberate platform fork (same as Android Wear). Rank
  updates always sync (no auto-sort suppression exists anymore). **Both mutation invariants live in
  `freezeVisibleOrder(at:transform:)`** — the single core of `reorderItems`/`reverseContents`/
  `adoptCurrentOrderAsCustom`: (1) capture-before-flip — the effective (visible) descriptors are resolved
  **before** the pref flips to `.custom`, else the mutation acts on rank order instead of what the user sees;
  (2) the `.custom` pref write precedes the rank rebuild so the next fetch doesn't re-sort the user's
  arrangement away. Route any new user-arrangement rank mutation through that helper (the one-shot
  materialization for `.unresolved` locations in `sortContents` is the deliberate exception — it has no pref
  key to flip). Playback prev/next walks
  `getOrderedSiblings` (visible order, lightweight entries), not rank cursors. On logout,
  `PreferencesSyncService` freezes automatically-sorted locations into ranks before wiping `library_sort:*`,
  so sign-out doesn't visibly re-scramble the library.
  UI reads on `viewContext`, background on `backgroundContext`, only `Simple*` snapshots cross back to UI.
- **Search** (`Search/`): **local-only** CoreData search (`LibraryService.searchAllBooks`), 0.3s debounce,
  results grouped by parent folder. Remote search lives in the integration view models, **not** here — don't
  expect network calls in `Search/`.
- **Settings** (`Settings/`): SwiftUI `Form` + `SettingsScreen` route enum; gating reads
  `accountService.accessLevel`. Integrations entry is `SettingsIntegrationsSectionView` → `MediaServersView` /
  Hardcover.

---

## Conventions

- **Prefer native Apple / SwiftUI APIs** over custom implementations.
- **Localization:** every user-facing string via `"key".localized`
  (`Shared/Extensions/String+BookPlayer.swift` → `NSLocalizedString`; no SwiftGen/`L10n`). New keys go in
  `BookPlayer/Base.lproj/Localizable.strings`; ~27 locales are Lokalise-managed — flag a **missing Base key** or a
  hardcoded literal, but do **not** nitpick the wording of existing translations.
- **Accessibility is first-class** (audiobook app, many low-vision users). New interactive SwiftUI controls need
  `accessibilityLabel` (and `accessibilityValue` where stateful) and must respect Dynamic Type — use the
  `bpFont(_:)` modifier, not fixed `.font(.system(size:))`. `Services/VoiceOverService.swift` builds VoiceOver
  strings; live content uses the `DynamicAccessibilityLabel` mechanism, not a static snapshot.
- **Mocks are Sourcery `AutoMockable`:** mark a protocol `/// sourcery: AutoMockable`; output is
  `BookPlayer/Generated/AutoMockable.generated.swift` (**DO NOT EDIT**, SwiftLint-excluded, regenerate via
  Sourcery over `Templates/AutoMockable.stencil`). A protocol change needs regeneration or the test target won't
  build. **New service logic should come with a test** in `BookPlayerTests/` (XCTest only — no Swift Testing).
- **App Group correctness:** data/defaults/files shared with widgets/watch/extension must use the App Group
  container / `UserDefaults.sharedDefaults`, not `.standard`. The App Group id
  `group.$(BP_BUNDLE_IDENTIFIER).files` must stay consistent across the app, watch, widgets, and share-extension
  entitlements — it is the sole data channel for widgets and the share extension.
- **Combine:** long-lived subscriptions → `private var disposeBag = Set<AnyCancellable>()` + `.store(in:)`;
  single-purpose → a named `AnyCancellable?` that is `.cancel()`'d before rebind. `[weak self]` in sinks/closures
  is the norm — match it. A sink that touches UI needs `.receive(on: DispatchQueue.main)`.
- **`@MainActor` is the UI/service isolation convention.** Off-main → main hops are explicit
  (`Task { @MainActor in … }` / `.receive(on:)`).

---

## High-risk invariants — reviewer hotlist

The crash surfaces and invariants most likely to be broken by a change. (The full severity rubric lives in
`.github/claude/review-guide.md`; this is the architecture-backed "why".)

1. **CoreData threading:** never pass an `NSManagedObject` across threads — use `Simple*` / `Playable*` snapshots;
   UI on `viewContext`, background on `backgroundContext`. `saveContext` `fatalError`s; there is no merge policy,
   so conflicts crash.
2. **CoreData model change without the full 5-step manual-migration ritual** (auto-inference is OFF) → crashes
   existing installs.
3. **SwiftData:** don't share a `ModelContext` across actors; the sync-queue lives behind the `SyncTasksStorage`
   actor; `MigrationPlan.injectedCoreDataContext` must be set before the container is built.
4. **Retain cycles / Combine leaks:** missing `[weak self]` in a sink; an `AnyCancellable` not stored; a named
   subscription not `.cancel()`'d before rebind (`PlayerManager` depends on this).
5. **UI/state mutated off the main actor** without a `@MainActor` hop / `.receive(on: .main)`.
6. **Player / AVAudioSession lifecycle:** `currentItem` swap without re-binding the chapter subscription;
   unbalanced KVO on player-item status; unhandled interruption / `mediaServicesWereReset`; a `beginBackgroundTask`
   without a matching `endBackgroundTask` on **every** path including errors.
7. **`SyncService.isActive`** assigned directly instead of via `updateSyncEnabled(_:)` / `logout()`, or the
   `.logout` / `.accountUpdate` / `teardownTask`-await contract broken.
8. **Entitlement gating** that trusts client-only RevenueCat state for a server-billed resource, or gates sync
   without going through `AccountService`.
9. **Secrets:** committing/overwriting real `Debug.xcconfig` / `Release.xcconfig`, or hardcoding a key instead of
   the xcconfig → `Configuration` path; `BP_MOCKED_BEARER_TOKEN` / `loginTestAccount` left live in prod.
10. **Force-unwrap / `try!` on remote or decoded data** (network / JSON / S3) — a bad payload crashes.
11. **App Group correctness** for anything consumed by widgets/watch/extension.
12. **`BookPlayerKit` boundary:** `Shared/` importing app-layer types.
13. **Integration session-expiry / token contracts** (see the integrations section).
14. Hand-editing `Generated/AutoMockable.generated.swift`; adding code to a top-level **empty stub** folder.
