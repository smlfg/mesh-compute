# Architektur

Überblick über Samuel Fleigs geteiltes Tailscale-Mesh-Compute: ThinkPad **Hermes** nutzt das MacBook Pro als **Last-Resort** Inference-Backend.

## Rollenaufteilung

```
┌─────────────────────────────────────────────────────────────────┐
│  Metal / lokaler Cursor (MBP)                                   │
│  samuel-mbp  ·  Tailscale z.B. 100.100.119.4                   │
│  ─────────────────────────────────────────────────────────────  │
│  · Ollama / MLX installieren & Modelle pullen                   │
│  · Inference ausführen (GPU/Metal)                              │
│  · OLLAMA_HOST=0.0.0.0, Port 11434                              │
└───────────────────────────────┬─────────────────────────────────┘
                                │ Tailscale (verschlüsselt)
                                │ OpenAI-compat /v1
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│  Interconnect / dieses Repo (mesh-compute)                      │
│  ─────────────────────────────────────────────────────────────  │
│  · Dokumentation & Verträge                                     │
│  · Hermes provider YAML (Template)                            │
│  · Keep-Awake LaunchAgent (caffeinate)                          │
│  · Smoke-Tests (models, tool_calls)                             │
└───────────────────────────────┬─────────────────────────────────┘
                                │ fallback_providers
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│  ThinkPad Hermes (pop-os)                                       │
│  ─────────────────────────────────────────────────────────────  │
│  · Primäre Provider (lokal / Cloud)                             │
│  · mbp-ollama als letzte Kette wenn alles andere scheitert      │
└─────────────────────────────────────────────────────────────────┘
```

### Metal (MBP)

- Physische Hardware und Modell-Runtime leben **nur** auf dem Mac.
- Cursor auf dem MBP kann direkt mit lokalem Ollama arbeiten — ohne Tailscale-Umweg.
- Kein Deployment dieses Repos auf dem MBP nötig für Inference; nur Keep-Awake + Ollama-Exposure.

### Interconnect (dieses Repo)

- Definiert **wie** der ThinkPad den MBP erreicht (Hostname/IP, Port, API-Pfade).
- Stellt **installierbare** Artefakte bereit (LaunchAgent, Scripts, Hermes-Template).
- Enthält **keine** Modell-Blobs, keine privaten Hermes-Secrets.

## Tailscale-Mesh

Beide Knoten sind im selben Tailnet:

| Knoten | Beispiel-Hostname | Beispiel-IP |
|--------|-------------------|-------------|
| MBP | `samuel-mbp` | `100.100.119.4` |
| ThinkPad | `pop-os` | (eigene Tailscale-IP) |

Erreichbarkeit per **MagicDNS** (`http://samuel-mbp:11434/v1`) oder **Tailscale-IP** (`http://100.100.119.4:11434/v1`). Beides ist äquivalent, solange DNS im Tailnet aktiv ist.

## Datenfluss Hermes → MBP Ollama

1. Hermes auf `pop-os` wählt einen Provider aus der `fallback_providers`-Kette.
2. Wenn lokale/Cloud-Provider ausfallen, wird `mbp-ollama` versucht.
3. HTTP `POST /v1/chat/completions` an den MBP mit optional `tools`.
4. Antwort muss bei Tool-Use `tool_calls` im OpenAI-Format liefern — nicht alle Modelle tun das trotz Tool-Werbung.

## API-Vertrag

| Endpoint | Zweck |
|----------|-------|
| `GET /v1/models` | Modellliste (Health-Check) |
| `POST /v1/chat/completions` | Chat inkl. `tools` / `tool_calls` |

Validierung von der ThinkPad-Seite:

```bash
./scripts/check-mesh-endpoint.sh
./scripts/smoke-tool-calls.sh   # MODEL=mistral:latest
```

## Schwester-Repo: mesh-ear

Text-to-Speech für ein Ohr läuft separat: [github.com/smlfg/mesh-ear](https://github.com/smlfg/mesh-ear)

Dieses Repo deckt **nur LLM-Inference-Fallback** ab — keine TTS-Duplikation.

## Overnight-Betrieb

- LaunchAgent `com.samuel.mbp-inference-awake` hält den MBP per `caffeinate -dims` wach.
- Modellwahl: `mistral:latest` zuerst (schnell, tool_calls OK); große Prompts (~19k) auf 35B+ können timeouten.
- Siehe [KEEP-AWAKE.md](KEEP-AWAKE.md) und [HERMES-FALLBACK.md](HERMES-FALLBACK.md).
