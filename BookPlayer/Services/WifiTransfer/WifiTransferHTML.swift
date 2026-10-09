//
//  WifiTransferHTML.swift
//  BookPlayer
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation

enum WifiTransferHTML {
  struct Strings: Encodable {
    let title: String
    let subtitle: String
    let accepted: String
    let folderHint: String
    let dropTitle: String
    let dropHint: String
    let chooseFiles: String
    let chooseFolder: String
    let retry: String
    let uploading: String
    let uploaded: String
    let failed: String
    let importing: String
    let importDone: String
    let queueEmpty: String
    let selectedCount: String
    let skipped: String
    let pinPrompt: String
    let pinSubmit: String
    let pinWrong: String
  }

  /// Page copy from the app’s `Localizable.strings` (same keys / language as Settings).
  static var strings: Strings {
    Strings(
      title: "wifi_transfer_title".localized,
      subtitle: "wifi_transfer_web_subtitle".localized,
      accepted: "wifi_transfer_web_accepted".localized,
      folderHint: "wifi_transfer_web_folder_hint".localized,
      dropTitle: "wifi_transfer_web_drop_title".localized,
      dropHint: "wifi_transfer_web_drop_hint".localized,
      chooseFiles: "wifi_transfer_web_choose_files".localized,
      chooseFolder: "wifi_transfer_web_choose_folder".localized,
      retry: "wifi_transfer_web_retry".localized,
      uploading: "wifi_transfer_web_uploading".localized,
      uploaded: "wifi_transfer_web_uploaded".localized,
      failed: "wifi_transfer_web_failed".localized,
      importing: "wifi_transfer_web_importing".localized,
      importDone: "wifi_transfer_web_import_done".localized,
      queueEmpty: "wifi_transfer_web_queue_empty".localized,
      selectedCount: "wifi_transfer_web_selected_count".localized,
      skipped: "wifi_transfer_web_skipped".localized,
      pinPrompt: "wifi_transfer_web_pin_prompt".localized,
      pinSubmit: "wifi_transfer_web_pin_submit".localized,
      pinWrong: "wifi_transfer_web_pin_wrong".localized
    )
  }

