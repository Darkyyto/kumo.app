<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/banner-dark.png">
    <img src="docs/banner-light.png" alt="Kumo" width="100%">
  </picture>
</p>

# Kumo

Kumo writes down your lectures and meetings as they happen. Press Start, read along while the words appear, press Stop, give it a name. Kumo then listens to the whole recording again with a more accurate model, fixes the words that were hard to hear and writes clean notes, a summary and flashcards (or minutes with action items).

Everything is on one page: Start at the top, everything you recorded before underneath, with search.

## How it works

- **Live transcript.** Words appear as people speak, on device. Quiet or distant voices are boosted and low hum is filtered out.
- **Safe recordings.** The transcript is saved every few seconds and the audio survives a crash. An interrupted recording is recovered the next time Kumo opens.
- **Notes.** After you stop, Apple Intelligence writes notes, a summary and flashcards. Turn it off in Settings if you only want the transcript.
- **Merge, export, search.** Join two parts of the same lecture, export as PDF, search titles, transcripts and notes.
- **Light on the battery.** No animation, nothing running while you are not recording.

## Privacy

There is no account, no analytics and no server. Audio, transcripts and notes stay on this Mac. Kumo goes online only to download the speech model for your language once, and to check GitHub for a new version, which you can turn off in Settings.

Record lectures and meetings only where you are allowed to, and ask first when in doubt.

## Building

Requires macOS 26, Xcode 26 and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
make run
```

| Command | What it does |
| --- | --- |
| `make run` | Builds a debug copy and opens it |
| `make dmg` | Builds a universal release in `dist/` |

## License

Kumo is free to use for personal, study and other noncommercial purposes under the [PolyForm Strict License 1.0.0](LICENSE).
