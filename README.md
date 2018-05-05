<img src="./.github/readme-header.png" alt="BookPlayer" width="888" height="300">
<p align="center">Audiobook player made in Swift for your DRM-free audiobooks.</p>
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

- Upload your DRM-free audiobooks to your device via file sharing in iTunes
- Load books from other apps on your device (e.g. Dropbox)
- Import books via AirDrop
- Control audio playback from the lock screen or the control center
- Maintain progress of your audiobooks
- Delete uploaded books from the app
- Jump to start of the current book
- Mark book as finished
- Change playback speed
- Smart rewind
- Boost volume
- Support for remote events from headset buttons
- Automatically plays next item in list

### Upcoming features

- Support for Playlists
- iCloud integration to store users' playlist and books' url cloud reference
- Implementation of AWS S3 integration to store books in the cloud
- Stream books

## Contributing

Pull requests regarding upcoming features (or bugs) are welcomed. Any suggestion or bug please open up an issue 👍

### Contributors

- [@GianniCarlo](https://github.com/GianniCarlo) - Creator
- [@bryanrezende](https://github.com/bryanrezende) - Smart rewind
- [@e7mac](https://github.com/e7mac) - Speed control, Autoplay
- [@gpambrozio](https://github.com/gpambrozio) - Volume Boost
- [@pichfl](https://github.com/pichfl) - UI Design, App Icon, Refactoring
- [@vab9](https://github.com/vab9) - AirDrop Support

A full list of all contributors can be found [on GitHub.](https://github.com/GianniCarlo/Audiobook-Player/graphs/contributors)

## Dependencies

Managed with [Carthage](https://github.com/Carthage/Carthage)

- [MBProgressHUD](https://github.com/jdg/MBProgressHUD) for loading wheels
- [MarqueeLabel](https://github.com/cbpowell/MarqueeLabel) for scrolling labels
- [ColorCube](https://github.com/pixelogik/ColorCube) for extracting artwork colors
- [Sweetercolor](https://github.com/jathu/sweetercolor) for handling artwork colors

Managed with [Homebrew](https://brew.sh)

- [SwiftLint](https://github.com/realm/SwiftLint)

## Credits

### Code

- Drag gesture code adapted from [HarshilShah/DeckTransition](https://github.com/HarshilShah/DeckTransition)

### Images

- Skip time image made by [Vaadin](http://www.flaticon.com/authors/vaadin) from [www.flaticon.com](http://www.flaticon.com)
- Small Play image made by [Madebyoliver](http://www.flaticon.com/authors/madebyoliver) from [www.flaticon.com](http://www.flaticon.com)
- Small Pause image made by [Hanan](http://www.flaticon.com/authors/hanan) from [www.flaticon.com](http://www.flaticon.com)
- Small Double right arrows image made by [Freepik](http://www.flaticon.com/authors/freepik) from [www.flaticon.com](http://www.flaticon.com)

## License

Licensed under [GNU GPL v. 3.0](https://opensource.org/licenses/GPL-3.0). See `LICENSE` for details.
