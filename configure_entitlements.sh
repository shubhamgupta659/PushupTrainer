#!/bin/bash

# Script to configure entitlements in Xcode project

PROJECT_FILE="/Users/shubhamgupta/Documents/Repo/PushupTrainer/PushupTrainer.xcodeproj/project.pbxproj"

echo "Configuring entitlements for PushupTrainer..."

# Backup the project file
cp "$PROJECT_FILE" "$PROJECT_FILE.backup"

# Add entitlements to main app target (if not already present)
if ! grep -q "CODE_SIGN_ENTITLEMENTS.*PushupTrainer.entitlements" "$PROJECT_FILE"; then
    echo "Adding entitlements to main app..."
    # This would require complex pbxproj parsing
fi

echo "✅ Project file backed up at: $PROJECT_FILE.backup"
echo ""
echo "⚠️  Please follow these manual steps in Xcode:"
echo ""
echo "=== FOR MAIN APP (PushupTrainer) ==="
echo "1. Select 'PushupTrainer' target in Xcode"
echo "2. Go to 'Build Settings' tab"
echo "3. Click on 'All' and 'Combined' filters at the top"
echo "4. Search for: CODE_SIGN_ENTITLEMENTS"
echo "5. Double-click the empty field next to 'Code Signing Entitlements'"
echo "6. Enter: PushupTrainer/PushupTrainer.entitlements"
echo "7. Press Enter"
echo ""
echo "=== FOR WIDGET (PushupTrainerWidgetExtension) ==="
echo "8. Select 'PushupTrainerWidgetExtension' target in Xcode"
echo "9. Go to 'Build Settings' tab"
echo "10. Search for: CODE_SIGN_ENTITLEMENTS"
echo "11. Double-click the empty field"
echo "12. Enter: PushupTrainerWidget/PushupTrainerWidget.entitlements"
echo "13. Press Enter"
echo ""
echo "=== VERIFY APP GROUPS ==="
echo "14. Select 'PushupTrainer' target"
echo "15. Go to 'Signing & Capabilities' tab"
echo "16. Verify 'App Groups' capability exists with: group.com.coder.ai.PushupTrainer"
echo "17. If not, click '+Capability' → Add 'App Groups' → Add the group"
echo ""
echo "18. Select 'PushupTrainerWidgetExtension' target"
echo "19. Go to 'Signing & Capabilities' tab"
echo "20. Verify 'App Groups' capability exists with: group.com.coder.ai.PushupTrainer"
echo "21. If not, click '+Capability' → Add 'App Groups' → Add the group"
echo ""
echo "After completing these steps:"
echo "- Clean Build Folder (Shift+Cmd+K)"
echo "- Build (Cmd+B)"
echo "- Run (Cmd+R)"
echo ""

