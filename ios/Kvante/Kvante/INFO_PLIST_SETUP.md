# Adding Info.plist to Kvante Xcode Project

## Background
Your Kvante app needs these privacy/capability keys:
- **NSBonjourServices**: For local network service discovery (finding your homework server)
- **NSLocalNetworkUsageDescription**: Required explanation for local network access
- **NSCameraUsageDescription**: Required explanation for camera usage (document scanning)

## ⭐ RECOMMENDED: Use Xcode Build Settings (Simplest)

Modern Xcode projects auto-generate Info.plist at build time. You can add custom keys without a separate file:

### Steps:

1. **Open Kvante.xcodeproj in Xcode**

2. **Select the Kvante target** (click on the blue project icon, then select "Kvante" under TARGETS)

3. **Go to the "Info" tab** (not Build Settings)

4. **Add the following keys** by clicking the `+` button:

   **Key 1: Bonjour Services**
   - Key: `NSBonjourServices` (or select "Bonjour services" from dropdown)
   - Type: Array
   - Add item (String): `_kvante._tcp`

   **Key 2: Local Network Usage**
   - Key: `NSLocalNetworkUsageDescription` (or "Privacy - Local Network Usage Description")
   - Type: String
   - Value: `Kvante skal finde din lektiehjælp-server på det lokale netværk`

   **Key 3: Camera Usage**
   - Key: `NSCameraUsageDescription` (or "Privacy - Camera Usage Description")
   - Type: String  
   - Value: `Kvante skal bruge kameraet til at scanne dine lektiesider`

5. **Verify in Build Settings:**
   - Go to Build Settings tab
   - Search for "Info.plist File"
   - Ensure **"Generate Info.plist File"** is set to **YES**
   - The path should be empty or point to the generated file

6. **Clean and rebuild:**
   ```
   Product → Clean Build Folder (⇧⌘K)
   Product → Build (⌘B)
   ```

✅ **This is the modern approach and works perfectly with auto-generated Info.plist!**

---

## Alternative: Use Custom Info.plist File

If you prefer a separate Info.plist file:

### Option A: Add via Xcode UI

1. **Add the file to Xcode:**
   - Right-click the "Kvante" folder in the Project Navigator
   - Select "Add Files to 'Kvante'..."
   - Navigate to `ios/Kvante/Kvante/Info.plist`
   - ✓ Check "Copy items if needed"
   - ✓ Ensure "Kvante" target is checked
   - Click "Add"

2. **Configure target to use it:**
   - Select Kvante target → Build Settings
   - Search for "Info.plist File"
   - Set `INFOPLIST_FILE` to `Kvante/Info.plist`
   - Keep "Generate Info.plist File" = NO (or YES to merge)

### Option B: Manual project.pbxproj Edit

⚠️ **Warning:** Editing project.pbxproj manually can break your project. Always backup first!

1. **Backup your project:**
   ```bash
   cp ios/Kvante/Kvante.xcodeproj/project.pbxproj ios/Kvante/Kvante.xcodeproj/project.pbxproj.backup
   ```

2. **Run the helper script:**
   ```bash
   chmod +x add_infoplist.sh
   ./add_infoplist.sh ios/Kvante/Kvante.xcodeproj
   ```

3. **Open in Xcode and verify:**
   - Open the project
   - Verify Info.plist appears in the Project Navigator
   - Check Build Settings → Info.plist File points to it

---

## Merging Custom + Auto-Generated Info.plist

If you want BOTH custom Info.plist AND auto-generation:

1. **Keep your Info.plist file** with the three keys
2. **In Build Settings:**
   - Set `INFOPLIST_FILE` to your custom file path
   - Set `GENERATE_INFOPLIST_FILE` to `YES`
3. **Xcode will merge:**
   - Auto-generated keys (bundle ID, version, etc.)
   - Your custom keys (privacy descriptions, Bonjour)

---

## Verification

After setup, verify the keys are included:

1. **Build the app** (⌘B)

2. **Check the built Info.plist:**
   ```bash
   # Find the built app
   find ~/Library/Developer/Xcode/DerivedData -name "Kvante.app" -type d
   
   # View its Info.plist
   plutil -p path/to/Kvante.app/Info.plist | grep -E "Bonjour|Camera|Network"
   ```

3. **Expected output:**
   ```
   "NSBonjourServices" => [
     0 => "_kvante._tcp"
   ]
   "NSCameraUsageDescription" => "Kvante skal bruge kameraet til at scanne dine lektiesider"
   "NSLocalNetworkUsageDescription" => "Kvante skal finde din lektiehjælp-server på det lokale netværk"
   ```

---

## Troubleshooting

### "Local network permission prompt not appearing"
- Ensure `NSBonjourServices` array contains `_kvante._tcp`
- Clean build folder and rebuild
- Delete app from simulator/device and reinstall

### "Camera permission prompt not appearing"  
- Verify `NSCameraUsageDescription` exists
- The key name is case-sensitive
- Value must be a non-empty string

### "Project won't open after manual edit"
- Restore from backup:
  ```bash
  cp ios/Kvante/Kvante.xcodeproj/project.pbxproj.backup \
     ios/Kvante/Kvante.xcodeproj/project.pbxproj
  ```
- Use Xcode UI method instead

---

## Testing

After adding the keys, test the permissions:

```swift
// In ServerDiscovery.swift - Local network access
// Permission prompt appears when starting NWBrowser

// In DocumentScannerView.swift - Camera access  
// Permission prompt appears when showing VNDocumentCameraViewController
```

Run the app and:
1. Tap "Scan din side" → Camera permission prompt should appear
2. ServerDiscovery starts → Local network prompt should appear (on first Bonjour browse)

---

## Reference Info.plist

The `Info.plist` file in this directory contains the three required keys with Danish descriptions appropriate for your app.

**File location:** `Info.plist`

You can copy this file to `ios/Kvante/Kvante/Info.plist` if needed.
