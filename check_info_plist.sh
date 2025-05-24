#!/bin/bash

# Find all .xcodeproj directories
find . -name "*.xcodeproj" -type d | while read xcode_proj; do
  echo "Project: $xcode_proj"
  
  # Check project.pbxproj for Info.plist references
  echo "Checking for Info.plist references in project file:"
  grep -n "Info.plist" "$xcode_proj/project.pbxproj" | grep -v "ProjectBrowserInfoPlist"
  
  echo ""
done

echo "Checking for Info.plist files in the project:"
find . -name "Info.plist" -type f

echo ""
echo "Please use this information to resolve the Info.plist conflict in Xcode."
echo "Tip: Look for multiple INFOPLIST_FILE references in the build settings." 