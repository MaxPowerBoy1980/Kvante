# 📋 Info.plist Setup for Kvante

This directory contains tools and documentation for adding the required Info.plist keys to your Kvante iOS app.

## 🎯 What You Need

Your Kvante app requires these three privacy/capability keys:

| Key | Purpose | Required For |
|-----|---------|--------------|
| `NSBonjourServices` | Declare Bonjour service types | Local network service discovery |
| `NSLocalNetworkUsageDescription` | Explain local network usage | iOS 14+ local network permission |
| `NSCameraUsageDescription` | Explain camera usage | Document scanning with camera |

## 🚀 Quick Start

### Option 1: Xcode UI (Recommended) ⭐

This is the **easiest and safest** method:

1. Open `Kvante.xcodeproj` in Xcode
2. Select the **Kvante target** → **Info tab**
3. Click **+** to add keys:
   - `NSBonjourServices` (Array) → Add item: `_kvante._tcp`
   - `NSLocalNetworkUsageDescription` (String) → Add Danish description
   - `NSCameraUsageDescription` (String) → Add Danish description
4. Build & run!

**See [`INFO_PLIST_SETUP.md`](INFO_PLIST_SETUP.md) for detailed step-by-step instructions.**

### Option 2: Automated Script

Use the Python script to add the Info.plist file:

```bash
# Make sure Info.plist exists at ios/Kvante/Kvante/Info.plist
python3 add_infoplist.py ios/Kvante/Kvante.xcodeproj
```

Then open Xcode and configure Build Settings → Info.plist File.

## 📁 Files in This Directory

### Documentation
- **`INFO_PLIST_SETUP.md`** - Complete setup guide with all methods
- **`README_INFOPLIST.md`** - This file

### Reference Files
- **`Info.plist`** - Template Info.plist with required keys (Danish text)

### Scripts
- **`add_infoplist.py`** - Python script to add Info.plist to project.pbxproj
- **`add_infoplist.sh`** - Bash script (alternative)
- **`validate_infoplist.py`** - Verify keys in built app

## 🔧 Validation

After setup, validate the configuration:

```bash
# Build the app in Xcode first (⌘B)
python3 validate_infoplist.py
```

This will check if all required keys are present in the built app.

## 📝 Reference Info.plist Content

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSBonjourServices</key>
    <array>
        <string>_kvante._tcp</string>
    </array>
    <key>NSLocalNetworkUsageDescription</key>
    <string>Kvante skal finde din lektiehjælp-server på det lokale netværk</string>
    <key>NSCameraUsageDescription</key>
    <string>Kvante skal bruge kameraet til at scanne dine lektiesider</string>
</dict>
</plist>
```

## 🧪 Testing Permissions

After adding the keys, test in the simulator or on a device:

1. **Camera Permission:**
   - Tap "Scan din side" button
   - Camera permission dialog should appear

2. **Local Network Permission:**
   - App launches
   - ServerDiscovery starts browsing
   - Local network permission dialog should appear

## 🔍 Troubleshooting

### Permission dialogs not appearing?

1. **Clean build:**
   ```
   Xcode → Product → Clean Build Folder (⇧⌘K)
   ```

2. **Delete and reinstall app** from simulator/device

3. **Verify keys in built app:**
   ```bash
   python3 validate_infoplist.py
   ```

### Project won't open after script?

1. **Restore from backup:**
   ```bash
   # Script creates timestamped backups
   ls ios/Kvante/Kvante.xcodeproj/*.backup*
   cp ios/Kvante/Kvante.xcodeproj/project.pbxproj.backup.TIMESTAMP \
      ios/Kvante/Kvante.xcodeproj/project.pbxproj
   ```

2. **Use Xcode UI method instead** (Option 1 above)

## 📚 Additional Resources

- [Apple Documentation: Information Property List](https://developer.apple.com/documentation/bundleresources/information_property_list)
- [Local Network Privacy](https://developer.apple.com/documentation/bundleresources/information_property_list/nslocalnetworkusagedescription)
- [Camera Usage Description](https://developer.apple.com/documentation/bundleresources/information_property_list/nscamerausagedescription)
- [Bonjour Services](https://developer.apple.com/documentation/bundleresources/information_property_list/nsbonjourservices)

## 💡 Modern Xcode Projects

Modern Xcode projects (Xcode 13+) **auto-generate** Info.plist at build time. You have two options:

1. **Add keys via Xcode UI** (recommended) - No separate file needed
2. **Use custom Info.plist** - Set `INFOPLIST_FILE` in Build Settings

Both approaches work! The UI method is simpler and less error-prone.

## ✅ Success Criteria

After proper setup, you should have:

- ✓ No build errors related to Info.plist
- ✓ Camera permission prompt appears when scanning
- ✓ Local network permission prompt appears (iOS 14+)
- ✓ ServerDiscovery can find Bonjour services
- ✓ `validate_infoplist.py` passes all checks

---

**Need help?** See [`INFO_PLIST_SETUP.md`](INFO_PLIST_SETUP.md) for detailed instructions.
