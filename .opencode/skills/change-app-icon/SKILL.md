---
name: change-app-icon
description: >
  Use when the user provides an image file (PNG/JPG) and asks to change the
  app icon. Automatically generates all Android icon densities, creates a
  new icon theme, and switches to it. Also handles updating the app name.
  Works with the qiaoqiao_companion Flutter project.
---

# Change App Icon

Given a user-provided image file, this skill replaces the Android app launcher
icon (and optionally the app name) in the qiaoqiao_companion Flutter project.

## Workflow

1. Ask the user for a **theme name** (short kebab-case, e.g. `halloween`,
   `birthday`, `newyear`). If they don't have a preference, use today's date
   like `theme_20260523`.

2. Confirm the image path exists. Accept common image formats (PNG, JPG/JPEG).
   If the format is not PNG, convert by renaming (PowerShell: `Copy-Item`).

3. Copy the image into the project:

   ```powershell
   Copy-Item -Path "<user-image>" -Destination "qiaoqiao_companion/assets/images/icons/<name>.png" -Force
   ```

4. Run the icon generation script:

   ```powershell
   powershell -ExecutionPolicy Bypass -File "qiaoqiao_companion/scripts/add_icon_theme.ps1" -Name <name> -ProjectDir (Resolve-Path "qiaoqiao_companion")
   ```

5. Update `strings.xml` to switch to the new theme (the Gradle task reads this):

   ```xml
   <!-- android/app/src/main/res/values/strings.xml -->
   <string name="app_icon_theme"><name></string>
   ```

6. Optionally ask if they want to change the app name too, and update
   `<string name="app_name">...</string>` in the same file.

7. Tell the user:
   ```
   Done! Rebuild the app with:
     cd qiaoqiao_companion
     flutter clean
     flutter build apk --debug
   ```

## How the Gradle task works

The `android/app/build.gradle.kts` has an `applyIconTheme` task that runs before
every build. It reads `<string name="app_icon_theme">` from `strings.xml`,
then:
1. Deletes old icon files from `src/main/res/`
2. Copies the theme's files from `src/icons/{theme}/res/` to `src/main/res/`

The `add_icon_theme.ps1` script creates both the theme source
(`src/icons/{name}/res/`) and directly writes into `src/main/res/`, so
the first-time setup works even without the Gradle task.

## Troubleshooting

If icons don't update on device:
1. `flutter clean` first (clears build cache)
2. Uninstall the old app from the device
3. Reboot the device (clears MIUI icon cache)
4. Install the new APK

## Notes

- All working directory references (`qiaoqiao_companion/...`) are relative to
  project root `D:\Developfile\baby-friends`.
- The `add_icon_theme.ps1` script handles all density generation and adaptive
  icon creation internally.
- If the script fails, check that `flutter_launcher_icons` is in
  `qiaoqiao_companion/pubspec.yaml` dev_dependencies and has been fetched
  via `flutter pub get`.
