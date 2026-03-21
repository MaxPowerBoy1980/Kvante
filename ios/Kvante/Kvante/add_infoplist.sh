#!/bin/bash

# Script to add Info.plist to Xcode project
# Usage: ./add_infoplist.sh path/to/Kvante.xcodeproj

set -e

PROJECT_PATH="$1"

if [ -z "$PROJECT_PATH" ]; then
    echo "Usage: $0 path/to/Kvante.xcodeproj"
    exit 1
fi

PBXPROJ="$PROJECT_PATH/project.pbxproj"

if [ ! -f "$PBXPROJ" ]; then
    echo "Error: project.pbxproj not found at $PBXPROJ"
    exit 1
fi

echo "Adding Info.plist to $PROJECT_PATH"

# Backup the project file
cp "$PBXPROJ" "$PBXPROJ.backup"

# Generate a unique file reference ID (using timestamp-based UUID-like format)
FILE_REF_ID="INFOPLIST$(date +%s)000000000000000"
BUILD_FILE_ID="BUILDINFO$(date +%s)000000000000000"

# Add the file reference
# Find the /* End PBXFileReference section */ line and add before it
perl -i -pe "if (/\/\* End PBXFileReference section \*\//) {
    print \"		$FILE_REF_ID /* Info.plist */ = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = \\\"<group>\\\"; };\n\";
}" "$PBXPROJ"

# Find the main group and add Info.plist to the file list
# This adds it to the group that contains other Swift files
perl -i -pe "if (/ContentView.swift in Sources/) {
    s/(ContentView.swift in Sources,)$/\$1\n				$FILE_REF_ID \/* Info.plist *\/,/;
}" "$PBXPROJ"

echo "✓ Info.plist added to project"
echo "✓ Backup saved as $PBXPROJ.backup"
echo ""
echo "Note: You still need to configure the build settings:"
echo "1. Open the project in Xcode"
echo "2. Select your target → Build Settings"
echo "3. Search for 'Info.plist'"
echo "4. Ensure 'Generate Info.plist File' is set to YES"
echo "5. The custom Info.plist values will merge automatically"
