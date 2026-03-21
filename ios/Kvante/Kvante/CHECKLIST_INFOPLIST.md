# ✅ Info.plist Setup Checklist

Quick reference for adding Info.plist to your Kvante Xcode project.

## Prerequisites

- [ ] Info.plist file exists at `ios/Kvante/Kvante/Info.plist`
- [ ] Info.plist contains all three required keys:
  - [ ] `NSBonjourServices` (Array with `_kvante._tcp`)
  - [ ] `NSLocalNetworkUsageDescription` (String)
  - [ ] `NSCameraUsageDescription` (String)

## Method 1: Xcode UI (Recommended) ⭐

- [ ] Open `ios/Kvante/Kvante.xcodeproj` in Xcode
- [ ] Select **Kvante** target in Project Navigator
- [ ] Go to **Info** tab
- [ ] Add `NSBonjourServices`:
  - [ ] Type: Array
  - [ ] Add string item: `_kvante._tcp`
- [ ] Add `NSLocalNetworkUsageDescription`:
  - [ ] Type: String
  - [ ] Value: `Kvante skal finde din lektiehjælp-server på det lokale netværk`
- [ ] Add `NSCameraUsageDescription`:
  - [ ] Type: String
  - [ ] Value: `Kvante skal bruge kameraet til at scanne dine lektiesider`
- [ ] Clean build folder: **Product → Clean Build Folder** (⇧⌘K)
- [ ] Build: **Product → Build** (⌘B)
- [ ] Run validation: `python3 validate_infoplist.py`

## Method 2: Automated Script

- [ ] Backup project: `cp ios/Kvante/Kvante.xcodeproj/project.pbxproj{,.backup}`
- [ ] Run script: `python3 add_infoplist.py ios/Kvante/Kvante.xcodeproj`
- [ ] Open Xcode
- [ ] Verify Info.plist appears in Project Navigator
- [ ] Go to **Kvante target → Build Settings**
- [ ] Search for "Info.plist File"
- [ ] Set value to: `Kvante/Info.plist`
- [ ] Set "Generate Info.plist File" to **NO** (or **YES** to merge)
- [ ] Clean build folder: **Product → Clean Build Folder** (⇧⌘K)
- [ ] Build: **Product → Build** (⌘B)
- [ ] Run validation: `python3 validate_infoplist.py`

## Method 3: Manual File Addition

- [ ] Right-click "Kvante" folder in Xcode Project Navigator
- [ ] Select **Add Files to "Kvante"...**
- [ ] Navigate to `ios/Kvante/Kvante/Info.plist`
- [ ] Check "Copy items if needed"
- [ ] Check "Kvante" target
- [ ] Click **Add**
- [ ] Go to **Kvante target → Build Settings**
- [ ] Search for "Info.plist File"
- [ ] Set to: `Kvante/Info.plist`
- [ ] Clean & Build
- [ ] Run validation

## Validation

- [ ] Build succeeds without errors
- [ ] Run `python3 validate_infoplist.py` - all checks pass
- [ ] Camera permission prompt appears when tapping "Scan din side"
- [ ] Local network permission prompt appears on first Bonjour discovery
- [ ] ServerDiscovery can find `_kvante._tcp` services

## Troubleshooting

If something goes wrong:

- [ ] Check Build Settings → Info.plist File path is correct
- [ ] Verify file is in Kvante target (not just the project)
- [ ] Clean build folder (⇧⌘K)
- [ ] Delete app from simulator/device
- [ ] Rebuild and reinstall
- [ ] Check Console.app for permission-related errors

## Success! 🎉

When everything works:

- ✅ App builds without Info.plist errors
- ✅ Permission prompts appear correctly
- ✅ Server discovery works
- ✅ Document scanning works
- ✅ App can be submitted to App Store (all privacy keys declared)

---

**Current Status:** (Update as you progress)

- [ ] Info.plist created
- [ ] Added to Xcode project
- [ ] Build settings configured
- [ ] Validation passed
- [ ] Tested camera permission
- [ ] Tested network permission
- [ ] Ready for production ✨
