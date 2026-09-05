# Ollama über Tailscale exponieren

Ollama auf dem MBP (`samuel-mbp`) so konfigurieren, dass Hermes auf dem ThinkPad (`pop-os`) die **OpenAI-kompatible** API erreicht.

## Basis-Konfiguration

```bash
export OLLAMA_HOST=0.0.0.0
ollama serve
```

| Variable / Port | Wert | Bedeutung |
|-----------------|------|-----------|
| `OLLAMA_HOST` | `0.0.0.0` | Bindet auf alle Interfaces — **nötig** für Tailscale-Zugriff von anderen Knoten |
| Port | `11434` | Standard-Ollama-Port |
| OpenAI-Compat | `/v1` | Basis-URL: `http://<mbp>:11434/v1` |

### Persistenz (Shell-Profil / LaunchAgent)

In `~/.zshrc` oder `~/.bash_profile` auf dem MBP:

```bash
export OLLAMA_HOST=0.0.0.0
```

Oder als Umgebungsvariable im macOS-Ollama-App-Kontext / eigenem LaunchAgent — je nach Installationsweg.

## Erreichbarkeit

### MagicDNS (empfohlen)

```
http://samuel-mbp:11434/v1
```

Tailscale MagicDNS muss im Admin-Panel aktiv sein. Hostname ist der **Kurzname** des MBP im Tailnet.

### Tailscale-IP (Fallback)

```
http://100.100.119.4:11434/v1
```

IP mit `tailscale ip -4` auf dem MBP prüfen. Beispiel-IP `100.100.119.4` — in deiner Umgebung anpassen.

## API-Endpunkte (Vertrag)

| Methode | Pfad | Nutzung |
|---------|------|---------|
| `GET` | `/v1/models` | Health-Check, Modellliste |
| `POST` | `/v1/chat/completions` | Chat + `tools` / `tool_calls` |

### Health-Check vom ThinkPad

```bash
export MESH_COMPUTE_URL="http://samuel-mbp:11434/v1"
./scripts/check-mesh-endpoint.sh
```

Manuell:

```bash
curl -s "http://samuel-mbp:11434/v1/models" | jq .
```

## Firewall

### macOS

- Ollama lauscht auf `0.0.0.0:11434`.
- Tailscale-Traffic kommt über das `utun`-Interface; in der Regel kein zusätzlicher macOS-Firewall-Eintrag nötig, wenn „eingehende Verbindungen“ für den Ollama-Prozess erlaubt sind.
- Bei Problemen: Systemeinstellungen → Netzwerk → Firewall → Optionen für `ollama` prüfen.

### Tailscale ACLs (high-level)

Im Tailscale-Admin:

- **Default allow** im selben Tailnet reicht meist.
- Restriktiver: ACL-Regel, die `pop-os` → `samuel-mbp:11434` erlaubt und sonstigen Zugriff auf 11434 blockiert.
- Keine öffentliche Port-Freigabe am Router nötig — alles bleibt im Tailnet.

Beispiel-ACL-Skizze (nur Illustration — an eure Policy anpassen):

```json
{
  "acls": [
    {
      "action": "accept",
      "src": ["tag:thinkpad"],
      "dst": ["tag:mbp:11434"]
    }
  ]
}
```

## Sicherheit

- **Nicht** `OLLAMA_HOST=0.0.0.0` auf öffentlichen Interfaces ohne Tailscale — hier ist Tailscale die Absicherung.
- Kein API-Key bei Standard-Ollama; Zugriff = wer im Tailnet ist. ACLs nach Bedarf einschränken.
- Modell-Blobs (`~/.ollama/`) nicht ins Git — siehe `.gitignore`.

## Troubleshooting

| Symptom | Prüfung |
|---------|---------|
| Connection refused | `ollama serve` läuft? `OLLAMA_HOST=0.0.0.0`? |
| Timeout von pop-os | `tailscale ping samuel-mbp` vom ThinkPad |
| Leere Modellliste | `ollama list` auf MBP; Modelle pullen |
| tool_calls fehlen | Anderes Modell — siehe [HERMES-FALLBACK.md](HERMES-FALLBACK.md) |

## Verwandte Docs

- [KEEP-AWAKE.md](KEEP-AWAKE.md) — MBP muss für Overnight erreichbar bleiben
- [HERMES-FALLBACK.md](HERMES-FALLBACK.md) — Provider in Hermes einbinden
