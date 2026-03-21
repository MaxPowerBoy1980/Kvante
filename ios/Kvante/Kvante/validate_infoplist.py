#!/usr/bin/env python3
"""
Validate that Info.plist is properly configured in the built app.
Run this after building to verify all required keys are present.
"""

import sys
import os
import plistlib
import subprocess
from pathlib import Path

REQUIRED_KEYS = {
    'NSBonjourServices': list,
    'NSLocalNetworkUsageDescription': str,
    'NSCameraUsageDescription': str,
}

def find_built_app():
    """Find the most recently built Kvante.app in DerivedData."""
    home = Path.home()
    derived_data = home / 'Library' / 'Developer' / 'Xcode' / 'DerivedData'
    
    if not derived_data.exists():
        return None
    
    # Find all Kvante.app bundles
    apps = list(derived_data.glob('**/Kvante.app'))
    
    if not apps:
        return None
    
    # Return the most recently modified
    return max(apps, key=lambda p: p.stat().st_mtime)

def validate_infoplist(app_path):
    """Validate Info.plist in the built app."""
    info_plist_path = app_path / 'Info.plist'
    
    if not info_plist_path.exists():
        print(f"❌ Info.plist not found in {app_path}")
        return False
    
    print(f"📱 Checking Info.plist in: {app_path.name}")
    print(f"   Path: {info_plist_path}")
    print()
    
    # Read the plist
    try:
        with open(info_plist_path, 'rb') as f:
            plist = plistlib.load(f)
    except Exception as e:
        print(f"❌ Failed to read Info.plist: {e}")
        return False
    
    # Check required keys
    all_valid = True
    
    for key, expected_type in REQUIRED_KEYS.items():
        if key not in plist:
            print(f"❌ Missing key: {key}")
            all_valid = False
            continue
        
        value = plist[key]
        
        if not isinstance(value, expected_type):
            print(f"❌ Wrong type for {key}: expected {expected_type.__name__}, got {type(value).__name__}")
            all_valid = False
            continue
        
        if expected_type == str and not value:
            print(f"⚠️  Empty value for {key}")
            all_valid = False
            continue
        
        if expected_type == list and not value:
            print(f"⚠️  Empty array for {key}")
            all_valid = False
            continue
        
        # Display the value
        if expected_type == str:
            print(f"✓ {key}")
            print(f"  → {value}")
        elif expected_type == list:
            print(f"✓ {key}")
            for item in value:
                print(f"  → {item}")
        print()
    
    # Special validation for NSBonjourServices
    if 'NSBonjourServices' in plist:
        services = plist['NSBonjourServices']
        if '_kvante._tcp' not in services:
            print("⚠️  NSBonjourServices doesn't contain '_kvante._tcp'")
            print(f"   Current value: {services}")
            all_valid = False
    
    return all_valid

def main():
    print("━" * 70)
    print("Kvante Info.plist Validator")
    print("━" * 70)
    print()
    
    # Try to find the built app
    if len(sys.argv) > 1:
        app_path = Path(sys.argv[1])
    else:
        print("🔍 Looking for built Kvante.app in DerivedData...")
        app_path = find_built_app()
        
        if not app_path:
            print("❌ Could not find Kvante.app")
            print("\nPlease either:")
            print("1. Build the app first (⌘B in Xcode)")
            print("2. Provide the path: python3 validate_infoplist.py /path/to/Kvante.app")
            sys.exit(1)
        
        print(f"✓ Found: {app_path}")
        print()
    
    if not app_path.exists():
        print(f"❌ App not found: {app_path}")
        sys.exit(1)
    
    # Validate
    if validate_infoplist(app_path):
        print("━" * 70)
        print("✅ All required Info.plist keys are present and valid!")
        print("━" * 70)
        print("\nYour app should now:")
        print("• Show camera permission prompt when scanning")
        print("• Show local network prompt when discovering servers")
        print("• Be able to use Bonjour/mDNS for server discovery")
    else:
        print("━" * 70)
        print("❌ Info.plist validation failed")
        print("━" * 70)
        print("\nTroubleshooting:")
        print("1. Check that Info.plist exists in ios/Kvante/Kvante/")
        print("2. Verify it's added to the Xcode project")
        print("3. Check Build Settings → Info.plist File setting")
        print("4. Clean build folder (⇧⌘K) and rebuild (⌘B)")
        print("\nSee INFO_PLIST_SETUP.md for detailed instructions")
        sys.exit(1)

if __name__ == '__main__':
    main()
