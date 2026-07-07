# External Resources Branch Review — `external-resource` vs `develop`

Date: 2026-07-07
Scope: full branch diff (~8.8k added lines) + uncommitted working-tree changes (AppDelegate, HardcoverService, ItemDetailsHardcoverSectionView). Reviewed for inconsistencies and race conditions across four areas: the ConcurrentSync engine, the SwiftData task persistence/migration layer, the CoreData/sync reconciliation logic, and the UI layer. All high-severity findings were hand-verified against the code.

---

## Ship blockers (verified)

### 1. SchemaV3 reuses SchemaV2's version identifier — V2→V3 migration can't work
`Shared/SwiftData/Models/SchemaV3SyncTasksModels.swift:14` declares `Schema.Version(2, 0, 0)`, identical to SchemaV2 (`SchemaV2SyncTasksModels.swift:14`). SwiftData distinguishes schema versions by this identifier, so for every user upgrading from a develop build the `v2ToV3` stage (`MigrationPlan.swift:113`) either fails at `ModelContainer` init — which is a `try!` at `TasksDataManager.swift:43`, i.e. **crash loop at launch** — or silently never runs the hardcover backfill.

**Fix:** bump to `Schema.Version(3, 0, 0)`; add a migration test that opens a V2-seeded store through the plan.

### 2. Persistent crash loop from force-unwrapped URLs in upload task rehydration
`ConcurrenceService.createOperation` (`ConcurrenceService.swift:228`):
```swift
return FileUploadOperation(fileURL: URL(string: filePath)!, remoteURL: URL(string: remotePath)!, uuid: uuid)
```
The producer stores `"remotePath": result.remotePath ?? ""` (`SyncJobScheduler.swift:520`); `URL(string: "")` is nil. `filePath` is a plain filesystem path — spaces/non-URL characters also make `URL(string:)` return nil. The task is persisted and re-materialized by `wakeUpWorkers()` on every launch, so one bad task = **crash on every startup** until reinstall.

**Fix:** guard-let the URLs and return nil (existing path discards via `pop`); use `URL(fileURLWithPath:)` for the local file.

### 3. Locally-linked external resources are wiped by the initial library sync
- `syncLibraryContents()` clears the whole task queue when anything is queued (`SyncService.swift:264-266` → `resetAllJobs()`).
- `updateInfo` reconciliation is server-wins: any local resource missing from the server payload is deleted (`LibraryService+Sync.swift:169-177`, `idsToRemove`).

Scenario: link a Hardcover book offline → pending `externalResource` upload task persisted → relaunch triggers initial `syncLibraryContents()` → `resetAllJobs()` destroys the upload task → item already exists remotely so `getItemsToSync` never re-schedules its resources → reconciliation deletes the local link. **Permanent data loss, nothing left to recreate it.**

Related: `HardcoverService.uploadExternalResource` (working tree ~:444) creates the local resource even when `syncService.isActive == false` (the schedule call no-ops via `guard isActive`), leaving it exposed to the same deletion on re-subscribe.

**Fix:** exclude `syncStatus == .notSynced` resources from `idsToRemove`; and/or re-derive resource-upload tasks from local not-synced state instead of blindly clearing the queue.

### 4. Two `ModelContainer`s over the same sync-tasks store
`SyncService.swift:146` and `ConcurrenceService.swift:70` each build their own `TasksDataManager` (plus a third as a default arg at `ConcurrentTasksRepository.swift:41`). SwiftData only auto-merges between contexts of the *same* container. Consequences:
- **Stalled uploads:** tasks written through the scheduler's repository can be invisible to the worker's repository (stale realized `tasks` relationship); the `.newTaskInQueue`-woken worker sees nothing, retires, and the upload sits until next launch.
- **Duplicate singleton rows:** both `storeTask` implementations do fetch-then-insert of `ConcurrentTasksContainer` with no uniqueness (`ConcurrentTasksRepository.swift:140-146`); every reader uses `containers.first` (`:92`), so tasks appended to the "other" container are permanently stranded.
- **Count drift:** the scheduler notifies TasksDataManager #1's subject; the UI observes #2 via `ConcurrentTasksCountService`.

