#!/usr/bin/env python3
"""
Add Info.plist to Xcode project.pbxproj file safely.
This script parses the project file and adds the Info.plist reference.
"""

import sys
import os
import re
import hashlib
from datetime import datetime

def generate_uuid():
    """Generate a pseudo-UUID for Xcode object IDs."""
    timestamp = datetime.now().isoformat()
    hash_obj = hashlib.md5(timestamp.encode())
    return hash_obj.hexdigest()[:24].upper()

def backup_file(filepath):
    """Create a backup of the project file."""
    backup_path = f"{filepath}.backup.{datetime.now().strftime('%Y%m%d_%H%M%S')}"
    with open(filepath, 'r') as f:
        content = f.read()
    with open(backup_path, 'w') as f:
        f.write(content)
    print(f"✓ Backup created: {backup_path}")
    return backup_path

def add_infoplist_to_project(pbxproj_path, infoplist_path="Kvante/Info.plist"):
    """Add Info.plist file reference to Xcode project."""
    
    if not os.path.exists(pbxproj_path):
        print(f"Error: {pbxproj_path} not found")
        return False
    
    # Backup first
    backup_file(pbxproj_path)
    
    # Read project file
    with open(pbxproj_path, 'r') as f:
        content = f.read()
    
    # Generate unique IDs
    file_ref_id = generate_uuid()
    
    # Check if Info.plist already exists
    if 'Info.plist' in content and 'PBXFileReference' in content:
        print("⚠️  Info.plist already exists in project")
        print("    Check if it's properly configured in Build Settings")
        return True
    
    # 1. Add PBXFileReference
    file_ref = f"\t\t{file_ref_id} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = \"<group>\"; }};\n"
    
    # Find the PBXFileReference section end marker
    pattern = r'(/\* End PBXFileReference section \*/)'
    content = re.sub(pattern, file_ref + r'\1', content)
    
    # 2. Add to main group (find the group with Swift files)
    # Look for a group that contains ContentView.swift
    group_pattern = r'(children = \((?:[^)]+ContentView\.swift[^)]+)\);)'
    
    def add_to_group(match):
        group_content = match.group(1)
        # Add Info.plist before the closing );
        return group_content.replace(');', f'\t\t\t\t{file_ref_id} /* Info.plist */,\n\t\t\t);')
    
    new_content = re.sub(group_pattern, add_to_group, content, flags=re.DOTALL)
    
    if new_content == content:
        print("⚠️  Could not find appropriate group to add Info.plist")
        print("    You may need to add it manually in Xcode")
        return False
    
    # Write modified content
    with open(pbxproj_path, 'w') as f:
        f.write(new_content)
    
    print("✓ Info.plist added to project.pbxproj")
    return True

def configure_build_settings(pbxproj_path):
    """Add build setting for Info.plist file."""
    with open(pbxproj_path, 'r') as f:
        content = f.read()
    
    # Find XCBuildConfiguration section for the app target
    # Look for existing INFOPLIST_FILE setting
    if 'INFOPLIST_FILE' in content:
        print("ℹ️  INFOPLIST_FILE already configured in build settings")
        return True
    
    print("ℹ️  You need to configure INFOPLIST_FILE in Build Settings")
    print("    Set it to: Kvante/Info.plist")
    print("    Or use Xcode UI: Target → Build Settings → Info.plist File")
    
    return True

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 add_infoplist.py path/to/Kvante.xcodeproj")
        print("\nExample:")
        print("  python3 add_infoplist.py ios/Kvante/Kvante.xcodeproj")
        sys.exit(1)
    
    xcodeproj = sys.argv[1]
    pbxproj = os.path.join(xcodeproj, 'project.pbxproj')
    
    print("━" * 60)
    print("Adding Info.plist to Xcode Project")
    print("━" * 60)
    
    if not add_infoplist_to_project(pbxproj):
        print("\n❌ Failed to add Info.plist")
        print("   Consider using the Xcode UI method instead (see INFO_PLIST_SETUP.md)")
        sys.exit(1)
    
    configure_build_settings(pbxproj)
    
    print("\n" + "━" * 60)
    print("✓ Done!")
    print("━" * 60)
    print("\nNext steps:")
    print("1. Open Kvante.xcodeproj in Xcode")
    print("2. Verify Info.plist appears in the Project Navigator")
    print("3. Go to Target → Build Settings")
    print("4. Search for 'Info.plist File'")
    print("5. Set to: Kvante/Info.plist")
    print("6. Ensure 'Generate Info.plist File' = NO (or YES to merge)")
    print("7. Clean build folder (⇧⌘K) and rebuild (⌘B)")
    print("\nSee INFO_PLIST_SETUP.md for detailed instructions")

if __name__ == '__main__':
    main()
