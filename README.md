# ringabell

macOS CLI that fires confetti, plays a sound, and sends a notification.

## Install

```
brew install uwinx/tap/ringabell
```

## Usage

```
ringabell [options]
```

| Flag | Default | Description |
|------|---------|-------------|
| `--message` | `"Ring a bell!"` | Notification body text |
| `--sound` | `"Glass"` | System sound name (Glass, Hero, Ping, etc.) |
| `--colors` | default palette | Comma-separated color names or `#hex` values |
| `--duration` | `3.5` | Seconds before auto-dismiss (0.5–30) |
| `--density` | `1.0` | Particle birthRate multiplier (0.1–5.0) |
| `--url` | — | URL/deeplink to open when notification is clicked |
| `--no-notification` | off | Skip macOS notification |
| `--ignore-dnd` | off | Show effect and play sound even when Do Not Disturb / Focus is on |

When a Focus (Do Not Disturb included) is on, ringabell skips the visual effect and the sound; the notification is still delivered to Notification Center. Focus state is read from `~/Library/DoNotDisturb/DB/Assertions.json`; if the calling terminal can't read it, Focus is treated as off.
