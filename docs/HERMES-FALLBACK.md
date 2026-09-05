# Hermes Fallback: mbp-ollama

Anleitung, wie der MBP-Ollama-Provider in Hermes auf dem ThinkPad (`pop-os`) als **Last-Resort** eingebunden wird.

> **Warnung:** Niemals echte API-Keys, Tokens oder vollständige private Hermes-Konfigurationen in Git committen. Nur Templates aus `examples/` versionieren; lokale Overrides in ignorierten Dateien (siehe `.gitignore`).

## Provider-Template

Kopiere oder merge den Inhalt von [examples/hermes-provider.mbp-ollama.yaml](../examples/hermes-provider.mbp-ollama.yaml):

```yaml
providers:
  mbp-ollama:
    api: http://100.100.119.4:11434/v1   # oder http://samuel-mbp:11434/v1
    default_model: mistral:latest
    models:
      - mistral:latest
      - gpt-oss:20b
      - gemma4:26b
      - qwen3.5:35b
      - qwen3.6:35b-a3b
      - muse-glimmer:30b-mlx
```

Passe `api` an deine Umgebung an:

- MagicDNS: `http://samuel-mbp:11434/v1`
- Tailscale-IP: `http://100.100.119.4:11434/v1`

## In bestehende Hermes-Config mergen

Angenommen, deine private Hermes-Konfiguration hat bereits `providers` und `fallback_providers`. Füge **nur** den neuen Block hinzu — kein Dump der gesamten Datei hier.

### Schritt 1: Provider registrieren

Unter `providers:` den Schlüssel `mbp-ollama` einfügen (siehe Template oben).

### Schritt 2: Fallback-Kette erweitern

`mbp-ollama` **am Ende** der Kette platzieren — echtes Last-Resort, wenn lokale und Cloud-Provider nicht liefern:

```yaml
# Template — Struktur kann je nach Hermes-Version leicht abweichen
fallback_providers:
  - local-primary          # z.B. lokaler Provider auf pop-os
  - cloud-backup           # z.B. externer API-Provider (Key nur lokal!)
  - mbp-ollama             # Last-Resort: MBP über Tailscale
```

Alternativ, wenn Hermes pro-Modell-Fallbacks nutzt:

```yaml
# Beispiel-Template
models:
  default:
    provider: local-primary
    fallback:
      - cloud-backup
      - mbp-ollama
```

**Regel:** `mbp-ollama` immer **zuletzt** — hohe Latenz, MBP kann schlafen, große Modelle langsam.

## Modell-Reihenfolge

Innerhalb `mbp-ollama.models` (und als `default_model`):

| Priorität | Modell | Anmerkung |
|-----------|--------|-----------|
| 1 | `mistral:latest` | tool_calls von ThinkPad verifiziert |
| 2 | `gpt-oss:20b` | overnight-tauglich |
| 3 | `gemma4:26b` | mittlere Last |
| 4+ | `qwen3.5:35b`, `qwen3.6:35b-a3b`, `muse-glimmer:30b-mlx` | schwer, MLX — nur wenn nötig |

`default_model` auf `mistral:latest` lassen.

## tool_calls — kritisch für Hermes

Hermes-Agenten erwarten OpenAI-kompatibles **Tool-Calling**:

- Endpoint: `POST /v1/chat/completions` mit `tools` und Antwort `message.tool_calls`.

**Verifiziert (ThinkPad → MBP):**

- `mistral:latest` — **funktioniert**

**Nicht als Primary Fallback:**

- `qwen3:8b`, `qwen2.5-coder:7b` — werben `tools` an, emittieren aber oft **keine** `tool_calls`

Vor Produktiv-Nutzung:

```bash
export MESH_COMPUTE_URL="http://samuel-mbp:11434/v1"
export MODEL="mistral:latest"
./scripts/smoke-tool-calls.sh
```

## Overnight / Timeouts

Lange Prompts (~19k Tokens) auf großen Modellen (35B, MLX) können **timeouten**. Für unbeaufsichtigte Läufe:

1. `mistral:latest` als erstes Modell in der Kette
2. MBP wach halten: [KEEP-AWAKE.md](KEEP-AWAKE.md)
3. Ollama erreichbar: [OLLAMA-EXPOSE.md](OLLAMA-EXPOSE.md)

## Secrets

| Erlaubt im Repo | Nur lokal (gitignored) |
|-----------------|------------------------|
| `examples/hermes-provider.mbp-ollama.yaml` | `hermes.yaml`, `hermes.local.*` |
| Hostname/IP-Beispiele | API-Keys für Cloud-Provider |
| Scripts ohne Credentials | Vollständige Hermes-Config |

Cloud-Provider in `fallback_providers` **vor** `mbp-ollama` behalten deren Keys ausschließlich in privaten, nicht versionierten Dateien.
