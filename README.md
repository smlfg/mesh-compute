# mesh-compute

Geteilte **Tailscale-Mesh-Compute**: MacBook Pro (Metal) als **Last-Resort** OpenAI-kompatibler Inference-Provider für **Hermes** auf dem ThinkPad (`pop-os`).

Dieses Repo enthält **Interconnect-Konfiguration und Dokumentation** — nicht die Modell-Runtime selbst.

## Rollenaufteilung

| Rolle | Wo | Was |
|-------|-----|-----|
| **Metal / lokaler Cursor auf MBP** | `samuel-mbp` | Ollama/MLX bauen, Modelle laden, Inference ausführen |
| **Interconnect / dieses Repo** | Git + ThinkPad | Tailscale-Exposure, Keep-Awake, Hermes-Provider/Fallback, Verträge, Smoke-Tests |

Verwandtes Schwester-Repo (TTS, ein Ohr — **nicht** hier duplizieren): [mesh-ear](https://github.com/smlfg/mesh-ear)

## Voraussetzungen

- Beide Maschinen im **gleichen Tailscale-Tailnet**
- MagicDNS oder Tailscale-IP erreichbar (Beispiele):
  - Hostname: `samuel-mbp`
  - Tailscale-IP: `100.100.119.4`
- Ollama auf dem MBP mit OpenAI-Compat unter `http://<mbp>:11434/v1` (siehe [docs/OLLAMA-EXPOSE.md](docs/OLLAMA-EXPOSE.md))

## Schnellstart

### 1. MBP: Ollama exponieren

```bash
export OLLAMA_HOST=0.0.0.0
ollama serve   # oder via App/LaunchAgent — Port 11434
```

Details: [docs/OLLAMA-EXPOSE.md](docs/OLLAMA-EXPOSE.md)

### 2. MBP: Über Nacht wach halten

```bash
./scripts/install-keep-awake-macos.sh
```

Installiert LaunchAgent `com.samuel.mbp-inference-awake` → `/usr/bin/caffeinate -dims`.  
`pmset sleep` kann ohne sudo weiterhin `1` sein — siehe [docs/KEEP-AWAKE.md](docs/KEEP-AWAKE.md).

### 3. ThinkPad: Endpoint prüfen

```bash
export MESH_COMPUTE_URL="http://samuel-mbp:11434/v1"   # oder http://100.100.119.4:11434/v1
./scripts/check-mesh-endpoint.sh
```

### 4. ThinkPad: Tool-Calling smoke test

```bash
export MESH_COMPUTE_URL="http://samuel-mbp:11434/v1"
export MODEL="mistral:latest"
./scripts/smoke-tool-calls.sh
```

**Wichtig:** `mistral:latest` emittiert zuverlässig `tool_calls` über Tailscale. Modelle wie `qwen3:8b` / `qwen2.5-coder:7b` werben Tools an, liefern aber oft **keine** `tool_calls` — nicht als erstes Fallback wählen.

### 5. Hermes: Provider einbinden

Template: [examples/hermes-provider.mbp-ollama.yaml](examples/hermes-provider.mbp-ollama.yaml)  
Anleitung Fallback-Kette: [docs/HERMES-FALLBACK.md](docs/HERMES-FALLBACK.md)

**Niemals** echte API-Keys oder private Hermes-Konfigurationen committen.

## Modell-Reihenfolge (overnight-sicher)

Empfohlene Reihenfolge für lange Läufe:

1. `mistral:latest` — schnell, tool_calls verifiziert
2. `gpt-oss:20b`
3. `gemma4:26b`
4. Größere 35B / MLX-Modelle (`qwen3.5:35b`, `qwen3.6:35b-a3b`, `muse-glimmer:30b-mlx`)

Große Overnight-Prompts (~19k Tokens) können auf schweren Modellen **timeouten** — deshalb `mistral:latest` zuerst.

## API-Vertrag

- `GET /v1/models`
- `POST /v1/chat/completions` mit **tools** / **tool_calls** (OpenAI-kompatibel)

## Dokumentation

| Datei | Inhalt |
|-------|--------|
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Architektur, Rollen, Datenfluss |
| [docs/OLLAMA-EXPOSE.md](docs/OLLAMA-EXPOSE.md) | Ollama über Tailscale |
| [docs/KEEP-AWAKE.md](docs/KEEP-AWAKE.md) | caffeinate LaunchAgent + pmset |
| [docs/HERMES-FALLBACK.md](docs/HERMES-FALLBACK.md) | Hermes Provider & Fallback-Kette |

## Lizenz

MIT — Copyright (c) 2026 Samuel Fleig. Siehe [LICENSE](LICENSE).
