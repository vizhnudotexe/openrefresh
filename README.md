# AutoRefresh — SideStore Companion

> **No jailbreak. No PC. No more forgetting.** Automated 7-day refresh for your sideloaded apps.

[![Build IPA](https://github.com/vizhnudotexe/openrefresh/actions/workflows/build-ipa.yml/badge.svg)](https://github.com/vizhnudotexe/openrefresh/actions/workflows/build-ipa.yml)

---

## Download Latest IPA

**[→ Releases](https://github.com/vizhnudotexe/openrefresh/releases/latest)**  
Download `AutoRefresh.ipa` from the latest release → install via SideStore.

---

## What It Does

- **BGProcessingTask** fires automatically while your iPhone charges
- Checks if last SideStore refresh was ≥ 3 days ago (configurable, default 3 days)
- If due: opens your `SideStore Refresh` shortcut via `shortcuts://` URL scheme
- If that's blocked by iOS sandbox: posts a tap-able notification as fallback
- Logs every action in-app. Configurable threshold, shortcut name, charging wait time.

## Two-Layer Reliability

| Layer | Trigger | Notes |
|-------|---------|-------|
| **Charger automation** | Every plug-in | iOS fires this synchronously — most reliable |
| **BGProcessingTask** | Charging ≥ 15min + network | Catches missed plug-in automations |

Both call the same `SideStore Refresh` shortcut you build once.

## Install

### Option A — via GitHub Release (easiest)

1. Go to [Releases](https://github.com/vizhnudotexe/openrefresh/releases/latest)
2. Download `AutoRefresh.ipa`
3. Sideload into SideStore (tap **+** → select the IPA)
4. Open AutoRefresh once → allow notifications

### Option B — build yourself

```bash
git clone https://github.com/vizhnudotexe/openrefresh
open openrefresh/AutoRefresh/AutoRefresh.xcodeproj
# Set your Team in Signing & Capabilities → Product → Archive → Export
```

---

## Shortcut Setup (one-time, 2 minutes)

See [`SHORTCUT_BUILD_GUIDE.md`](AutoRefresh/SHORTCUT_BUILD_GUIDE.md) for exact steps.

**Summary:**
1. New shortcut named `SideStore Refresh`
2. Connect VPN → Wait 30s → SideStore "Refresh All Apps" → Disconnect VPN
3. Automation → Charger → Is Connected → Run Immediately → Run this shortcut

---

## Settings (in-app)

| Setting | Default | Range |
|---------|---------|-------|
| Shortcut name | `SideStore Refresh` | Any |
| Refresh threshold | 3 days | 1–6 days |
| Min charging time | 15 min | 5–60 min |

---

## Requirements

- iPhone with iOS 16+
- SideStore installed
- StosVPN / LocalDevVPN configured
- Background App Refresh ON (Settings → General → Background App Refresh)

## Hard Limit (no jailbreak)

The 7-day expiry is kernel-enforced. There is no bypass without jailbreak.  
This tool makes refresh **fully automatic** so you never have to think about it.

---

MIT License
