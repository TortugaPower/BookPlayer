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

Ten native targets in `BookPlayer.xcodeproj` (no `Package.swift`, no app `.xcworkspace`):

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
| `BookPlayerUITests` | UI-test bundle | **Release check only** (never CI), see below | `BookPlayerUITests/` |

**Deployment targets:** iOS **26.0** for every iOS target, watchOS **10.0** for the watch app, `BookPlayerWatchKit`
and the watch widgets. An `#available(iOS 18…26)` check is dead code on iOS, but `Shared/` and the shared widget
files also compile for watchOS 10, so an iOS-only API there still needs its `#if os(iOS)` / availability guard.

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

RevenueCat (`purchases-ios`, ~5.78), Sentry (`sentry-cocoa`, **exact 8.36.0**), Kingfisher (~8.10),
JellyfinAPI (`jellyfin-sdk-swift`, ~1.0), Get (~2.2), MarqueeLabel (~4.0.5), DeviceKit (~5.1),
IDZSwiftCommonCrypto (~0.13.1), Themeable (~3.0), ZipArchive (~2.3), DirectoryWatcher (~2.8.6).
`BlurHashDecode.swift` is vendored (SwiftLint-excluded). RevenueCat + Kingfisher link into the **frameworks**;
most others link into the **app**. SwiftLint runs as a build-phase run-script; **Sourcery is run manually** (not
a build phase) and its output is committed.

---

## Build, CI & tooling (what the tools own — don't hand-police it)

