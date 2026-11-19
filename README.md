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
| `--title` | `"ringabell"` | Notification title |
| `--subtitle` | — | Notification subtitle |
| `--message` | `"Ring a bell!"` | Notification body text |
| `--sound` | `"Glass"` | System sound name (Glass, Hero, Ping, etc.) |
| `--colors` | default palette | Comma-separated color names or `#hex` values |
| `--duration` | `3.5` | Seconds before auto-dismiss (0.5–30) |
| `--density` | `1.0` | Particle birthRate multiplier (0.1–5.0) |
| `--screen` | `all` | Screen for the visual effect: `all`, `main`, or a 0-based index in `NSScreen.screens` order (0 is the menu-bar display). An out-of-range index falls back to `main` |
| `--url` | — | URL/deeplink to open when notification is clicked |
| `--icon-file` | — | Custom notification image (png, jpg, gif; max 10 MB). Overrides `--icon` |
| `--no-notification` | off | Skip macOS notification |
| `--no-sound` | off | Skip system sound |
| `--list-sounds` | off | List available system sounds and exit |
| `--ignore-dnd` | off | Show effect and play sound even when Do Not Disturb / Focus is on |
| `--push` | — | Also push to your phone via `pushover`, end-to-end encrypted. With `--ignore-dnd`, sends emergency priority |
| `--push-sound` | — | Pushover sound, built-in (`persistent`, `alien`, `siren`, …) or uploaded. Defaults to `persistent` with `--ignore-dnd` |
| `--pushover-config` | — | Private (`chmod 600`) `KEY=value` file with the Pushover secrets, used instead of the environment |

When a Focus (Do Not Disturb included) is on, ringabell skips the visual effect and the sound; the notification is still delivered to Notification Center. Focus state is read from `~/Library/DoNotDisturb/DB/Assertions.json`; if the calling terminal can't read it, Focus is treated as off.

## Phone push (Pushover)

`--push pushover` sends the title, subtitle + message and `--url` to the [Pushover](https://pushover.net) app, encrypted with a key only you and your phone hold, so Pushover's servers never see the content. Setup:

1. Install Pushover on the phone, create an application at pushover.net to get an API token.
2. Generate a key with `openssl rand -hex 32` and enter it in the Pushover app's end-to-end encryption settings.
3. Provide `PUSHOVER_TOKEN`, `PUSHOVER_USER` (your user key) and `PUSHOVER_E2E_KEY`, either as environment variables or as `KEY=value` lines in a file passed with `--pushover-config <path>`. The file must be owned by you and `chmod 600`. With 1Password, keep a template of `op://` references and render it once: `op inject -i pushover.env.tpl -o ~/.config/ringabell/pushover.env && chmod 600 ~/.config/ringabell/pushover.env`.

With `--ignore-dnd` the push uses emergency priority: it bypasses the phone's silent switch and Focus (allow Critical Alerts for Pushover) and repeats every 60s for up to an hour until acknowledged, playing the long `persistent` sound unless `--push-sound` overrides it. With an Apple Watch on your wrist, iOS delivers to the watch instead of sounding the phone; turn off Pushover mirroring in the Watch app if pages must ring the phone. ringabell exits 1 if the push fails.
