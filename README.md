# Enhanced Experience for Claude Code

A portable configuration layer that makes Claude Code more responsive to work with — you *hear* what it's doing and *see* where you stand, without watching the transcript.

Install it on any machine and your setup comes with you.

```
📁 my-project | 🌿 main +142/-38 | [Opus 5 (1M context) · high] | 💰 $0.2344

⠹ 2h 14m | ⚡ 5hr: 42% | 📅 weekly: 18% | ⏳ Resets in 2h45m / 5d22h | ctx: ██████████░░░░░░░░░░░░ 42%
```

- 🔊 **Sounds** — audio notifications for every Claude Code event
- 📊 **Status line** — a two-line bottom bar with model, effort, cost, timing, lines changed, rate limits, and context usage

## Installation

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/ulisestame/Enhanced-Experience-Claude-Code/main/install.sh)
```

Restart Claude Code and you're set.

Install a single component:

```bash
# sounds only
bash <(curl -fsSL https://raw.githubusercontent.com/ulisestame/Enhanced-Experience-Claude-Code/main/install.sh) --sounds-only

# status line only
bash <(curl -fsSL https://raw.githubusercontent.com/ulisestame/Enhanced-Experience-Claude-Code/main/install.sh) --statusline-only
```

Your existing settings are preserved — the installer only merges in the keys it owns (`hooks` and `statusLine`). Everything else in `~/.claude/settings.json` is left untouched.

Prefer to read before you run? The installer is a single readable [`install.sh`](install.sh) — clone the repo and run it locally instead.

## Status Line

**Line 1** — where you are and what it costs: directory, git branch with the lines changed beside it (both omitted outside a repo), model and its effort level, session cost.

**Line 2** — how the session is going: a spinner and the elapsed time, rate limit usage, when each limit resets, and a context-window bar.

Details worth knowing:

- **Effort** (`· high`) appears only on models that support it, so it is absent on models like Haiku rather than showing an empty slot.
- **Elapsed time** measures how long the session has been open and scales to its own magnitude — `45s`, `6m 12s`, `3h 20m`, `4d 20h` — so a session left open for days stays readable instead of reporting five-digit minutes. The braille spinner in front of it turns once a second.
- **Lines changed** (`+142/-38`, green and red) counts what Claude edited this session, not your own edits or what is already committed. The segment is hidden entirely when nothing has been touched.
- **Rate limits and resets** render only when the session data includes them. Reset values follow the same order as the percentages above them: 5hr first, then weekly.
- **The context bar** is a 22-cell truecolor gradient running green → red, and the percentage after it takes the gradient's color at its own position. Cells are painted with background color rather than block glyphs: block characters fall a pixel short of the cell in many fonts, which shows up as a notch along the bar.

A blank row separates the two lines.

The session name is deliberately absent — Claude Code already shows it above the prompt.

Requires [`jq`](https://jqlang.github.io/jq/) (`brew install jq`).

### Keeping it current

The status line re-runs on events — a message, a finished turn, a model or effort change. Values read from the clock would otherwise freeze between events: the spinner stops, and the elapsed time and reset countdowns go stale on an idle session. The installer sets `refreshInterval` so the bar also re-renders on a timer:

```json
"statusLine": {
  "type": "command",
  "command": "~/.claude/statusline.sh",
  "padding": 1,
  "refreshInterval": 1
}
```

One second is the minimum Claude Code accepts, and it is what the spinner needs to turn. The whole script runs on every tick, so it reads the session payload in a single `jq` pass to keep that cheap — about 20ms per render. Raise the interval if you would rather trade the animation for fewer wakeups; the bar stays correct either way.

The script installs to `~/.claude/statusline.sh` — edit it freely to change segments, bar width, or color thresholds. See the [status line docs](https://code.claude.com/docs/en/statusline).

## Sounds

| File | Event |
|------|-------|
| `start_claude_sound.wav` | Session initialized |
| `claude_finished_task_01.wav` | Claude finished responding (variant 1) |
| `claude_finished_task_02.wav` | Claude finished responding (variant 2) |
| `claude_finished_task_03.wav` | Claude finished responding (variant 3) |
| `notification_user_input.wav` | Waiting for user input/approval |
| `tool_call_failed.wav` | Tool execution failed |
| `error.wav` | Error occurred |
| `compact_claude_session.wav` | Context being compacted |
| `sub-starts.wav` | Subagent spawned |
| `sub-ready.wav` | Subagent finished |
| `session_end.wav` | Session ended |

Sound files are copied to `~/.claude/sounds/` and wired up as hooks. Edit `~/.claude/settings.json` to change paths, swap in your own sounds, adjust volume with the `-v` flag (0.0–1.0), or disable individual hooks:

```json
"command": "afplay -v 0.3 ~/.claude/sounds/start_claude_sound.wav"
```

See the [hooks docs](https://code.claude.com/docs/en/hooks) for the full event list.

## Troubleshooting

**No sound?**
- Sounds play through system audio, not terminal output — check system volume
- Verify files exist: `ls ~/.claude/sounds/`
- Test directly: `afplay ~/.claude/sounds/start_claude_sound.wav`

**Status line blank or broken?**
- Confirm `jq` is installed: `command -v jq`
- Test it directly: `echo '{}' | ~/.claude/statusline.sh`
- Make sure it's executable: `chmod +x ~/.claude/statusline.sh`

**Either not applying?**
- Check settings syntax: `python3 -m json.tool ~/.claude/settings.json`
- Restart Claude Code

## Platform

Built and tested on macOS. Sounds use `afplay`; swapping in `paplay` or `aplay` ports them to Linux. The status line is portable as-is.

## Contributing

Issues and pull requests are welcome — new sound themes, status line variants, and additional config components all fit here.

Two things to keep in mind:

- **Use `~` paths, never absolute ones.** No `/Users/yourname/...` in committed files — it breaks the install for everyone else.
- **Keep the installer non-destructive.** It should merge into `~/.claude/settings.json`, never overwrite keys it doesn't own.

## License

MIT — see [LICENSE](LICENSE).
