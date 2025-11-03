# PushupTrainer Widget Setup Guide

## Overview
I've created two beautiful, interactive widgets for your PushupTrainer app:
1. **Medium Widget** - This Week Summary (shows total reps, workouts, and streak)
2. **Large Widget** - Activity Overview with Bar Chart (displays last 7 days activity)

## Files Created

### Widget Extension Files:
- `PushupTrainerWidget/PushupTrainerWidget.swift` - Main widget code
- `PushupTrainerWidget/Info.plist` - Widget configuration
- `PushupTrainerWidget/Assets.xcassets/` - Widget assets
- `PushupTrainerWidget/PushupTrainerWidget.entitlements` - App Group entitlements

### Main App Updates:
- `PushupTrainer/PushupTrainer.entitlements` - App Group entitlements
- `PushupTrainer/Models/WorkoutSession.swift` - Updated to share data with widgets
- `PushupTrainer/PushupTrainerApp.swift` - Added deep link handling
- `PushupTrainer/RootView.swift` - Added tab navigation from deep links

## Setup Steps in Xcode

### Step 1: Add Widget Extension Target

1. Open `PushupTrainer.xcodeproj` in Xcode
2. Click **File → New → Target**
3. Select **Widget Extension**
4. Configure the widget:
   - Product Name: `PushupTrainerWidget`
   - Team: Your development team
   - Include Configuration Intent: **NO** (uncheck this)
5. Click **Finish**
6. When prompted "Activate PushupTrainerWidget scheme?", click **Activate**

### Step 2: Replace Auto-Generated Files

1. In the Project Navigator, find the `PushupTrainerWidget` folder
2. Delete the auto-generated files:
   - `PushupTrainerWidget.swift` (delete)
   - `PushupTrainerWidgetBundle.swift` (delete if exists)
   - `PushupTrainerWidgetLiveActivity.swift` (delete if exists)
3. **Add our widget file**:
   - Right-click `PushupTrainerWidget` folder
   - Click **Add Files to "PushupTrainer"...**
   - Navigate to `/Users/shubhamgupta/Documents/Repo/PushupTrainer/PushupTrainerWidget/`
   - Select `PushupTrainerWidget.swift`
   - Check "Copy items if needed"
   - Target Membership: Check **PushupTrainerWidget**

### Step 3: Configure App Groups

#### For Main App:
1. Select `PushupTrainer` target
2. Go to **Signing & Capabilities**
3. Click **+ Capability**
4. Add **App Groups**
5. Click **+** and add: `group.com.coder.ai.PushupTrainer`
6. Check the checkbox next to the group name

#### For Widget:
1. Select `PushupTrainerWidget` target
2. Go to **Signing & Capabilities**
3. Click **+ Capability**
4. Add **App Groups**
5. Click **+** and add: `group.com.coder.ai.PushupTrainer`
6. Check the checkbox next to the group name

### Step 4: Add Entitlements Files

#### Main App:
1. Select `PushupTrainer` target
2. Go to **Build Settings**
3. Search for "Code Signing Entitlements"
4. Set value to: `PushupTrainer/PushupTrainer.entitlements`

#### Widget:
1. Select `PushupTrainerWidget` target
2. Go to **Build Settings**
3. Search for "Code Signing Entitlements"
4. Set value to: `PushupTrainerWidget/PushupTrainerWidget.entitlements`

### Step 5: Configure URL Scheme

1. Select `PushupTrainer` target
2. Go to **Info** tab
3. Expand **URL Types**
4. Click **+** to add new URL Type
5. Set:
   - Identifier: `com.coder.ai.PushupTrainer`
   - URL Schemes: `pushuptrainer`
   - Role: Editor

### Step 6: Update Info.plist for Widget

1. Select `PushupTrainerWidget` target
2. The `Info.plist` file should already be configured
3. Verify it contains:
   ```xml
   <key>NSExtension</key>
   <dict>
       <key>NSExtensionPointIdentifier</key>
       <string>com.apple.widgetkit-extension</string>
   </dict>
   ```

### Step 7: Build and Run

1. Select **PushupTrainer** scheme
2. Build the project: **Cmd + B**
3. Fix any build errors if they appear
4. Run on simulator or device: **Cmd + R**

## Testing the Widgets

### Add Widgets to Home Screen:

1. Long press on the home screen
2. Tap the **+** button in the top-left
3. Search for "PushupTrainer"
4. You'll see two widgets:
   - **This Week** (Medium) - Shows weekly summary
   - **Activity Overview** (Large) - Shows bar chart

### Test Deep Links:

Tap on either widget and it should:
- Medium widget → Opens app to Home tab
- Large widget → Opens app to Activity tab

## Widget Features

### Medium Widget "This Week":
- ✅ Total reps this week
- ✅ Number of workouts completed
- ✅ Current day streak
- ✅ Beautiful gradient background
- ✅ Tappable - opens to Home tab

### Large Widget "Activity Overview":
- ✅ Bar chart of last 7 days
- ✅ Total reps displayed prominently
- ✅ Quick stats: workouts, average reps, streak
- ✅ Color-coded bars (orange for days with workouts)
- ✅ iOS 16+ uses native Swift Charts
- ✅ iOS 15 fallback with custom bar chart
- ✅ Tappable - opens to Activity tab

## Data Syncing

The widgets automatically update when you:
- Complete a workout
- App data changes

Widgets refresh:
- Every 15 minutes automatically
- When you open the app
- When you force-refresh widgets

## Troubleshooting

### Widget Not Showing Data:
1. Make sure App Groups are enabled for both targets
2. Verify the group ID matches: `group.com.coder.ai.PushupTrainer`
3. Complete at least one workout in the app
4. Remove and re-add the widget

### Build Errors:
1. Clean build folder: **Shift + Cmd + K**
2. Delete derived data
3. Restart Xcode
4. Verify all files are added to correct targets

### Widget Not Updating:
1. Force quit the app
2. Remove and re-add widget
3. Check that `SessionStore.save()` is being called after workouts

## Customization

To change the App Group ID (if needed):
1. Update in both entitlements files
2. Update in `WorkoutSession.swift` (line 65)
3. Update in `PushupTrainerWidget.swift` (in `loadRecentSessions()`)

## Next Steps

Once the widget target is added and configured:
1. The widgets will appear in the widget gallery
2. Users can add them to their home screen
3. Data will sync automatically via App Groups
4. Deep links will navigate to the correct tabs

Enjoy your beautiful, functional widgets! 🎉

