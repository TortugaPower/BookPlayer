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
    let upload: String
    let uploading: String
    let uploaded: String
    let failed: String
    let importing: String
    let importDone: String
    let queueEmpty: String
    let selectedCount: String
  }

  static func strings(for languageCode: String) -> Strings {
    let lang = languageCode.lowercased().hasPrefix("ru") ? "ru" : "en"
    if lang == "ru" {
      return Strings(
        title: "BookPlayer",
        subtitle: "Перетащите файлы или папки аудиокниг. Они появятся на экране импорта в приложении.",
        accepted: "Поддерживаются: mp3, m4b, m4a, aax, flac, zip, lpf и похожие форматы.",
        folderHint: "Структура папки сохранится.",
        dropTitle: "Перетащите сюда",
        dropHint: "файлы или целую папку",
        chooseFiles: "Выбрать файлы",
        chooseFolder: "Выбрать папку",
        upload: "Загрузить",
        uploading: "Загрузка",
        uploaded: "Загружено",
        failed: "Ошибка",
        importing: "Импорт в приложение…",
        importDone: "Готово — смотрите импорт на телефоне",
        queueEmpty: "Ничего не выбрано",
        selectedCount: "Выбрано: %d"
      )
    }
    return Strings(
      title: "BookPlayer",
      subtitle: "Drop audiobook files or folders. They appear in the app’s import screen on your phone.",
      accepted: "Accepted: mp3, m4b, m4a, aax, flac, zip, lpf, and similar audio archives.",
      folderHint: "Folder structure is preserved.",
      dropTitle: "Drop here",
      dropHint: "files or an entire folder",
      chooseFiles: "Choose files",
      chooseFolder: "Choose folder",
      upload: "Upload",
      uploading: "Uploading",
      uploaded: "Uploaded",
      failed: "Failed",
      importing: "Importing into the app…",
      importDone: "Done — check Import on your phone",
      queueEmpty: "Nothing selected",
      selectedCount: "Selected: %d"
    )
  }

  // Large embedded document: keep HTML/CSS/JS together for the transfer page.
  // swiftlint:disable:next function_body_length
  static func page(languageCode: String) -> String {
    let strings = strings(for: languageCode)
    let lang = languageCode.lowercased().hasPrefix("ru") ? "ru" : "en"
    let json: String
    if let data = try? JSONEncoder().encode(strings),
      let encoded = String(data: data, encoding: .utf8)
    {
      json = encoded
    } else {
      json = "{}"
    }

    return """
    <!DOCTYPE html>
    <html lang="\(lang)">
    <head>
      <meta charset="utf-8" />
      <meta name="viewport" content="width=device-width, initial-scale=1" />
      <title>\(strings.title) — Wi‑Fi Transfer</title>
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
            --track: #24332c;
            --shadow: 0 18px 40px rgba(0, 0, 0, 0.35);
          }
        }
        * { box-sizing: border-box; }
        body {
          margin: 0; min-height: 100vh;
          font-family: "Avenir Next", "Segoe UI", -apple-system, BlinkMacSystemFont, sans-serif;
          color: var(--fg);
          background:
            radial-gradient(1200px 500px at 10% -10%, rgba(26,143,106,0.18), transparent 55%),
            radial-gradient(900px 420px at 100% 0%, rgba(26,143,106,0.10), transparent 50%),
            linear-gradient(180deg, var(--bg1), var(--bg0));
        }
        main { max-width: 44rem; margin: 0 auto; padding: 2.5rem 1.25rem 3rem; }
        .brand {
          display: flex; align-items: baseline; gap: 0.65rem; margin-bottom: 0.75rem;
        }
        .brand h1 {
          margin: 0; font-size: clamp(1.8rem, 4vw, 2.35rem); font-weight: 700; letter-spacing: -0.03em;
        }
        .pill {
          font-size: 0.72rem; font-weight: 700; letter-spacing: 0.06em; text-transform: uppercase;
          color: var(--accent); border: 1px solid color-mix(in srgb, var(--accent) 45%, var(--border));
          padding: 0.2rem 0.5rem; border-radius: 999px;
        }
        .lead { margin: 0 0 0.4rem; color: var(--muted); line-height: 1.5; font-size: 1.02rem; }
        .meta { margin: 0; color: var(--muted); font-size: 0.92rem; line-height: 1.45; }
        .meta strong { color: var(--fg); font-weight: 600; }
        .drop {
          margin-top: 1.6rem; padding: 2.4rem 1.4rem 1.6rem; border: 1.5px dashed var(--border);
          border-radius: 22px; background: var(--card); box-shadow: var(--shadow);
          text-align: center; transition: border-color .15s, transform .15s, background .15s;
        }
        .drop.over {
          border-color: var(--accent);
          background: color-mix(in srgb, var(--accent) 10%, var(--card));
          transform: translateY(-1px);
        }
        .drop .icon {
          width: 3.2rem; height: 3.2rem; margin: 0 auto 0.9rem; border-radius: 1rem;
          display: grid; place-items: center;
          background: color-mix(in srgb, var(--accent) 14%, transparent);
          color: var(--accent); font-size: 1.5rem;
        }
        .drop strong { display: block; font-size: 1.15rem; margin-bottom: 0.25rem; }
        .actions {
          display: flex; flex-wrap: wrap; gap: 0.6rem; justify-content: center; margin-top: 1.15rem;
        }
        .btn {
          appearance: none; border: 0; border-radius: 12px; padding: 0.72rem 1.15rem;
          font-weight: 700; font-size: 0.95rem; cursor: pointer;
        }
        .btn-primary { background: var(--accent); color: #fff; }
        .btn-primary:hover { background: var(--accent-press); }
        .btn-primary:disabled { opacity: 0.45; cursor: default; }
        .btn-ghost {
          background: transparent; color: var(--fg);
          border: 1px solid var(--border);
        }
        .hidden-input { position: absolute; width: 1px; height: 1px; opacity: 0; pointer-events: none; }
        .toolbar {
          display: flex; align-items: center; justify-content: space-between; gap: 1rem;
          margin-top: 1.25rem;
        }
        .count { color: var(--muted); font-size: 0.92rem; }
        ul { list-style: none; padding: 0; margin: 1rem 0 0; display: grid; gap: 0.55rem; }
        li {
          padding: 0.75rem 0.9rem; border-radius: 14px; background: var(--card);
          border: 1px solid var(--border); box-shadow: var(--shadow);
        }
        li .row { display: flex; justify-content: space-between; gap: 0.75rem; align-items: baseline; }
        li .name { font-size: 0.95rem; word-break: break-all; }
        li .status { font-size: 0.8rem; color: var(--muted); white-space: nowrap; }
        li.ok .status { color: var(--ok); }
        li.err .status { color: var(--err); }
        .bar {
          margin-top: 0.55rem; height: 6px; border-radius: 999px; background: var(--track); overflow: hidden;
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
          <button type="button" class="btn btn-primary" id="send"></button>
        </div>
        <div class="banner" id="banner" hidden></div>
        <ul id="log"></ul>
      </main>
      <script>
        const I18N = \(json);
        const drop = document.getElementById('drop');
        const fileInput = document.getElementById('fileInput');
        const folderInput = document.getElementById('folderInput');
        const send = document.getElementById('send');
        const log = document.getElementById('log');
        const count = document.getElementById('count');
        const banner = document.getElementById('banner');
        const pickFiles = document.getElementById('pickFiles');
        const pickFolder = document.getElementById('pickFolder');

        document.getElementById('title').textContent = I18N.title;
        document.getElementById('subtitle').textContent = I18N.subtitle;
        document.getElementById('accepted').textContent = I18N.accepted;
        document.getElementById('folderHint').textContent = I18N.folderHint;
        document.getElementById('dropTitle').textContent = I18N.dropTitle;
        document.getElementById('dropHint').textContent = I18N.dropHint;
        pickFiles.textContent = I18N.chooseFiles;
        pickFolder.textContent = I18N.chooseFolder;
        send.textContent = I18N.upload;

        /** @type {{path: string, file: File, root: string|null}[]} */
        let queue = [];

        function setCount() {
          count.textContent = queue.length
            ? I18N.selectedCount.replace('%d', String(queue.length))
            : I18N.queueEmpty;
        }
        setCount();

        function addFile(file, relativePath) {
          const path = (relativePath || file.name || '').replace(/^\\/+/, '');
          if (!path) return;
          queue.push({
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

        async function walkEntry(entry, prefix) {
          if (entry.isFile) {
            const file = await new Promise((resolve, reject) => entry.file(resolve, reject));
            addFile(file, prefix ? prefix + '/' + entry.name : entry.name);
            return;
          }
          if (entry.isDirectory) {
            const reader = entry.createReader();
            const children = await readEntries(reader);
            const next = prefix ? prefix + '/' + entry.name : entry.name;
            for (const child of children) {
              await walkEntry(child, next);
            }
          }
        }

        async function addFromDataTransfer(dt) {
          const items = dt.items ? [...dt.items] : [];
          if (items.some(i => i.webkitGetAsEntry)) {
            for (const item of items) {
              const entry = item.webkitGetAsEntry && item.webkitGetAsEntry();
              if (entry) await walkEntry(entry, '');
            }
            return;
          }
          for (const file of dt.files || []) {
            addFile(file, file.webkitRelativePath || file.name);
          }
        }

        ['dragenter','dragover'].forEach(ev => drop.addEventListener(ev, e => {
          e.preventDefault(); drop.classList.add('over');
        }));
        ['dragleave','drop'].forEach(ev => drop.addEventListener(ev, e => {
          e.preventDefault(); drop.classList.remove('over');
        }));
        drop.addEventListener('drop', async e => {
          await addFromDataTransfer(e.dataTransfer);
          setCount();
        });

        pickFiles.addEventListener('click', () => fileInput.click());
        pickFolder.addEventListener('click', () => folderInput.click());
        fileInput.addEventListener('change', () => {
          for (const file of fileInput.files) addFile(file, file.name);
          fileInput.value = '';
          setCount();
        });
        folderInput.addEventListener('change', () => {
          for (const file of folderInput.files) {
            addFile(file, file.webkitRelativePath || file.name);
          }
          folderInput.value = '';
          setCount();
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
            const url = '/upload?path=' + encodeURIComponent(item.path);
            xhr.open('POST', url);
            xhr.responseType = 'text';
            xhr.upload.onprogress = (e) => {
              if (e.lengthComputable) ui.setProgress((e.loaded / e.total) * 100);
            };
            xhr.onload = () => {
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
            xhr.send(item.file);
          });
        }

        function importRoot(root) {
          return new Promise((resolve, reject) => {
            const xhr = new XMLHttpRequest();
            xhr.open('POST', '/import?root=' + encodeURIComponent(root));
            xhr.onload = () => {
              if (xhr.status >= 200 && xhr.status < 300) resolve();
              else reject(new Error(xhr.responseText || String(xhr.status)));
            };
            xhr.onerror = () => reject(new Error('network'));
            xhr.send();
          });
        }

        send.addEventListener('click', async () => {
          if (!queue.length) {
            banner.hidden = false;
            banner.textContent = I18N.queueEmpty;
            return;
          }
          send.disabled = true;
          banner.hidden = true;
          const batch = queue.slice();
          queue = [];
          setCount();
          const roots = new Set();
          for (const item of batch) {
            const ui = row(item.path);
            try {
              await uploadOne(item, ui);
              if (item.root) roots.add(item.root);
            } catch (_) { /* status already set */ }
          }
          if (roots.size) {
            banner.hidden = false;
            banner.textContent = I18N.importing;
            for (const root of roots) {
              try { await importRoot(root); }
              catch (e) {
                banner.textContent = I18N.failed + ': ' + (e.message || e);
                send.disabled = false;
                return;
              }
            }
          }
          banner.hidden = false;
          banner.textContent = I18N.importDone;
          send.disabled = false;
        });
      </script>
    </body>
    </html>
    """
  }
}