- **CI** (`.github/workflows/ci.yml`): runner `xcode-27` (GitHub's preview image), **Xcode 27.0**
  (`/Applications/Xcode_27.0.app`, set with `xcode-select`). Xcode 27 is required: the upload code calls iOS 27
  SDK APIs behind `#available` (`BGTaskScheduler.submitTaskRequest`), which Xcode 26 can't compile. It copies
  `Debug.template.xcconfig` → `Debug.xcconfig`, resolves SPM, resets the simulators, then `build-for-testing` and
  `test-without-building` with the **`Unit Tests`** test plan, `-only-testing:BookPlayerTests`, simulator
  `iPhone 17`. Triggers on push to `main`/`develop` and PRs to `develop`. Release builds come from Xcode Cloud
  (`ci_scripts/`), whose Xcode version is set in App Store Connect and must be 27 too.
- **Release check** (`scripts/release-check/release_check.py`): run locally by the iOS release skill before a
  release is tagged, **never by CI**. It builds the **Release** configuration for the simulator through the shared
  `ReleaseCheck` scheme (CI's `BookPlayer` scheme and `Unit Tests` plan don't include `BookPlayerUITests`) and runs
  four scenarios per supported iOS major (deployment target → SDK, minus the script's `SKIPPED_MAJORS`): fresh
  launch, import, playback, and upgrade from the previous release (cached in `~/Library/Caches/BookPlayerReleaseCheck/`).
  A failure with a crash report fails at once; one without gets a single retry on a reset simulator and is
  reported as "passed on retry" if it then passes (simulators flake; a crash never gets a second chance). If the
  *previous* release crashes on an iOS version, the upgrade there starts from the release before it (its users never
  had data in the crashing one), and is reported as not tested if that one crashes too. It exists because 5.22.1
  crashed at launch on iOS < 27 while every check ran on iOS 27. The tests find the UI by four
  `accessibilityIdentifier`s (`library.row.<relativePath>`, `miniPlayer.info`, `player.playPause`,
  `player.currentTime`) and by the English labels "Done" (Import sheet) and "Library" (placement prompt); keep
  `BookPlayerUITests/ReleaseCheckUITests.swift` in step when changing those.
  The upgrade scenario drives the *previous* release with labels only, since older builds lack the identifiers.
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
   controller. `MainView` is a `TabView` (Library / Profile / Settings [+ Search on iPhone]) with a mini-player
   overlay and a `.fullScreenCover` for the player.

**Invariant:** the strong chain `SceneDelegate → LoadingCoordinator.mainCoordinator → MainCoordinator` is the
only thing keeping `MainCoordinator` alive — don't sever it. Boot ordering matters: several call sites
force-unwrap `AppServices.shared.coreServices!`, relying on `DataInitializerCoordinator` having awaited setup
first. Reordering boot risks a launch crash.

### Dependency injection — `BookPlayer/Utils/AppServices.swift`

- `@MainActor final class AppServices` with `static let shared` + `private init()`. Owns the async
  `setupCoreServicesTask`, the `DatabaseInitializer`, and a shared `PlayerState`.
- `CoreServices` (`BookPlayer/Utils/CoreServices.swift`) is a struct of exactly **12 services**: `accountService`,
  `syncQueueService`, `externalProgressService` (pulls media-server playback positions for lite/pro accounts;
  self-subscribes to `.bookPlayed` for the on-play prompt, and `ListSyncRefreshService.syncList` drives the
  per-level list pull through the one-method `ExternalProgressRefreshing` seam),
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
  `ListSyncRefreshService.syncList(at:)` is the ONE list-refresh entry point (list appear, pull-to-refresh, sync
  activation, CarPlay): cloud contents for the level → the level's media-server progress pull → preferences pull.
  A folder's cloud step is skipped until the first sync has run (`SyncService.hasRunFirstSync`, backed by
  `hasScheduledLibraryContents`): its listing would delete local items the server hasn't seen yet. The root refresh then asks, without waiting, for
  `SyncService.scheduleMissingItemsIfNeeded()` (the weekly / became-PRO missing-items pass).
  The pull runs strictly AFTER the cloud step and never alongside it (cloud writes on the background context, the
  progress ingest on the view context; no merge policy), whatever the cloud outcome. It is resource-first:
  `LibraryService.findMediaServerResources(at:)` fetches only the level's media-server `ExternalResource` rows
  (direct children, providers filtered in SQL from `ProviderName.mediaServerRawValues`) on the background context,
  so the main thread does nothing but the ingest. `ExternalResource.ProviderName.mediaServer` — which maps a
  provider onto the `ExternalResource.MediaServerProvider` sub-enum (`jellyfin`, `audiobookshelf`) — is the single
  exhaustive "is this a media server" switch; `isMediaServer`, `SimpleExternalResource.mediaServer`, the SQL filter,
  and every server-only switch (stream source, host display, progress push, the library-row glyph) derive from it.
- **Services → SwiftUI:** `ObservableObject`s (`playerManager`, `importManager`, `singleFileDownloadService`,
  `listSyncRefreshService`) via `.environmentObject`, plus `externalImportEvents`, which `MainView` owns as a
  `@StateObject` and injects itself — the coordinator builds services, not SwiftUI-internal wires; the rest via `.environment(\.key, …)`.
  `ExternalImportEvents` is a stateless wire (integrations send confirmed virtual-import batches; `LibraryRootView`
  consumes and inserts) that conforms to `ObservableObject` solely for the loud-injection contract — `ImportManager`
  itself carries no external-import state or publishers. The environment keys
  live in `BookPlayer/Utils/Extensions/Environment+BookPlayer.swift` (`@Entry`). **Each `@Entry` default is a
  throwaway placeholder (an un-`setup()` service).** A view that reads the environment default instead of the
  injected instance gets a non-functional service: stored-property reads return inert defaults, but METHODS that
  touch un-`setup()` dependencies trap on their implicitly-unwrapped optionals
  (`SyncQueueService.observeQueueCounts` and siblings all behave this way — it is the pattern, not a
  defect). Verify real injection by `MainCoordinator`; previews that exercise such views must construct and
  inject set-up services (see `ProfileSyncTasksSectionView`'s preview), never rely on the defaults.
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
`.listeningProgressChanged`, `.syncTaskPaused`, `.backgroundSessionFinishedEvents`, `.bookUploadsQueued`; and app-internal ones in `BookPlayer/Utils/Extensions/Notification+BookPlayer.swift`.

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
  currently `v1…v12`, current model `Audiobook Player 12` — v12 adds the `ExternalResource` entity + the
  `LibraryItem.externalResources` relationship for media-server items). It migrates **one version at a time** using explicit
  `.xcmappingmodel`s where present (`v1→v2 … v3→v4`, `v7→v8 … v11→v12`; the v4–v7 hops rely on inference). A model
  change requires: **(1)** new `.xcdatamodel` version + bump `.xccurrentversion`; **(2)** new `DBVersion` case +
  `model()`; **(3)** a mapping model registered in `mappingModelName()` (inference is OFF, so anything
  non-trivial fails without one); **(4)** any custom data population added to the post-migration step; **(5)**
  bundled resources. `DatabaseInitializer` + `DatabaseBackupService` are the only safety net for a failed
  migration (the migrator deletes the old store before moving the new one into place — interruption = data loss).

### Sync task queue = SwiftData — `Shared/SwiftData/`

- `TasksDataManager.swift` owns the `ModelContainer`. **Store is `applicationSupportDirectory/bp-synctasks.sqlite`
  — the app-support dir, NOT the App Group**, separate from the CoreData store. CloudKit disabled.
  Before the container is built, `storeIsUnknownToMigrationPlan(at:)` checks the store's own metadata against
  every `MigrationPlan.schemas` model; a store none of them can open (dev builds between schema edits, an older
  build over a newer store) is MOVED aside (`.incompatible` suffix, never deleted) and a fresh one is created.
  Don't match Cocoa codes (134504/134100) on the thrown error instead — SwiftData wraps them opaquely, so that
  guard never fired. Any load failure that remains — a custom-migration-stage bug, a corrupt file, a fresh store
  that won't open — still crashes (`fatalError`).
- Versioned schema: `SchemaV1` (10 models) → `SchemaV2` (11 models, adds `MatchUuidsTaskModel` + a `uuid` field)
  → `SchemaV3` (unified concurrent-task container: `QueuedTaskReferenceModel` with per-queue keys, plus
  `ExternalUpdateTaskModel`/`UploadFileTaskModel` payloads). App code always uses the V3 typealiases.
- `MigrationPlan.swift` (`SchemaMigrationPlan`) has a **custom `v1ToV2` stage that reads UUIDs out of the CoreData
  `LibraryItem` table** — it requires `MigrationPlan.injectedCoreDataContext` to be set first, else
  **`fatalError`** (the `v2ToV3` stage also uses the injected context, but degrades gracefully when absent).
  This is the coupling between the two stores; set it before the `ModelContainer` is built.
- **`ModelContext` is per-actor and not `Sendable`.** All task-queue reads/writes go through
  `public actor SyncQueueRepository: ModelActor` (`Shared/Services/SyncQueue/`) with a single
  confined `ModelContext` (it replaced the old `SyncTasksStorage` actor). Do not share/pass a `ModelContext`
  across actors or threads. Execution lives in `SyncQueueService` (OperationQueue): the `sync` queue key runs
  BookPlayer-server jobs serially; provider-named keys (externalUpdate pushes) and `uploadFile` run concurrently.
  **The engine is the single owner of queue counts:** `observeQueueCounts()` publishes one per-lane `QueueCounts`
  snapshot (the Profile row shows its `total`; the single Queued Tasks screen — one `DisclosureGroup` per lane,
  sync first — reads `count(in:)` for its headers and lists every lane through `getOrderedQueuedJobs`).
  `SyncService.canSyncListContents` gates list refresh on the `sync` lane only (repository `getTasksCount(in:)`),
  and `AppDelegate.handleAppRefresh` waits on `laneDrained(TaskQueueKey.sync)` — S3 uploads and provider pushes
  never block a refresh or hold a background window open (pushes retry forever against an unreachable server).
  **Server-lane gate:** the BookPlayer-server lanes (`sync`, `uploadFile`) run only while
  `SyncQueueService.serverLanesEnabled` is on. It starts off (workers wake in `setup`, before `SyncService` is
  set up) and mirrors `SyncService.isActive` — `SyncService` is the ONLY writer: `setup` in the same synchronous
  call as `isActive`, `updateSyncEnabled` and `logout` inside the main-actor block that writes `isActive` (so a
  fast re-login can't be overwritten by a late logout write). Workers check it before every pop, so a lapse stops
  a running lane after its current task. Gated tasks are **held, never cleared**: RevenueCat's cached info is nil
  before the first fetch, so a paying subscriber can read inactive at launch. Provider lanes ignore the gate, and
  `handleAppRefresh` completes immediately while it's off (a gated lane never drains).
  **Parking:** a failed task parks ONLY on a coded failure — `SyncFailurePolicy.codedFailure` returns a
  `CodedFailure` for the server's coded 4xx (`BookPlayerError.networkErrorWithCode`, its `error` key) and for the
  app's own `UploadFileError.fileTooLarge` (`file_too_large`, no HTTP status); anything uncoded (network, 5xx,
  the engine's retry-later) keeps the 5 s retry. Errors from both `LibraryItemSyncOperation` and
  `FileUploadOperation` reach it. `SyncFailurePolicy` owns the rules: leaf tasks (`update`,
  `uploadArtwork`, `uploadFile`) park alone (`TaskPauseScope.task`, the lane keeps running); every other
  sync-lane task is structural and stops its lane (`.lane`); `not_subscribed`/`tier_required` park `.account`
  (holds every server lane) and trigger a fresh RevenueCat read — inactive runs the normal lapse path, active or
  failed keeps the tasks held and reports; `externalUpdate` keeps its own handling. The watch sets
  `parkingEnabled = false` (no UI there), so task-level coded failures drop. The pause lives on
  `QueuedTaskReferenceModel` (`pauseScope`, code, message, status, `pausedAt`, `sentryEventId`);
  `SyncQueueRepository.getNextTask` skips `.task` rows and stops at a `.lane`/`.account` head, and
  `TasksDataManager.queueCounts` mirrors those rules (paused counts, blocked lanes; `laneDrained` counts a lane
  with nothing runnable as drained). Parked tasks and the running task (tracked by id in the repository — a Retry
  can put a resumed task ahead of it) are never coalescing targets. Retry = one automatic resume at
  launch (`setup`) plus `retryPausedTask(id:)`; there is deliberately no Skip. A first park posts
  `.syncTaskPaused`, skipped when the row already carries a `sentryEventId` (recorded via `recordPauseReport`;
  it survives resumes) and for a too-large book (decided: an expected limit, nothing to act on). The app-target `SyncPauseReporter` (owned by `AppServices`) turns it into ONE Sentry
  warning per task, fingerprint `["sync-paused", jobType, errorCode]`, with a minimal payload (job type, code,
  status, lane, scope, item uuid) — **never the server message or a path: both embed file names**. The Queued
  Tasks row of a parked task shows the server's message with Retry and Report; Report mails (or, without Mail,
  shares) `SyncPauseReport`: the paused task, every queued task with its state, and the local library tree with
  uuids. A too-large book (`file_too_large`) instead shows the app's own message and a **Dismiss** action — the
  only dismissible pause (`dismissPausedTask(id:)` refuses anything else; server-refused tasks never get a Skip).
  A blocked lane's header turns red, Profile's "Queued sync tasks" title turns red with a warning icon while
  anything is parked (its caption keeps showing last sync / progress), and a blocked pull-to-refresh says sync
  is paused.
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
  S3 presigned PUTs through `NetworkClient` (folders and bound books in `handleUploadJob`, artwork) use
  `useKeychain: false` (the URL carries its own auth); book files never go through `NetworkClient` — their parts
  are header-less background upload tasks (below). Media-server calls use
  their own connection tokens. Any new `request(url:...)` must set `useKeychain` deliberately — the default
  `true` attaches the JWT to whatever host is passed.
- **Background `URLSession`s** (`Shared/Network/BPURLSession.swift`): two sessions (`.background` and
  `.background.cellular`) chosen by the `allowCellularData` default; downloads via `BPDownloadURLSession`.
  They carry multipart upload PARTS, one upload task each, described `<uuid>#<partNumber>@<uploadId>`
  (`BackgroundPartUploadTransport`); `progressPublisher` emits `(task, bytesSent)`.
  **Background wakes:** `AppDelegate.application(_:handleEventsForBackgroundURLSession:)` hands iOS's completion
  handler to `BackgroundSessionWakeCoordinator` (names in `BackgroundTransferSessions`). For the upload sessions it
  recreates them and answers only after `SyncQueueService.settleUploads()` — the running upload has handled the
  delivered parts and queued the next ones (`FileUploadOperation.settle()`) — under `beginBackgroundTask`, with a
  25 s cap; calling the handler earlier suspends the app mid-request. The downloads session waits the same way
  for `SyncService.settleDownloads()` (each finished download's follow-up: chapters, verification, scheduling —
  Core Data in the App Group container); any other session (single-file media-server downloads) is answered right
  away. Both delegates post `.backgroundSessionFinishedEvents` from SERIAL delegate queues (so it follows the last
  completion); either order of handler and events works. The coordinator is created in `didFinishLaunching`, before
  anything can wake a session. These session names are NOT `BGTaskSchedulerPermittedIdentifiers`.
  **Continued task:** `UploadContinuationController` (app target, owned by `AppServices`, registered at launch as
  `<bundle>.uploads.continued`) runs ONE `BGContinuedProcessingTask` for the whole upload queue, so uploads keep
  full speed in the background (Live Activity "Uploading files", "(x / n) <file name>", progress in bytes). It is
  submitted whenever books are queued for upload — `.bookUploadsQueued` (posted by `SyncService.handleItemsToUpload`
  for an import, and by the missing-items pass for the first sync and on becoming PRO, never its weekly run;
  decided: always, no size threshold), on a parked
  task's Retry, and from the "Continue in background" buttons (the Queued Tasks File Uploads header, a
  borderless button under Profile's Queued Tasks link; shown only when `isOfferAvailable`) — only from
  the foreground, with S3 access, when the Wi-Fi-only setting allows the current network, and when some waiting
  book sits in a lane that can run (not all behind a blocked lane). Its books come from
  `SyncQueueService.pendingBookUploads()` (one repository read of both lanes: the sync lane's book `.upload`s —
  not media-server ones, which carry no file — and pipe jobs, then the upload lane; parked ones counted apart);
  refreshes are coalesced (one in flight). It ends when the queue stays empty for a moment (a book between
  lanes can look absent; the upload task is stored BEFORE the sync `.upload` is popped), unsuccessfully if only
  parked uploads remain or nothing can move (no S3 access, every waiting book behind a blocked lane). On expiry
  or a Live Activity cancel it answers `setTaskCompleted(false)` in the handler and the parts carry on in the
  background sessions. A task iOS launches before the services exist is held, not failed; a request iOS dropped
  (`pendingTaskRequests`) no longer blocks the next submit. While a task runs, Profile's caption reads "Uploading in background · N%"
  (`runningPercent`); Profile stays two lines (no Wi-Fi caption there — the banner is Queued Tasks only).
- **Book uploads are S3 multipart** (`FileUploadOperation`, the `uploadFile` lane; contract in
  bookplayer-api `docs/multipart-uploads.md`). A non-nil `url` from `PUT /v1/library` only means "the server
  needs the bytes" — the client never PUTs to it. **The server sets `synced` at `/upload/complete`; the client
  never confirms a book upload it made** (folders and bound books are confirmed after their presigned PUT). A nil `url` is confirmed with `synced:true` for folders and bound books on
  every tier, but for a book only when the tier has S3 access (`LibraryItemSyncOperation.canUploadFiles`, from
  `accessPolicy[.uploadFile]` when `createOperation` builds it): there it means the file is already in S3, while on
  LITE it only means the tier stores no file, so LITE books stay `synced=false` and the missing-items pass (below)
  queues their files on becoming PRO. S3 is the source of truth: every run rebuilds from `GET /upload/parts` plus
  the session's tasks for the current `uploadId`, so a relaunch or a lost event resumes without re-sending. The
  resumable state (`uploadId`, `partSize`, `fileSize`, `restartCount`) lives on `UploadFileTaskModel`; parts are
  sliced to `tmp/uploads/<uuid>/`; 64 MiB parts, 8 in flight (fewer on low disk), fresh part URLs every top-up
  (403 = expired), up to 3 restarts (`upload_not_found`/`invalid_parts`/NoSuchUpload, or `complete` answering
  `parts_missing` 5 rounds running while S3 lists every part) before the task parks with the server's code — the
  dead upload is forgotten and the budget reset first, so a Retry starts fresh; books over 10 GiB park as
  `file_too_large`. The source is the temp hard link, else the book's
  current Processed file found by uuid (`LibrarySyncProtocol.fetchRelativePath(forUuid:)`) — never deleted. A
  cellular-setting change cancels the parts in flight so they resend through the session that now applies.
  `item_not_found` from the upload routes is not parked the first time: the book is re-registered through the sync
  lane from its CURRENT state (`LibrarySyncProtocol.fetchSyncableItem(forUuid:)`) — item, external resources,
  bookmarks, like `SyncService.handleItemsToUpload` — before the task is popped, or dropped when it's gone locally
  too. Always re-register (decided): a book deleted on another device mid-upload can come back. A SECOND
  `item_not_found` for the same uuid in a session parks it (re-registering didn't help: e.g. another uuid holds
  its key on the server). A Retry of that parked upload clears the mark (decided: the user asked for the upload),
  so the book is registered once more instead of parking again. Only a MEDIA-SERVER link (`SyncableItem.mediaServerProviderName`, never Hardcover) marks an
  `.upload` as provider-backed (its answer then schedules no file); such a book's file goes up once downloaded
  through the sync-lane `externalResourceToDownload` job, which just schedules the upload (the old `external_set`
  route is gone; `complete` marks the resources downloaded).
- **Missing-items pass** (`SyncService.runMissingItemsPass`; contract in bookplayer-api `docs/multipart-uploads.md`):
  sends every local uuid in ONE `POST /v1/library/status` and gets `{ unknown, unsynced }` back. Unknown items
  (no server row, active or deleted) are first matched by path INLINE (`POST /uuids`, conflicts adopted in the
  library and the queue via `applyUuidConflicts`, items re-read) — `PUT /` at a path the server holds under no uuid
  or another one would never store ours, and a queued match job could rewrite uuids while the registrations were
  still being stored — then registered like an import (`handleItemsToUpload`, parents first). Unsynced books (PRO only: `accessPolicy[.uploadFile]`) go straight to the upload lane BY UUID
  (`scheduleMissingFileUploads`, the Processed file as source), never re-PUT: a stale path would move them back.
  It skips media-server books (no backfill), books without a local file or over 10 GiB, and any book with an upload
  already queued, parked included (`storeFileUploadsIfAbsent`: checked and stored in one actor turn, one save). It IS
  the first sync's registration step (`syncLibraryContents`: the pass, then a root pull that never deletes); `/keys`
  is deprecated and no longer called. The first sync never clears queued work: it waits until the sync lane is
  empty (the flag stays off, the next root refresh retries), and every run of the pass is single-flight. A run
  remembers the sync session it began in: sync going off (`logout`, a lapse) bumps it and clears the flag in one
  locked step, so a logout+sign-in during a pass can't let the old run mark the first sync done after its teardown
  wiped what it queued. Registration reads bookmarks in batches on a background context (`getUserBookmarks`). A lapse (`updateSyncEnabled(false)`, or `setup` finding a signed-in account —
  `getAccountId() != nil` — that isn't syncing: the entitlement expired while the app was closed, or a stale cached
  read, which is harmless) clears `hasScheduledLibraryContents`, so coming back runs a first sync: books imported meanwhile aren't on the server, and a plain listing would delete
  them. `scheduleMissingItemsIfNeeded()` runs it again on LITE → PRO (the `.accountUpdate` sink's `noteProAccess`
  sets `missingItemsPassPending` on a change of `lastKnownProAccess` — its first reading, e.g. after an app update,
  only seeds it — cleared only by a run that could queue files, i.e. once the queue had its PRO policy) and weekly
  (`missingItemsPassLastRun`), only once the first sync ran, while sync is on and with an empty sync lane; a tier
  change arriving during a weekly run runs right after it; only a pending (tier-change) run posts
  `.bookUploadsQueued`. Its state lives in the `UserDefaults` given to `setup` (`.standard`; tests inject a suite). Phone only: `setup(runsMissingItemsPass:)` is true in
  `AppServices` alone (the watch has downloaded files of its own); without it the first sync throws and the other
  entry points return. Accepted: a pre-March-2026 item that another
  device deleted under its own uuid, or none, reads as unknown and comes back. The Settings › Debug export is
  local only (tree with uuids, no server call).
- `SyncService.swift` is `@Observable`. **`isActive` is `public private(set)` and must be mutated only via
  `updateSyncEnabled(_:)` / `logout()`** (both hop to `@MainActor`). It is driven by `.logout` (→ teardown, clears
  scheduled-contents flag, resets jobs) and `.accountUpdate` (→ `updateSyncEnabled(hasSyncEnabled())`)
  notifications. A `teardownTask` is **awaited** at the top of the sync-contents entry points so a fast
  logout→login can't let a late `resetAllJobs()` wipe freshly-scheduled jobs — preserve this ordering. Every
  `schedule*` method short-circuits on `guard isActive`.
- **Sync = the `pro` OR `lite` entitlement** (`hasSyncEnabled()`); `lite` gets DB-backed sync only —
  S3 file uploads are gated per-job via `SyncQueueService.accessPolicy` (`.uploadFile` is pro-only,
  `.externalUpdate` — progress pushes to the USER'S OWN media server — is available on every tier,
  matching the Android app). **The media-server progress PULL is the opposite:** `ExternalProgressService`
  gates both the on-play resume prompt and the list refresh on `accountService.hasSyncEnabled()` (lite/pro),
  read live on every pull, and cancels an in-flight pull on an `.accountUpdate` that drops the entitlement —
  free/plus users push to their own server but never see other devices' positions. Android must mirror this.
  Job types (`SyncJobType`): `upload, update, move, renameFolder, delete, shallowDelete, setBookmark,
  deleteBookmark, uploadArtwork, matchUuid, externalResource, externalResourceToDownload, deleteExternalResource`
  (sync lane), `uploadFile` (upload lane), `externalUpdate` (provider lanes).
- **Download verification:** `verifyDownloadedFile` rejects truncated files by comparing `AVURLAsset` duration to
  the stored duration (tolerance `max(2, expected*0.02)`); completion is broadcast only after verification.
  Don't skip it — it prevents promoting a truncated book.

---

## Auth · secrets · Keychain · subscriptions

### Secrets / config: xcconfig → Info.plist → `Configuration`

- `BuildConfiguration/*.xcconfig` define `BP_*` keys; `Info.plist` substitutes them (`$(BP_…)`);
  `Shared/Configuration.swift` (`ConfigurationKeys`) reads them. **`Bundle.configurationValue(for:)` uses `try!`
  — a missing key crashes at launch.** Keys: API scheme/domain/port, bundle id, RevenueCat key, Sentry DSN.
- **`Debug.xcconfig` and `Release.xcconfig` are gitignored and hold the working-tree real values —
  never commit or overwrite them.** Nuance a reviewer should know: `Debug.xcconfig` is untracked and holds real
  prod secrets; `Release.xcconfig` is *also* gitignored **but is already tracked** with placeholder values
  (`replace.me`) — CI (`ci_scripts/ci_post_clone.sh`) rewrites it from Xcode Cloud env vars at build time. A new
  secret must be added to **the template (`Debug.template.xcconfig`) + the CI script + `Info.plist` +
  `ConfigurationKeys`** in lockstep, never inlined — or the `try!` crashes Release builds. Hardcoded API keys /
  tokens / Sentry DSN / RevenueCat key are a 🔴 finding.

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

- RevenueCat entitlements `AccessLevel { free, plus, lite, pro }`. `hasSyncEnabled()` = `pro` OR `lite` active
  (pro wins when both are held);
  `hasPlusAccess()` = `plus` OR `pro` OR `lite` (all paid tiers unlock plus perks; local `donationMade` fallback when cached info is nil).
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
  - **Has no instance id:** sign-in stores `serverId: nil` (its login's `serverSettings.id` is the constant
    `"server-settings"`), so an ABS book's `hostId` is the server's canonical address (`URL.canonicalDedupKey`,
    which must equal what Android phones store: AOSP's `java.net.URI` allows `_` in hosts).
  - **Streams per file** (a contract shared with the Android app): the item
    download is a zip for any book in a folder, and a file's id is its inode, which changes when the file is
    replaced. So a chapter carries `PlayableChapter.StreamLookup` and `PlayerManager.streamURL` asks
    `GET api/items/{id}?expanded=1` (`AudiobookShelfStreamLookup`) when the chapter loads, once per item (a
    volume's books share it), never ahead of time. It plays `api/items/{id}/file/{ino}` relative to the saved
    URL, token in the header. Time limits: 5 s on playback (an unreachable server falls through to the cloud
    copy), 30 s for downloads. Only a 401 is an expired session (its own `PlaybackFailure.Reason`, said only for
    a play the user started and when no cloud copy plays the book); a 403 means this user can't open that item.
  - **Multi-file items import as volumes** (`LibraryService.createExternalVolume`): a bound folder named after
    the title holding the link, one book per file named by its flattened path
    (`MediaServerFileNames.volumeChildFileNames`). The books have no link of their own: playback
    (`PlaybackService.VolumeStream`), downloads (`MediaServerDownloadPlanner`, one more lookup after a 404), sync
    registration (`SyncableItem.volumeMediaServerProviderName`, so no file is asked for) and the post-download
    upload all go through the volume's. Single books are named `<title>.<ext>` (no provider prefix), with
    `-<uuid prefix>` when a book anywhere already has that name.
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
  **The import's "where should these go?" prompt is `ImportPlacementPrompt`, owned by `LibraryRootView`, not
  one of the list's alerts.** SwiftUI drops a presentation started while something covers the library or is
  still leaving it, and a dropped value in the list's single `activeAlert` slot used to block every later list
  alert until relaunch. So: the import screen starts the import only once it has closed
  (`finishPresentation(animated:completion:)`); the prompt waits until `ListStateManager.coversOnScreen` is
  empty (covers register in their content's `onAppear` and leave in the presentation's `onDismiss`: a new cover
  over the library must do the same), the import screen is gone (`ImportManager.isImportScreenShown`) and the
  Library tab is on screen; and it carries the imported items' uuids, reading their current paths when an
  option is picked (`LibraryService.getItemRefs(forUuids:)`). The list's own sheets and alerts aren't waited
  for: the prompt closes one (seen with a sheet), or is dropped under it, lost, and cleared when the next
  import screen or cover closes (streams are confirmed in the media-server browser) so it can't block later
  prompts. Its actions and the list's multi-select share
  `LibraryOrganizer`. An alert that leads to another (Move → the folder name) uses a separate alert, set from
  the first one's button: switching one alert's contents (nil, then the next) can be dropped mid-animation.
- **Library** (`Library/ItemList/…`, backed by `Shared/Services/LibraryService.swift`): the main list, folders,
  and drag-drop reordering. **Ordering model (query-time sort):** `orderRank` means ONLY the user's custom
  arrangement (written by drag/reverse/Custom-freeze/one-shot sorts and by sync; never by an automatic sort).
  An automatic sticky sort is applied at fetch time — `resolveSortDescriptors` in `LibraryService` maps the
  location's effective sort to `SortType.sortDescriptors` (`localizedStandardCompare:` + `orderRank` tie-break);
  sync may overwrite ranks freely — the rendered order only follows ranks where the effective sort resolves to
  rank order: Custom, `.unresolved`/bound locations, and any target with no `preferencesService` wired.
  **watchOS wires a pull-only `PreferencesSyncService`** (constructed in `ExtensionDelegate`, bootstrapped at
  launch, refreshed before each list sync in `RemoteItemListViewModel`), so the watch renders the same sticky
  sort as the phone; nothing on the watch writes sort prefs, and the pull is gated on the sync entitlement so
  free accounts never make the request. Rank
  updates always sync (no auto-sort suppression exists anymore). **Both mutation invariants live in
  `freezeVisibleOrder(at:transform:)`** — the single core of `reorderItems`/`reverseContents`/
  `adoptCurrentOrderAsCustom`: (1) capture-before-flip — the effective (visible) descriptors are resolved
  **before** the pref flips to `.custom`, else the mutation acts on rank order instead of what the user sees;
  (2) the `.custom` pref write precedes the rank rebuild so the next fetch doesn't re-sort the user's
  arrangement away. Route any new user-arrangement rank mutation through that helper (the one-shot
  materialization for `.unresolved` locations in `sortContents` is the deliberate exception — it has no pref
  key to flip). Playback prev/next walks
  `getOrderedSiblings` (visible order, lightweight entries), not rank cursors. A correct fetch order doesn't
  update a list already on screen: `ItemListView` holds fetched rows, so under "Most recent" it re-fetches when
  the loaded book changes, and `setLibraryLastBook` stamps the book's parent folders too, so parent lists move
  the folder on that re-fetch instead of after the progress tick's delayed save. On logout,
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
  `BookPlayer/Base.lproj/Localizable.strings`; ~27 locales are community-translated — flag a **missing Base key** or a
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
3. **SwiftData:** don't share a `ModelContext` across actors; the sync-queue lives behind the
   `SyncQueueRepository` actor; `MigrationPlan.injectedCoreDataContext` must be set before the container
   is built.
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
   the xcconfig → `Configuration` path.
10. **Force-unwrap / `try!` on remote or decoded data** (network / JSON / S3) — a bad payload crashes.
11. **App Group correctness** for anything consumed by widgets/watch/extension.
12. **`BookPlayerKit` boundary:** `Shared/` importing app-layer types.
13. **Integration session-expiry / token contracts** (see the integrations section).
14. Hand-editing `Generated/AutoMockable.generated.swift`; adding code to a top-level **empty stub** folder.
15. **SDK-only result-builder content:** an `if` or several statements inside a `ForEach` that builds rotor or toolbar
    content uses `Optional`/`TupleContent` conformances that, with the iOS 27 SDK, exist only on iOS 27 → launch
    crash on older iOS (5.22.1). Filter the data before the `ForEach` instead.
