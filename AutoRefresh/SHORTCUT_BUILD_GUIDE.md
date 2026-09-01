# SideStore Refresh Shortcut — Build Instructions
#
# iOS Shortcuts cannot be created programmatically from a .shortcut file in this repo
# because the format is binary/plist. Instead, build it manually in the Shortcuts app.
# The steps below are exact — take 2 minutes.
#
# ─────────────────────────────────────────────
#  SHORTCUT NAME (must match what AutoRefresh app is configured with):
#    "SideStore Refresh"
# ─────────────────────────────────────────────
#
# STEP 1: Open Shortcuts app → tap "+" (new shortcut)
# STEP 2: Tap the shortcut name at top → rename to: SideStore Refresh
#
# ACTION 1: Set Variable
#   Variable name: refreshNeeded
#   Value: (leave empty — we'll set it in the automation)
#
# ACTION 2: Connect to VPN
#   VPN: [Select your StosVPN / LocalDevVPN profile]
#
# ACTION 3: Wait
#   Duration: 30 seconds
#   (Gives VPN time to establish before signing handshake)
#
# ACTION 4: [SideStore] Refresh All Apps
#   → Search "SideStore" in the action search bar
#   → Pick "Refresh All Apps"
#
# ACTION 5: Disconnect from VPN
#   VPN: [Same StosVPN / LocalDevVPN profile]
#
# ACTION 6: Wait
#   Duration: 5 seconds
#
# ─────────────────────────────────────────────
# AUTOMATION SETUP (optional but recommended as parallel backup):
# ─────────────────────────────────────────────
#
# Go to Automation tab → New Automation → Charger → "Is Connected"
# Toggle: Run Immediately = ON
# Toggle: Notify When Run = OFF
#
# Add action: "Run Shortcut" → pick "SideStore Refresh"
# Save.
#
# This creates TWO paths for reliability:
#   Path A: AutoRefresh IPA BGProcessingTask → opens shortcut when charging ≥ threshold
#   Path B: Charger automation → also runs shortcut on plug-in (immediate)
#
# Path B catches cases where BGTask is delayed/killed.
# Path A catches cases where shortcut app is backgrounded and automation fails.
# Together they cover nearly all edge cases without jailbreak.
#
# ─────────────────────────────────────────────
# TROUBLESHOOTING:
# ─────────────────────────────────────────────
# - "Unknown Action" on SideStore Refresh All Apps:
#     Delete the action → re-search "SideStore" → re-add it
#
# - VPN not connecting in shortcut:
#     Increase Wait time after Connect to VPN from 30s → 45s
#
# - Shortcut runs but apps still expire:
#     In SideStore Settings → re-enable "Allow Siri / Shortcuts"
#
# - AutoRefresh IPA itself expires:
#     SideStore auto-refreshes it along with your other apps when it runs
#
# - BGTask never fires:
#     Settings → General → Background App Refresh → ON (global + AutoRefresh)
#     Low Power Mode OFF (suppresses BGProcessingTask entirely)
