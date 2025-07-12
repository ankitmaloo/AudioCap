
# Branch Walkthrough: `notes`

This document outlines the key changes made in the `notes` branch. The primary focus of this branch is to transition the application from a standard windowed application to a menu bar application, providing a more lightweight and accessible user experience.

## Key Changes

### 1. Application Behavior: UIElement Mode

The application is now configured to run as a "UIElement." This is a significant change that affects how the application interacts with the system:

- **No Dock Icon:** The application will no longer appear in the Dock.
- **No Main Window:** The application doesn't have a main window in the traditional sense. Its interface is now accessed through the menu bar.

This change was made by adding the `INFOPLIST_KEY_LSUIElement` key to the `project.pbxproj` file.

### 2. User Interface: Menu Bar App

The application's user interface has been completely redesigned to work as a menu bar application:

- **`MenuBarExtra`:** The main application scene is now a `MenuBarExtra`, which places an icon in the system menu bar.
- **Dropdown View:** The `RootView` is now displayed within the menu bar's dropdown window, with a fixed width for a consistent appearance.

This was implemented in `AudioCap/AudioCapApp.swift`.

### 3. UI Refinements

To better suit the menu bar context, several UI elements have been refined:

- **`ProcessSelectionView`:** The `Section` has been replaced with a `VStack` for a cleaner and more compact layout.
- **`RootView`:** The `Form` has been replaced with a `VStack`, and padding has been added for a more modern and streamlined look.

These changes can be seen in `AudioCap/ProcessSelectionView.swift` and `AudioCap/RootView.swift`.

## Summary

The `notes` branch transforms the application into a menu bar utility. This provides a more seamless and integrated experience for the user, allowing them to access the app's functionality without cluttering their Dock or managing another window.
