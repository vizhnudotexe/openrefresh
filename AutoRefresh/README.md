# AutoRefresh — SideStore Companion IPA

Automated SideStore refresh companion for iOS 16+, no jailbreak required.

## What It Does

- Runs a **background processing task** that fires when your phone is charging
- Checks if your last SideStore refresh was ≥ 3 days ago (configurable)
- If yes + internet available → opens the `SideStore Refresh` shortcut automatically
- If background open is blocked → posts a local notification as fallback
- Stores last refresh time, shows logs, configurable via UI

## Architecture

```
BGProcessingTask (fires on charge + network)
    │
    ├─ Check: lastRefresh >= threshold (default 3 days)?
    │         NO → skip, reschedule
    │
    └─ YES → NWPathMonitor: network available?
                  NO → skip
                  YES → UIApplication.open("shortcuts://run-shortcut?name=SideStore Refresh")
                              │
                              ├─ Success → update lastRefreshDate, reschedule
                              └─ Blocked → post UNNotification fallback
```

## Two-Layer Reliability

| Layer | Trigger | Mechanism |
|-------|---------|-----------|
| Primary | Charger connected automation | Shortcuts `Charger → Is Connected → Run Immediately` |
| Secondary | BGProcessingTask | Fires when charging ≥ 15min + network, checked every cycle |

Both layers call the same `SideStore Refresh` shortcut.

## Build & Install

### Requirements
- Mac with Xcode 15+
- Apple Developer account (free tier works)
- SideStore installed on iPhone 13 iOS 18.0

### Steps

```bash
# 1. Open project
open AutoRefresh/AutoRefresh.xcodeproj

# 2. In Xcode:
#    - Select your iPhone as the run destination
#    - Product menu → Destination → iPhone 13 (your device)
#    - Set your Team in Signing & Capabilities
#    - Product → Archive
#    - Distribute → Ad Hoc or Development
#    - Export the .ipa

# 3. Install via SideStore
#    - Open SideStore → + → Browse → select the .ipa
#    - Or: drag .ipa to AltServer if you still have it set up

# Alternatively: direct Xcode run
#    Product → Run (with device connected)
```

### Post-Install Setup

1. Open AutoRefresh app once to register background task
2. Allow notifications when prompted
3. **Settings → General → Background App Refresh → ON** (globally and for AutoRefresh)
4. Build the shortcut per `SHORTCUT_BUILD_GUIDE.md`
5. Ensure shortcut name in AutoRefresh settings matches exactly

## Configuration (in-app)

| Setting | Default | Description |
|---------|---------|-------------|
| Shortcut Name | `SideStore Refresh` | Must match your Shortcuts app shortcut name exactly |
| Refresh Threshold | 3 days | How many days before triggering a refresh |
| Min. Charging Time | 15 min | BGTask earliest begin delay after scheduling |

## Why BGProcessingTask and Not BGAppRefreshTask?

`BGAppRefreshTask` has strict 30-second time limits and gets heavily throttled.  
`BGProcessingTask` can run for **several minutes**, allows `requiresExternalPower = true`,  
and is designed for exactly this kind of periodic background work.

## Limitations (no jailbreak)

- `UIApplication.open()` is sandboxed in background — iOS may block the Shortcuts URL  
  → Notification fallback covers this: tap → foreground → shortcut runs
- BGProcessingTask timing is system-controlled, not exact  
  → The Charger automation (Shortcuts) provides the reliable "always fires on plug-in" path
- SideStore `Refresh All Apps` Shortcuts action requires SideStore to have been opened recently  
  → Keep SideStore's own background refresh enabled

## Why This Is More Reliable Than Shortcuts Alone

Your current Shortcuts automation fails because:
1. SideStore's App Intent isn't in memory when Shortcuts runs headless
2. VPN wait times are too short or too long
3. iOS kills the Shortcuts background runner before the signing handshake completes

This app runs as a **native BGProcessingTask** which gets more CPU budget and doesn't  
depend on the Shortcuts background runner staying alive. The shortcut only needs to execute  
the SideStore action — the VPN and timing logic is handled by the shortcut directly with  
verified working timings (30s VPN wait).
