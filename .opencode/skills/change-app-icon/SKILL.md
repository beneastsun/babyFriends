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

5. Update `strings.xml` to switch to the new theme:

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
     flutter build apk --release
   ```

## Notes

- All working directory references (`qiaoqiao_companion/...`) are relative to
  project root `D:\Developfile\baby-friends`.
- The `add_icon_theme.ps1` script handles all density generation and adaptive
  icon creation internally.
- If the script fails, check that `flutter_launcher_icons` is in
  `qiaoqiao_companion/pubspec.yaml` dev_dependencies and has been fetched
  via `flutter pub get`.
