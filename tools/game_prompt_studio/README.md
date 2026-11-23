# Game Prompt Studio

Game Prompt Studio turns rough Rich’s Houseboat notes into editable, source-grounded Codex prompts. Ollama runs on the Windows host. A local database stores notes, prompts, revisions, source snapshots, imported history, and screenshot attachments.

## Run on this PC

Double-click **Open Game Prompt Studio.cmd** in this folder, or run the following from the Rich’s Houseboat root.

```powershell
cd '.\tools\game_prompt_studio'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\run_windows.ps1
```

Open [Game Prompt Studio](http://127.0.0.1:8765/) when the console says it is ready. If a copy is already listening there, use the existing browser session. Press Ctrl+C in the launch console to stop the studio. Ollama can remain available for other local tools.

## Set up on another host

Install [Node.js 24 LTS](https://nodejs.org/en/download) and [Ollama for Windows](https://ollama.com/download/windows). Extract the studio under the game root at `tools/game_prompt_studio`. Then run these PowerShell commands from that folder.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install_windows.ps1 -PullModel
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\run_windows.ps1
```

The install script sets up the local SQLite database and index without installing npm packages. The optional model pull downloads about 9.3 GB. The script recognizes a standard Ollama install and the versioned portable Ollama install under the host’s local app data. The launcher starts Ollama with local-only settings when an instance is absent. If the host already runs Ollama, keep it bound to the loopback address and enable `OLLAMA_NO_CLOUD=1` in that instance’s startup environment. [Ollama Windows setup](https://docs.ollama.com/windows) · [Ollama local configuration](https://docs.ollama.com/faq)

## Use the studio

1. Open **Studio**, describe a request, and choose the detail level. The optional source picker accepts up to four files from the index.
2. Select **Generate prompt**. Inspect **Context used** for indexed excerpts and separately labeled historical reports.
3. Edit the text, save it, copy it, or download the UTF-8 TXT. **Download .txt** saves current edits before downloading. Review any findings shown by the export checks.
4. Reopen notes and revisions from **Library**. Use **Outcome and status** to record what actually happened. Open **Knowledge** to inspect and rebuild the index.
5. Use **Imports** to preview candidate project notes or select UTF-8 teammate documents. To attach a screenshot, first save or generate the note, then open **Screenshots** in the editor. The app stores a validated, resized PNG and supplies its human-written description on regeneration.

## Model settings and diagnostics

The default is **qwen3:14b Q4_K_M**, an **8,192-token context**, and **two minutes** of keep-alive. One generation runs at a time. **Settings** shows installed models, the selected model, and the VRAM and context Ollama reports while a model is loaded. Run `ollama ps` or `nvidia-smi` to inspect current GPU use. The browser library works when Ollama is offline. [Qwen3 model sizes](https://ollama.com/library/qwen3/tags) · [Ollama GPU and context diagnostics](https://docs.ollama.com/faq)

If the model competes with the game for VRAM, close the game during generation, lower the context to 4,096, or pull `qwen3:8b` and select it in Settings. These are fallback settings.

Use the following command to find the database and configuration. Data defaults to the host’s local AppData outside the game’s OneDrive directory. Keep `STUDIO_DATA_DIR` on a local drive if you override it.

```powershell
node .\control.mjs paths
```

See [Peter's local handoff](PETER_HANDOFF.md) for setup and the HTTP contract. [History imports](docs/ADDING_TEAMMATE_HISTORY.md) and [Data and recovery](docs/ARCHITECTURE.md) describe the local library.

## Run automated tests

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\test_windows.ps1
```

The automated suite uses temporary files and a simulated Ollama provider. For an additional live check against a running default local studio, use `node .\scripts\live-smoke.mjs`. This generates and saves a labeled validation prompt.