**Fix:** create one `TasksDataManager` in `AppServices.createCoreServicesIfNeeded` and inject into both `SyncService.setup` and `ConcurrenceService.setup`; delete the default-parameter trap; add uniqueness/fetch-on-write guard for the container singleton.

---

## High — silent data loss and correctness

### 5. `updateExternalResource` never saves the context
`LibraryService+Sync.swift:229-241` — mutates `syncStatus`/`processedFile` inside `context.perform` but never calls `dataManager.saveSyncContext(context)` (the sibling function directly above does). This is the post-download bookkeeping path (`SyncService.handleDownloadCompleted`), so `processedFile` updates evaporate. Compounding: **nothing anywhere writes `SyncStatus.downloaded`** (only declared in `ExternalResource+CoreDataClass.swift:17`), so fully-downloaded external items keep resolving an `externalURL` and play as streams (`PlaybackService.swift:223`).

**Fix:** save the context; set `.downloaded` in the download-completed handler.

### 6. The `provider` gate on file uploads is dead code — external items upload their files anyway
`queueNextTask` skips scheduling a device file upload when `task.parameters["provider"] != nil` (`SyncJobScheduler.swift:427-431`), but tasks are rehydrated via `UploadTaskModel.toDictionaryPayload()`, which **omits `provider`** (verified — `SwiftDataModels+Extensions.swift:21-50`; the model persists it at `SchemaV3SyncTasksModels.swift:96`). So a Jellyfin/ABS-linked item both uploads the local file *and* schedules the server-side pull (`scheduleResourceToDownload`) — double bandwidth, two writers racing on the same storage object. `handleUploadResult` also stores directly via the repository, bypassing `ConcurrenceService.accessPolicy` (`uploadFile: false` for Lite).

**Fix:** add `"provider"` to the payload; route file-upload scheduling through `ConcurrenceService.scheduleFileUpload` so policy applies.

### 7. In-flight coalescing drops the final progress update
`storeTask` merges a new `.update` into the existing task model if its reference is still queued (`ConcurrentTasksRepository.swift:147-155`) — but the reference stays queued *while executing* (removed only by `pop` on completion) and the operation already snapshotted its parameters via `getNextTask`. The merged value is deleted unsent. Self-heals during playback (next 10s tick); the update at **end of playback is permanently lost** — the provider never learns the final position / `isFinished`. The legacy queue explicitly guards this hazard for matchUuid (`SyncTasksStorage.swift:50-62`).

**Fix:** exclude the head-of-queue/in-flight task from coalescing (e.g. a `state` marker on the reference), or compare a revision counter at pop time and re-enqueue if it changed.

### 8. Poison tasks retry forever and block their queue
`ConcurrenceService.swift:170-187`: failure → sleep 5s → retry, unconditionally; errors only `print`ed (`ExternalUpdateProgressOperation.swift:58`). A 404 (item deleted server-side) or revoked token starves every other update for that provider indefinitely; network/battery churn; eternal spinner. Also `ExternalUpdateProgressOperation.main` sleeps 5s unconditionally *before* working (`:40`), capping drain at ~1 task/5s, and the sleep is outside the do/catch so cancellation during it counts as failure → retry.

**Fix:** persist an attempt count; exponential backoff; drop/dead-letter after N attempts; distinguish 4xx (permanent) from transient; move/remove the sleep.

### 9. CoreData threading violations in the new helpers
- `parseSyncableItems` runs inside a background `context.perform` but calls `findResources(for:)` with the default **view context** (`LibraryService+Sync.swift:423`).
- `getItemWithResources` fetches the shared background context **without `perform`** (`LibraryService+Sync.swift:485-497`) and its managed objects are then read on the main thread and inside a detached Task (`SyncService.swift:809-819`).
- `getExternalResource(for:)` (`LibraryService.swift:2871-2890`) resumes a continuation with a managed object fetched on the background context.

