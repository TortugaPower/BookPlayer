//
//  WifiTransferHTML.swift
//  BookPlayer
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation

enum WifiTransferHTML {
  static let page: String = """
  <!DOCTYPE html>
  <html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>BookPlayer — Wi‑Fi Transfer</title>
    <style>
      :root { color-scheme: light dark; --fg: #111; --muted: #666; --accent: #0a7; --bg: #f6f6f6; --card: #fff; --border: #ddd; }
      @media (prefers-color-scheme: dark) {
        :root { --fg: #f2f2f2; --muted: #aaa; --accent: #3c9; --bg: #121212; --card: #1e1e1e; --border: #333; }
      }
      * { box-sizing: border-box; }
      body { margin: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; background: var(--bg); color: var(--fg); }
      main { max-width: 40rem; margin: 2rem auto; padding: 0 1.25rem; }
      h1 { font-size: 1.5rem; font-weight: 650; margin: 0 0 0.35rem; }
      p { color: var(--muted); line-height: 1.45; }
      .drop {
        margin-top: 1.5rem; padding: 2.5rem 1.25rem; border: 2px dashed var(--border);
        border-radius: 12px; background: var(--card); text-align: center; transition: border-color .15s, background .15s;
      }
      .drop.over { border-color: var(--accent); background: color-mix(in srgb, var(--accent) 8%, var(--card)); }
      .drop strong { display: block; margin-bottom: 0.35rem; }
      input[type=file] { margin-top: 1rem; }
      button {
        margin-top: 1rem; appearance: none; border: 0; border-radius: 10px; padding: 0.7rem 1.2rem;
        background: var(--accent); color: #fff; font-weight: 600; font-size: 1rem; cursor: pointer;
      }
      button:disabled { opacity: 0.5; cursor: default; }
      ul { list-style: none; padding: 0; margin: 1.25rem 0 0; }
      li { padding: 0.55rem 0.75rem; margin: 0.4rem 0; border-radius: 8px; background: var(--card); border: 1px solid var(--border); font-size: 0.95rem; }
      li.ok { border-color: var(--accent); }
      li.err { border-color: #c44; }
      .hint { font-size: 0.9rem; }
    </style>
  </head>
  <body>
    <main>
      <h1>BookPlayer</h1>
      <p>Drop audiobook files here. They appear in the app’s import screen on your phone.</p>
      <p class="hint">Accepted: mp3, m4b, m4a, aax, flac, zip, lpf, and similar audio archives.</p>
      <div class="drop" id="drop">
        <strong>Drop files here</strong>
        <span class="hint">or choose them below</span>
        <div>
          <input id="file" type="file" multiple accept=".mp3,.m4b,.m4a,.m4v,.aax,.aaxc,.wav,.flac,.opus,.ogg,.oga,.mp4,.mov,.avi,.zip,.lpf,audio/*,application/zip" />
        </div>
        <button id="send" type="button">Upload</button>
      </div>
      <ul id="log"></ul>
    </main>
    <script>
      const drop = document.getElementById('drop');
      const input = document.getElementById('file');
      const send = document.getElementById('send');
      const log = document.getElementById('log');
      let queue = [];

      function addFiles(list) {
        for (const f of list) queue.push(f);
      }
      function line(text, cls) {
        const li = document.createElement('li');
        if (cls) li.className = cls;
        li.textContent = text;
        log.prepend(li);
      }
      ['dragenter','dragover'].forEach(ev => drop.addEventListener(ev, e => { e.preventDefault(); drop.classList.add('over'); }));
      ['dragleave','drop'].forEach(ev => drop.addEventListener(ev, e => { e.preventDefault(); drop.classList.remove('over'); }));
      drop.addEventListener('drop', e => addFiles(e.dataTransfer.files));
      input.addEventListener('change', () => addFiles(input.files));

      async function uploadOne(file) {
        const url = '/upload?name=' + encodeURIComponent(file.name);
        const res = await fetch(url, {
          method: 'POST',
          headers: { 'Content-Type': 'application/octet-stream', 'Content-Length': String(file.size) },
          body: file
        });
        if (!res.ok) {
          const msg = await res.text();
          throw new Error(msg || ('HTTP ' + res.status));
        }
      }

      send.addEventListener('click', async () => {
        if (!queue.length) { line('No files selected', 'err'); return; }
        send.disabled = true;
        const batch = queue.slice();
        queue = [];
        input.value = '';
        for (const file of batch) {
          line('Uploading ' + file.name + '…');
          try {
            await uploadOne(file);
            line('Uploaded ' + file.name, 'ok');
          } catch (e) {
            line('Failed ' + file.name + ': ' + (e.message || e), 'err');
          }
        }
        send.disabled = false;
      });
    </script>
  </body>
  </html>
  """
}
