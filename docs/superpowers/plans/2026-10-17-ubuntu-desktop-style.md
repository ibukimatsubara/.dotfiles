# Ubuntu visual parity

User requested keeping macOS behavior while bringing Ubuntu's bar and terminal appearance closer to the existing macOS configuration. Baseline desktop is saved in 41a3a47.

- Keep macOS presets/config files intact; derive additional Ubuntu artifacts from their color/style tokens.
- Arrange timer and workspaces left, media center, usage and clock right. Remove the redundant focused-window title and menu grid from the default bar.
- Use attached or floating bar geometry according to the current preset, with matching module colors, outlines and corner radii.
- Apply an Ubuntu-only terminal background opacity of 0.78, preserving opaque text; disable the cursor shader to match macOS.
- Keep bar layout changes explicit, merge live DMS preferences and retain a backup. Routine theme changes update geometry/colors without overwriting widget choices.
- Validate fixture rendering/preferences, unchanged macOS-generated artifacts, Ghostty/Hyprland parsing, and a separate compositor preview before applying to the live session.

## Validation

Fixture tests cover preserved custom widgets/secondary bars, explicit layout, immutable generation selection and backups. Generated macOS artifacts remain byte-identical for Anime Blue and Walnut. A separate Hyprland preview confirms capsules, workspace colors and watched settings-file layout updates. Ghostty and Hyprland configs parse successfully. Existing compositor and applications are kept running during live application.