All assert under `-com.apple.CoreData.ConcurrencyDebug 1`.

**Fix:** pass the enclosing context through; wrap in `context.perform`; return `SimpleExternalResource` value types across boundaries.

### 10. Lost-wakeup race retires workers with work pending
Between a worker's `getNextTask` returning nil and `stateLock.withLock { activeQueueKeys.remove(queueKey) }` (`ConcurrenceService.swift:149-155`), a `storeTask` + `.newTaskInQueue` notification can fire; the listener sees the key still active and bails (`:128-137`); the worker then retires. The stored task sits until the next task for that key or app restart — for a one-off end-of-playback update, possibly never this session.

**Fix:** double-checked retire (re-check `getNextTask` after removing the key), or move worker bookkeeping into the repository actor so check + empty-verdict are atomic.

---

## Medium

- **`hostId` lost in three places** → wrong-server writes for multi-server users. `updateInfo` add-branch (`LibraryService+Sync.swift:196-206`) and `addBook` (`:294-307`) never copy `hostId`; `ExternalUpdateTaskModel` has no `hostId` field at all (`SchemaV3SyncTasksModels.swift:364-374`), so `createOperation`'s `parameters["hostId"]` is always nil. Downstream falls back to `connections.first` (`PlaybackService.swift:230-250`, `SyncService.downloadRemoteFiles:427-470`, `ExternalUpdateProgressOperation:68-72`) — streams/progress can target the wrong Jellyfin server.
- **Reconciliation keyed on `providerId` alone** (`LibraryService+Sync.swift:166-171`): no `(providerName, providerId, hostId)` tuple, no CoreData uniqueness constraint. Collisions across providers/hosts delete or cross-contaminate rows (syncStatus from provider A written onto provider B). Also `updateProgress` publishes only `resourcesArray.first` from an unordered NSSet (`LibraryService.swift:2512-2516`) — an item linked to Hardcover *and* Jellyfin nondeterministically pushes progress to only one.
- **Server-wins `syncStatus` merge overwrites device-local download state** (`LibraryService+Sync.swift:180-188`). "Downloaded on this device" is per-device; device B's status gets flipped by device A's sync, re-routing playback through `externalURL`. Also `lastSyncedAt`/`processedFile`/`hostId` are never updated for existing rows, only `syncStatus`.
- **Empty-uuid dedupe pass can delete other items' resources** (`LibraryService+Sync.swift:210-222`): `findResources(for: storedItem.uuid)` with legacy `uuid == ""` matches every empty-uuid item's resources and deletes those not attached to this item. Guard `!uuid.isEmpty` / fetch by relationship instead.
- **Migration backfill non-atomic + non-idempotent** (`MigrationPlan.swift:128-207`): Core Data save (`try?`, errors swallowed, line 160) and SwiftData save (line 207) are separate transactions. Kill in between → resources exist locally, upload tasks never enqueued, stage never re-runs (the "already exists" check filters everything). Also `guard injectedCoreDataContext else { return }` (`:118-120`) silently skips the one-shot backfill where v1ToV2 `fatalError`s. Prefer moving the backfill out of migration, keyed off `syncStatus == .notSynced` at first sync.
- **No logout/delete/unlink cleanup for the concurrent queue**: `ConcurrentTasksRepository` has no `clearAll` and no logout hook (`ConcurrenceService`'s logout observer only resets `hasScheduledLibraryContents`). Persisted upload tasks carry the previous account's presigned URLs and resume after account switch; queued `.update` tasks outlive item deletion/unlinking and (with the retry bug) 404 forever.
- **Orphaned references block queues permanently**: `createConcurrentTaskModel` silently no-ops on a missing payload param (`TasksDataManager.swift:492-516`, no else) while `storeTask` still appends the reference; `getNextTask` then returns nil at the head (`ConcurrentTasksRepository.swift:55-61`) as if the queue were empty → head-of-line stall forever + count never reaches zero. Make creation throwing; on missing payload in `getNextTask`, delete the reference and advance.
- **`pop` never deletes payload models** (`ConcurrentTasksRepository.swift:70-84` deletes only the reference): unbounded store growth; the coalescing lookup `fetch(...).last(where:)` increasingly hits leaked rows so dedup quietly stops working. Legacy `finishedTask` deletes both (`SyncTasksStorage.swift:148-162`).
- **HTTP error responses count as upload success**: `BPTaskUploadDelegate.didFinishTask` forwards only transport errors; a 403/500 PUT arrives with `error == nil` → `didSucceed = true` → task popped **and source hard link deleted**. Durable loss, no retry. Check `task.response` status.
- **`FileUploadOperation` issues** (`FileUploadOperation.swift`):
  - Progress filter tautology (`:99`): closure destructures `(path, progress)` but compares `uuid == self.uuid` — always true after `guard let self`; any upload's progress drives every operation's callback. Should be `path == self.uuid`.
  - `cancel()` (`:145-151`) cancels the completion subscriber so `finish()` never runs → never-finishing operation occupies a queue slot, queue stalls. (Nothing calls `cancel()` today — latent.)
  - Observer binding happens *after* task lookup (`:51-69`): a reused in-flight task completing in the gap is never observed (PassthroughSubject, no replay) → same never-finish stall. Cellular toggle can also "reuse" the just-cancelled task whose cancel event is deliberately ignored.
  - Unsynchronized mutable state (`currentUploadTask`, subscribers, KVO observer) touched from 4 threads — TSan-visible data race. Confine to a serial queue/actor.
- **Counts**: `concurrentTasksCountSubject` never seeded at launch (`TasksDataManager.initializeTasksCount:473` seeds only the legacy subject), not zeroed by `deleteAllTasks` (`:95`), and delivered off-main (`observeConcurrentTasksCount:65` lacks the `.receive(on: .main)` its legacy sibling has).
- **Round-trip fabrication**: `SimpleExternalResource.init(from: ExternalResource)` doesn't copy `processedFile` while `SyncableExternalResource.init(from: SimpleExternalResource)` hardcodes `processedFile = true` (`SyncableExternalResource.swift:56`) — the uploaded value is fiction. `SyncableItem.copy(uuid:)` (`SyncableItem.swift:112-132`) drops `externalResources`, so first-arrival items with placeholder uuids lose their resources. `ExternalResource.id` (server row id) is never set by the synced-down path (always 0).
- **Placeholder-uuid guard missing**: `UploadExternalResourceTaskModel.toDictionaryPayload()` returns `"uuid": uuid` unconditionally (`SwiftDataModels+Extensions.swift:179-192`) where upload/update models gate behind `Constants.isRealUuid`. A placeholder uuid → server rejection → serial queue retries every 5s and blocks everything behind it (`applyMatchUuidConflicts` mitigates but doesn't cover all orderings).

---

## Low

- `SyncTasksStorage.getNextTask` invalid-reference cleanup (`:127-129`) removes from the relationship but never deletes the `SyncTaskReferenceModel` row — dangling rows accumulate (`finishedTask` does it right).
- `pop` swallows save errors (`ConcurrentTasksRepository.swift:81`, `try?`) → completed task re-executed after restart (duplicate upload/progress POST).
- `handleUploadResult` swallows `storeTask` throws inside a bare `Task { }` (`SyncJobScheduler.swift:513-525`) — a failed store silently never schedules the upload.
- Retain cycle: `ConcurrenceService.listeningTask` strongly captures self → `deinit` unreachable (`ConcurrenceService.swift:66, 95-109`). Benign for app-lifetime instance; leaks elsewhere.
- `@Entry var concurrenceService: ConcurrenceService = .init()` (`Environment+BookPlayer.swift:18`) creates an un-setup instance with nil IUOs — resolving the environment outside `MainCoordinator`'s injection crashes.
- `AsyncOperation` state machine has no lock (`AsyncOperation.swift:17-26`) — a duplicate completion event (same `taskDescription` in two background sessions from a prior run) would re-enter `finish()` after `completionBlock` ran. Cheap to harden.
- N+1 view-context fetches: `handleSyncFromExternalResouce` (`LibraryService.swift:2911`) and `parseFetchedItems`'s per-row `findResources` on every list load — safe but measurable scroll cost on large libraries.
- Resume-popup pull (`ItemListViewModel.fetchExternalResource:882-933`): with the concurrent queue's drain latency, the device's *own* delayed push can make Jellyfin look newer than local → spurious resume prompt at an equal/older position.

## UI layer

- `ExternalImportViewModel` proxies `resources` to `ImportManager.externalFiles` but never forwards `objectWillChange` from the manager — the sheet observes only the view model, so tapping minus may not visually remove rows. Also a leftover `print(destinationURL)` in `ImportManager.hasExistingBook`.
- `ItemDetailsViewModel.resolveHardcoverSelection`: the placeholder selection is guarded against spurious re-save (same-id check), but the placeholder `hardcoverBook` carries `userBookID: nil`, so swapping books while the real fetch is in flight skips the removal-confirmation alert a real linked book would trigger.
- Uncommitted `AppDelegate`: `register(defaults:)` with `hardcoverAutoAddWantToRead: true` flips the effective default for users who never touched the setting (previously `bool(forKey:)` → false) — books now auto-add to "Want to Read". Confirm intended. `register(defaults:)` is per-process; watch/widgets won't see it (HardcoverService is app-only today).
- Uncommitted `HardcoverService`: `assignItem` delete-then-create ordering and `setExternalResource`'s already-linked guard look sound. `updateHardcoverStatus` (~:304) does read-check-insert; two concurrent throttled progress events can both pass the check and double-insert (low impact, Hardcover insert is idempotent-ish by book).

---

## Design safety assumptions the implementation relies on

1. Actor confinement: `SyncTasksStorage` and `ConcurrentTasksRepository` are `ModelActor`s; each `ModelContext` only touched on its actor — violated globally by the dual-container setup (#4).
2. Per-`queueKey` serial execution is enforced by the operation→`completionBlock`→`enqueueNextTask` chain, which depends on every operation reaching `isFinished` (broken by the `FileUploadOperation` cancel/reuse gaps) and on `activeQueueKeys` bookkeeping (subject to the lost-wakeup race, #10).
3. `providerId` is globally unique across providers/hosts/items — nothing enforces it.
4. The BookPlayer server's resource list is authoritative; local not-synced resources are only safe while their upload task survives — violated by `resetAllJobs` (#3).
5. `syncStatus` is treated as global state though `downloaded` semantics are per-device.
6. Item uuids are real by the time external-resource tasks execute — only partially backed by `applyMatchUuidConflicts`.
7. Keychain `connections.first` is an acceptable fallback when `hostId` is missing — but `hostId` is dropped in three paths, making the fallback the common case.
8. Concurrent-task store contents remain valid across account changes — false; never cleared on logout.
9. `MigrationPlan.injectedCoreDataContext` is assigned before the first `TasksDataManager()` in both app and watch targets — true today, one refactor away from silently breaking (#Medium, migration).

---

## Suggested fix order

1. **#1 schema version** and **#2 URL force-unwraps** — crash loops.
2. **#3 resource wipe** and **#4 single shared `TasksDataManager`** — data loss / queue integrity.
3. **#5–#8** — silent data loss (missing save, dead provider gate, coalescing loss, poison retry).
4. Structural: add an **in-flight marker on concurrent task references** — one change that fixes the coalescing race, enables poison-task handling, and makes unlink/logout cleanup tractable.
5. The medium/low lists as cleanup passes (threading, hostId plumbing, counts, lifecycle hooks).
