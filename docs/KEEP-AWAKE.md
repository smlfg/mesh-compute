# MBP wach halten (Keep-Awake)

Damit Hermes auf dem ThinkPad nachts noch auf Ollama am MBP (`samuel-mbp`) zugreifen kann, muss der Mac **nicht in den Schlaf** fallen.

Zwei ergänzende Mechanismen — beide dokumentieren:

1. **LaunchAgent + `caffeinate`** (dieses Repo, ohne sudo)
2. **`pmset`** (System-Schlafverhalten, oft sudo nötig)

## Pfad 1: LaunchAgent (empfohlen, repo-gestützt)

### Was es tut

LaunchAgent `com.samuel.mbp-inference-awake` startet:

```bash
/usr/bin/caffeinate -dims
```

| Flag | Bedeutung |
|------|-----------|
| `-d` | Display darf nicht schlafen |
| `-i` | System idle sleep verhindern |
| `-m` | Disk idle sleep verhindern |
| `-s` | System sleep verhindern (auf AC — bei Batterie Verhalten beachten) |

`KeepAlive: true` — launchd startet `caffeinate` neu, falls der Prozess endet.

### Installation

```bash
./scripts/install-keep-awake-macos.sh
```

Kopiert [examples/com.samuel.mbp-inference-awake.plist](../examples/com.samuel.mbp-inference-awake.plist) nach `~/Library/LaunchAgents/` und lädt den Agent.

### Status prüfen

```bash
launchctl print "gui/$(id -u)/com.samuel.mbp-inference-awake"
pgrep -lf caffeinate
```

### Deinstallieren

```bash
launchctl bootout "gui/$(id -u)" ~/Library/LaunchAgents/com.samuel.mbp-inference-awake.plist
rm ~/Library/LaunchAgents/com.samuel.mbp-inference-awake.plist
```

## Pfad 2: pmset (System-Schlaf)

**Hinweis:** Ohne sudo zeigt `pmset -g` oft weiterhin `sleep 1` — der LaunchAgent-Pfad oben kompensiert das für Inference-Overnight **teilweise**, aber für maximale Zuverlässigkeit pmset anpassen.

### Aktuellen Stand anzeigen

```bash
pmset -g
```

Typische Ausgabe ohne sudo-Anpassung:

```
 sleep           1
 disksleep       10
 displaysleep    10
 ...
```

`sleep 1` bedeutet: System kann nach 1 Minute idle schlafen — **caffeinate -dims** soll das abfangen, solange der Agent läuft.

### Mit sudo dauerhaft deaktivieren (optional)

```bash
sudo pmset -a sleep 0 disksleep 0 displaysleep 0
```

| Einstellung | Wert | Effekt |
|-------------|------|--------|
| `sleep` | `0` | Kein System-Sleep |
| `disksleep` | `0` | Festplatte bleibt wach |
| `displaysleep` | `0` oder höher | Display darf dimmen/aus (Strom sparen) |

### Zurücksetzen (Beispiel Standard-Laptop)

```bash
sudo pmset -a sleep 1 disksleep 10 displaysleep 10
```

## Beide Pfade kombinieren

| Szenario | Empfehlung |
|----------|------------|
| Kurzer Abend-Test | Nur LaunchAgent |
| Overnight Inference | LaunchAgent **+** `pmset sleep 0` (sudo) |
| Batteriebetrieb | `caffeinate` ohne `-s` erwägen; Display-Sleep OK |

## Abhängigkeiten

- Ollama muss laufen: [OLLAMA-EXPOSE.md](OLLAMA-EXPOSE.md)
- Tailscale muss verbunden bleiben (eigener Tailscale-Client, kein Sleep-Kill)
- ThinkPad smoke test nach Setup:

```bash
./scripts/check-mesh-endpoint.sh
```

## Strom / Wärme

Overnight mit großen Modellen (35B, MLX) erzeugt Last und Wärme. MBP gelüftet abstellen; bei Bedarf kleineres Modell (`mistral:latest`) in Hermes priorisieren — siehe [HERMES-FALLBACK.md](HERMES-FALLBACK.md).
