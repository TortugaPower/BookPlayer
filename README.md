![BookPlayer](./.github/readme-header.png)

<p align="center">A wonderful player for your DRM-free audiobooks made in Swift and your help.</p>
<p align="center">
    <a href="https://itunes.apple.com/us/app/bookplayer-audio-book-player/id1138219998?ls=1&amp;mt=8">
        <img src="./.github/app-store-badge.svg" alt="Download on the App Store">
    </a>
</p>
<p align="center">
    <img src="./.github/list_screenshot.png" width="350" />
    <img src="./.github/player_screenshot.png" width="350" />
</p>



## Features

### Import

- Using [AirDrop](https://support.apple.com/en-us/HT204144#receive)
- From [Files](https://support.apple.com/en-us/ht206481) and other apps on your device
- Via [File Sharing](https://support.apple.com/en-us/HT201301) in iTunes

### Manage 

- Maintain and see progress of your books
- Mark books as finished
- Drag & Drop to sort your library
- Create playlists
    - Automatically play items in turn
    - Play the first unfinished file by tapping on the playlist artwork
    - Move files to playlists from the library or import them directly

### Listen

- Control audio playback from the lock screen or the control center
- Play and navigate books with Chapters
- Jump to start of the current book
- Change playback speed
- Smart rewind: Automatically go back when the player was paused for a bit longer
- Volume Boost: Doubles the volume
- Support for remote events from headset buttons and the lock screen
- Sleep timer with adjustable duration

### Upcoming features

See [our Roadmap on GitHub](https://github.com/GianniCarlo/Audiobook-Player/projects/1) for details



## Contributing

Pull requests and ideas are always welcomed. Please [open an issue](https://github.com/GianniCarlo/Audiobook-Player/issues/new) if you have any suggestions or found a bug. 👍 See our [Contribution Guidelines](./CONTRIBUTING.md) for details.

### Maintainers

- [@GianniCarlo](https://github.com/GianniCarlo) - Original Idea & Creation
- [@pichfl](https://github.com/pichfl) - UI Design & Artwork

### Contributors

- [@bryanrezende](https://github.com/bryanrezende) - Smart rewind
- [@e7mac](https://github.com/e7mac) - Speed control, Autoplay
- [@gpambrozio](https://github.com/gpambrozio) - Volume Boost
- [@vab9](https://github.com/vab9) - AirDrop Support

A full list of all contributors can be found [on GitHub.](https://github.com/GianniCarlo/Audiobook-Player/graphs/contributors)



## Dependencies

Managed with [Carthage](https://github.com/Carthage/Carthage)

- [ColorCube](https://github.com/pixelogik/ColorCube) for extracting artwork colors
- [DeviceKit](https://github.com/dennisweissmann/DeviceKit) for device information used in support requests
- [MarqueeLabel](https://github.com/cbpowell/MarqueeLabel) for scrolling labels
- [MBProgressHUD](https://github.com/jdg/MBProgressHUD) for loading wheels
- [Sweetercolor](https://github.com/jathu/sweetercolor) for handling artwork colors

Managed with [Homebrew](https://brew.sh)

- [SwiftLint](https://github.com/realm/SwiftLint)



## License

Licensed under [GNU GPL v. 3.0](https://opensource.org/licenses/GPL-3.0). See `LICENSE` for details.