  // Large embedded document: keep HTML/CSS/JS together for the transfer page.
  // swiftlint:disable:next function_body_length
  static func page(requiresPin: Bool = false) -> String {
    let strings = self.strings
    let lang = Bundle.main.preferredLocalizations.first ?? "en"
    let json: String
    if let data = try? JSONEncoder().encode(strings),
      let encoded = String(data: data, encoding: .utf8)
    {
      json = encoded
    } else {
      json = "{}"
    }
    let allowedExtJSON: String = {
      let sorted = WifiTransferFileSupport.allowedExtensions.sorted()
      guard let data = try? JSONEncoder().encode(Array(sorted)),
        let s = String(data: data, encoding: .utf8)
      else {
        return "[]"
      }
      return s
    }()
    let pageTitle = escapeHTML(strings.title)
    let requiresPinJS = requiresPin ? "true" : "false"
    let pinHeaderName = WifiTransferFileSupport.pinHeaderName

    return """
    <!DOCTYPE html>
    <html lang="\(lang)">
    <head>
      <meta charset="utf-8" />
      <meta name="viewport" content="width=device-width, initial-scale=1" />
      <title>\(pageTitle)</title>
      <style>
        :root {
          color-scheme: light dark;
          --fg: #14201c;
          --muted: #5c6b64;
          --accent: #1a8f6a;
          --accent-press: #147a5a;
          --bg0: #eef3f0;
          --bg1: #f7faf8;
          --card: rgba(255,255,255,0.88);
          --border: #c5d2cb;
          --ok: #1a8f6a;
          --err: #c23b3b;
          --track: #d7e2dc;
          --shadow: 0 18px 40px rgba(20, 40, 32, 0.08);
        }
        @media (prefers-color-scheme: dark) {
          :root {
            --fg: #eef6f2;
            --muted: #9aada3;
            --accent: #3dbe92;
            --accent-press: #32a87f;
            --bg0: #0d1411;
            --bg1: #15201b;
            --card: rgba(28, 40, 34, 0.92);
            --border: #2f433a;
            --ok: #3dbe92;
            --err: #e06666;
            --track: #24352e;
            --shadow: 0 18px 40px rgba(0, 0, 0, 0.35);
          }
        }
        * { box-sizing: border-box; }
        body {
          margin: 0; min-height: 100vh;
          font: 16px/1.45 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
          color: var(--fg);
          background:
            radial-gradient(1200px 600px at 10% -10%, color-mix(in srgb, var(--accent) 18%, transparent), transparent),
            linear-gradient(160deg, var(--bg0), var(--bg1));
        }
        main { max-width: 640px; margin: 0 auto; padding: 2rem 1.25rem 3rem; }
        .brand { display: flex; align-items: center; gap: 0.75rem; margin-bottom: 0.35rem; }
        h1 { font-size: 1.75rem; margin: 0; letter-spacing: -0.02em; }
        .pill {
          font-size: 0.7rem; font-weight: 700; letter-spacing: 0.06em; text-transform: uppercase;
          padding: 0.25rem 0.55rem; border-radius: 999px;
          background: color-mix(in srgb, var(--accent) 16%, transparent);
          color: var(--accent); border: 1px solid color-mix(in srgb, var(--accent) 40%, transparent);
        }
        .lead { color: var(--muted); margin: 0 0 0.5rem; }
        .meta { color: var(--muted); font-size: 0.9rem; margin: 0 0 1.25rem; }
        .drop {
          border: 2px dashed var(--border); border-radius: 20px; padding: 2rem 1.25rem;
          background: var(--card); backdrop-filter: blur(8px); box-shadow: var(--shadow);
          text-align: center; transition: border-color .15s, background .15s, transform .15s;
        }
        .drop.over {
          border-color: var(--accent);
          background: color-mix(in srgb, var(--accent) 10%, var(--card));
          transform: scale(1.01);
        }
        .drop .icon {
          width: 3rem; height: 3rem; margin: 0 auto 0.75rem; border-radius: 1rem;
          display: grid; place-items: center; font-size: 1.5rem;
          background: color-mix(in srgb, var(--accent) 14%, transparent); color: var(--accent);
        }
        .actions { display: flex; flex-wrap: wrap; gap: 0.6rem; justify-content: center; margin-top: 1.1rem; }
        .btn {
          appearance: none; border: 0; border-radius: 12px; padding: 0.7rem 1.1rem;
          font-weight: 600; font-size: 0.95rem; cursor: pointer;
        }
        .btn:disabled { opacity: 0.45; cursor: not-allowed; }
        .btn-primary { background: var(--accent); color: #fff; }
        .btn-primary:hover:not(:disabled) { background: var(--accent-press); }
        .btn-ghost {
          background: transparent; color: var(--fg);
          border: 1px solid var(--border);
        }
        .btn-ghost:hover:not(:disabled) {
          border-color: var(--accent);
          color: var(--accent);
        }
        .hidden-input { position: absolute; width: 1px; height: 1px; opacity: 0; pointer-events: none; }
        .toolbar {
          display: flex; align-items: center; justify-content: space-between;
          gap: 1rem; margin: 1.25rem 0 0.75rem; flex-wrap: wrap;
        }
        .count { color: var(--muted); font-size: 0.95rem; }
        #log { list-style: none; padding: 0; margin: 0; display: grid; gap: 0.55rem; }
        #log li {
          background: var(--card); border: 1px solid var(--border); border-radius: 14px;
          padding: 0.75rem 0.9rem; box-shadow: var(--shadow);
        }
        #log li.ok { border-color: color-mix(in srgb, var(--ok) 45%, var(--border)); }
        #log li.err { border-color: color-mix(in srgb, var(--err) 45%, var(--border)); }
        .row { display: flex; justify-content: space-between; gap: 0.75rem; align-items: baseline; }
        .name { font-size: 0.92rem; word-break: break-all; }
        .status { font-size: 0.8rem; color: var(--muted); white-space: nowrap; }
        .bar {
          margin-top: 0.45rem; height: 6px; border-radius: 999px; background: var(--track); overflow: hidden;
        }
        .bar > i {
          display: block; height: 100%; width: 0%; background: var(--accent); border-radius: inherit;
          transition: width .12s linear;
        }
        .banner {
          margin-top: 1rem; padding: 0.85rem 1rem; border-radius: 14px;
          background: color-mix(in srgb, var(--accent) 12%, var(--card));
          border: 1px solid color-mix(in srgb, var(--accent) 35%, var(--border));
          color: var(--fg); font-size: 0.95rem;
        }
        .pin-gate {
          border: 1px solid var(--border); border-radius: 20px; padding: 1.5rem 1.25rem;
          background: var(--card); box-shadow: var(--shadow); margin-bottom: 1.25rem;
        }
        .pin-gate label { display: block; margin-bottom: 0.6rem; color: var(--muted); }
        .pin-row { display: flex; gap: 0.6rem; flex-wrap: wrap; }
        .pin-gate input {
          flex: 1; min-width: 8rem; border: 1px solid var(--border); border-radius: 12px;
          padding: 0.7rem 0.9rem; font-size: 1.25rem; letter-spacing: 0.2em; text-align: center;
          background: transparent; color: var(--fg);
        }
        .transfer { display: none; }
        .transfer.ready { display: block; }
        .pin-error { color: var(--err); font-size: 0.9rem; margin-top: 0.65rem; }
      </style>
    </head>
    <body>
      <main>
        <div class="brand">
          <h1 id="title"></h1>
          <span class="pill">Wi‑Fi</span>
        </div>
        <p class="lead" id="subtitle"></p>
        <p class="meta" id="accepted"></p>
        <p class="meta"><strong id="folderHint"></strong></p>

        <div class="pin-gate" id="pinGate" hidden>
          <label for="pinInput" id="pinPrompt"></label>
          <div class="pin-row">
            <input id="pinInput" type="password" inputmode="numeric" maxlength="4" autocomplete="one-time-code" />
            <button type="button" class="btn btn-primary" id="pinSubmit"></button>
          </div>
          <div class="pin-error" id="pinError" hidden></div>
        </div>

        <div class="transfer" id="transfer">
          <div class="drop" id="drop">
            <div class="icon" aria-hidden="true">↑</div>
            <strong id="dropTitle"></strong>
            <span class="meta" id="dropHint"></span>
            <div class="actions">
              <button type="button" class="btn btn-ghost" id="pickFiles"></button>
              <button type="button" class="btn btn-ghost" id="pickFolder"></button>
            </div>
            <input class="hidden-input" id="fileInput" type="file" multiple />
            <input class="hidden-input" id="folderInput" type="file" webkitdirectory multiple />
          </div>

          <div class="toolbar">
            <div class="count" id="count"></div>
            <button type="button" class="btn btn-primary" id="retry" hidden></button>
          </div>
          <div class="banner" id="banner" hidden></div>
          <ul id="log"></ul>
        </div>
      </main>
      <script>
        const I18N = \(json);
        const ALLOWED = new Set(\(allowedExtJSON));
        const CONCURRENCY = 3;
        const REQUIRES_PIN = \(requiresPinJS);
        const PIN_HEADER = '\(pinHeaderName)';
        const BASE = '/';
        const PIN_KEY = 'bpWifiTransferPin';
        const drop = document.getElementById('drop');
        const fileInput = document.getElementById('fileInput');
        const folderInput = document.getElementById('folderInput');
        const retryBtn = document.getElementById('retry');
        const log = document.getElementById('log');
        const count = document.getElementById('count');
        const banner = document.getElementById('banner');
        const pickFiles = document.getElementById('pickFiles');
        const pickFolder = document.getElementById('pickFolder');
        const transfer = document.getElementById('transfer');
        const pinGate = document.getElementById('pinGate');
        const pinInput = document.getElementById('pinInput');
        const pinSubmit = document.getElementById('pinSubmit');
        const pinError = document.getElementById('pinError');

        document.getElementById('title').textContent = I18N.title;
        document.getElementById('subtitle').textContent = I18N.subtitle;
        document.getElementById('accepted').textContent = I18N.accepted;
        document.getElementById('folderHint').textContent = I18N.folderHint;
        document.getElementById('dropTitle').textContent = I18N.dropTitle;
        document.getElementById('dropHint').textContent = I18N.dropHint;
        document.getElementById('pinPrompt').textContent = I18N.pinPrompt;
        pinSubmit.textContent = I18N.pinSubmit;
        pickFiles.textContent = I18N.chooseFiles;
        pickFolder.textContent = I18N.chooseFolder;
        retryBtn.textContent = I18N.retry;

        let sessionPin = sessionStorage.getItem(PIN_KEY) || '';

        function showTransfer() {
          pinGate.hidden = true;
          transfer.classList.add('ready');
        }

        function showPinGate() {
          pinGate.hidden = false;
          transfer.classList.remove('ready');
          pinInput.focus();
        }

        function applyPinHeader(xhr) {
          if (REQUIRES_PIN && sessionPin) {
            xhr.setRequestHeader(PIN_HEADER, sessionPin);
          }
        }

        if (!REQUIRES_PIN) {
          showTransfer();
        } else if (sessionPin) {
          const probe = new XMLHttpRequest();
          probe.open('POST', BASE + 'unlock');
          probe.setRequestHeader(PIN_HEADER, sessionPin);
          probe.onload = () => {
            if (probe.status >= 200 && probe.status < 300) showTransfer();
            else {
              sessionStorage.removeItem(PIN_KEY);
              sessionPin = '';
              showPinGate();
            }
          };
          probe.onerror = () => showPinGate();
          probe.send();
        } else {
          showPinGate();
        }

        function unlockWithPin() {
          const value = (pinInput.value || '').trim();
          if (!/^\\d{4}$/.test(value)) {
            pinError.hidden = false;
            pinError.textContent = I18N.pinWrong;
            return;
          }
          const xhr = new XMLHttpRequest();
          xhr.open('POST', BASE + 'unlock');
          xhr.setRequestHeader(PIN_HEADER, value);
          xhr.onload = () => {
            if (xhr.status >= 200 && xhr.status < 300) {
              sessionPin = value;
              sessionStorage.setItem(PIN_KEY, sessionPin);
              pinError.hidden = true;
              showTransfer();
            } else {
              sessionStorage.removeItem(PIN_KEY);
              sessionPin = '';
              pinError.hidden = false;
              pinError.textContent = I18N.pinWrong;
            }
          };
          xhr.onerror = () => {
            pinError.hidden = false;
            pinError.textContent = I18N.failed;
          };
          xhr.send();
        }
        pinSubmit.addEventListener('click', unlockWithPin);
        pinInput.addEventListener('keydown', e => {
          if (e.key === 'Enter') unlockWithPin();
        });

        /** @type {{path: string, file: File, root: string|null}[]} */
        let pending = [];
        /** @type {{path: string, file: File, root: string|null}[]} */
        let failed = [];
        let busy = false;

        function setCount() {
          const n = pending.length + (busy ? 1 : 0);
          count.textContent = (pending.length || busy)
            ? I18N.selectedCount.replace('%d', String(Math.max(pending.length, n)))
            : I18N.queueEmpty;
          retryBtn.hidden = !failed.length || busy;
        }
        setCount();

        function extOf(path) {
          const i = path.lastIndexOf('.');
          if (i < 0) return '';
          return path.slice(i + 1).toLowerCase();
        }

        function isAllowedPath(path) {
          const base = path.split('/').pop() || '';
          if (!base || base.startsWith('.')) return false;
          return ALLOWED.has(extOf(base));
        }

        function addFile(file, relativePath, collected, skipped) {
          const path = (relativePath || file.name || '').replace(/^\\/+/, '');
          if (!path) return;
          if (!isAllowedPath(path)) {
            skipped.count += 1;
            return;
          }
          collected.push({
            path,
            file,
            root: path.includes('/') ? path.split('/')[0] : null
          });
        }

        function readEntries(reader) {
          return new Promise((resolve, reject) => {
            const all = [];
            const pump = () => reader.readEntries(entries => {
              if (!entries.length) return resolve(all);
              all.push(...entries);
              pump();
            }, reject);
            pump();
          });
        }

        async function walkEntry(entry, prefix, collected, skipped) {
          if (entry.isFile) {
            const file = await new Promise((resolve, reject) => entry.file(resolve, reject));
            addFile(file, prefix ? prefix + '/' + entry.name : entry.name, collected, skipped);
            return;
          }
          if (entry.isDirectory) {
            const reader = entry.createReader();
            const children = await readEntries(reader);
            const next = prefix ? prefix + '/' + entry.name : entry.name;
            for (const child of children) {
              await walkEntry(child, next, collected, skipped);
            }
          }
        }

        async function collectFromDataTransfer(dt) {
          const collected = [];
          const skipped = { count: 0 };
          const items = dt.items ? [...dt.items] : [];
          let walked = false;
          for (const item of items) {
            const entry = (typeof item.webkitGetAsEntry === 'function')
              ? item.webkitGetAsEntry()
              : null;
            if (entry) {
              walked = true;
              await walkEntry(entry, '', collected, skipped);
            }
          }
          if (!walked || !collected.length) {
            for (const file of dt.files || []) {
              addFile(file, file.webkitRelativePath || file.name, collected, skipped);
            }
          }
          return { collected, skipped: skipped.count };
        }

        function collectFromFileList(files, useRelative) {
          const collected = [];
          const skipped = { count: 0 };
          for (const file of files) {
            const path = useRelative ? (file.webkitRelativePath || file.name) : file.name;
            addFile(file, path, collected, skipped);
          }
          return { collected, skipped: skipped.count };
        }

        function showSkipped(n) {
          if (!n) return;
          banner.hidden = false;
          banner.textContent = I18N.skipped.replace('%d', String(n));
        }

        function enqueueAndStart(collected, skippedCount) {
          if (skippedCount) showSkipped(skippedCount);
          if (!collected.length) {
            setCount();
            return;
          }
          pending.push(...collected);
          setCount();
          startUpload();
        }

        ['dragenter','dragover'].forEach(ev => drop.addEventListener(ev, e => {
          e.preventDefault();
          e.dataTransfer.dropEffect = 'copy';
          drop.classList.add('over');
        }));
        drop.addEventListener('dragleave', e => {
          e.preventDefault();
          drop.classList.remove('over');
        });
        drop.addEventListener('drop', async e => {
          e.preventDefault();
          drop.classList.remove('over');
          const { collected, skipped } = await collectFromDataTransfer(e.dataTransfer);
          enqueueAndStart(collected, skipped);
        });

        pickFiles.addEventListener('click', () => fileInput.click());
        pickFolder.addEventListener('click', () => folderInput.click());
        fileInput.addEventListener('change', () => {
          const { collected, skipped } = collectFromFileList(fileInput.files, false);
          fileInput.value = '';
          enqueueAndStart(collected, skipped);
        });
        folderInput.addEventListener('change', () => {
          const { collected, skipped } = collectFromFileList(folderInput.files, true);
          folderInput.value = '';
          enqueueAndStart(collected, skipped);
        });

        function row(path) {
          const li = document.createElement('li');
          li.innerHTML = '<div class="row"><span class="name"></span><span class="status"></span></div><div class="bar"><i></i></div>';
          li.querySelector('.name').textContent = path;
          log.prepend(li);
          return {
            el: li,
            setStatus(text, cls) {
              li.classList.remove('ok', 'err');
              if (cls) li.classList.add(cls);
              li.querySelector('.status').textContent = text;
            },
            setProgress(p) {
              li.querySelector('.bar > i').style.width = Math.max(0, Math.min(100, p)) + '%';
            }
          };
        }

        function uploadOne(item, ui) {
          return new Promise((resolve, reject) => {
            const xhr = new XMLHttpRequest();
            const url = BASE + 'upload?path=' + encodeURIComponent(item.path);
            xhr.open('POST', url);
            xhr.responseType = 'text';
            xhr.upload.onprogress = (e) => {
              if (e.lengthComputable) ui.setProgress((e.loaded / e.total) * 100);
            };
            xhr.onload = () => {
              if (xhr.status === 401) {
                sessionStorage.removeItem(PIN_KEY);
                sessionPin = '';
                showPinGate();
                pinError.hidden = false;
                pinError.textContent = I18N.pinWrong;
                ui.setStatus(I18N.pinWrong, 'err');
                reject(new Error(I18N.pinWrong));
                return;
              }
              if (xhr.status >= 200 && xhr.status < 300) {
                ui.setProgress(100);
                ui.setStatus(I18N.uploaded, 'ok');
                resolve();
              } else {
                ui.setStatus(I18N.failed + ': ' + (xhr.responseText || xhr.status), 'err');
                reject(new Error(xhr.responseText || String(xhr.status)));
              }
            };
            xhr.onerror = () => {
              ui.setStatus(I18N.failed, 'err');
              reject(new Error('network'));
            };
            ui.setStatus(I18N.uploading);
            xhr.setRequestHeader('Content-Type', 'application/octet-stream');
            applyPinHeader(xhr);
            xhr.send(item.file);
          });
        }

        function importRoot(root) {
          return new Promise((resolve, reject) => {
            const xhr = new XMLHttpRequest();
            xhr.open('POST', BASE + 'import?root=' + encodeURIComponent(root));
            xhr.onload = () => {
              if (xhr.status === 401) {
                sessionStorage.removeItem(PIN_KEY);
                sessionPin = '';
                showPinGate();
                pinError.hidden = false;
                pinError.textContent = I18N.pinWrong;
                reject(new Error(I18N.pinWrong));
                return;
              }
              if (xhr.status >= 200 && xhr.status < 300) resolve();
              else reject(new Error(xhr.responseText || String(xhr.status)));
            };
            xhr.onerror = () => reject(new Error('network'));
            applyPinHeader(xhr);
            xhr.send();
          });
        }

        async function runPool(items, worker) {
          let index = 0;
          const runners = Array.from({ length: Math.min(CONCURRENCY, items.length) }, async () => {
            while (index < items.length) {
              const i = index++;
              await worker(items[i]);
            }
          });
          await Promise.all(runners);
        }

        async function startUpload(retryOnly) {
          if (busy) return;
          const batch = retryOnly ? failed.splice(0, failed.length) : pending.splice(0, pending.length);
          if (!batch.length) {
            setCount();
            return;
          }
          busy = true;
          setCount();
          if (!retryOnly) banner.hidden = true;

          /** @type {Record<string, {ok: number, fail: number}>} */
          const rootStats = {};
          await runPool(batch, async (item) => {
            const ui = row(item.path);
            try {
              await uploadOne(item, ui);
              if (item.root) {
                rootStats[item.root] = rootStats[item.root] || { ok: 0, fail: 0 };
                rootStats[item.root].ok += 1;
              }
            } catch (_) {
              failed.push(item);
              if (item.root) {
                rootStats[item.root] = rootStats[item.root] || { ok: 0, fail: 0 };
                rootStats[item.root].fail += 1;
              }
            }
          });

          const completeRoots = Object.keys(rootStats).filter(
            root => rootStats[root].ok > 0 && rootStats[root].fail === 0
          );
          if (completeRoots.length) {
            banner.hidden = false;
            banner.textContent = I18N.importing;
            for (const root of completeRoots) {
              try {
                await importRoot(root);
              } catch (e) {
                banner.textContent = I18N.failed + ': ' + (e.message || e);
                busy = false;
                setCount();
                return;
              }
            }
          }

          banner.hidden = false;
          if (failed.length) {
            banner.textContent = I18N.failed + ' (' + failed.length + ')';
          } else {
            banner.textContent = I18N.importDone;
          }
          busy = false;
          setCount();
          if (pending.length) startUpload(false);
        }

        retryBtn.addEventListener('click', () => startUpload(true));
      </script>
    </body>
    </html>
    """
  }

  private static func escapeHTML(_ value: String) -> String {
    value
      .replacingOccurrences(of: "&", with: "&amp;")
      .replacingOccurrences(of: "<", with: "&lt;")
      .replacingOccurrences(of: ">", with: "&gt;")
      .replacingOccurrences(of: "\"", with: "&quot;")
  }
}
