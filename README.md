# Audiobook-Player

Player made in Swift for your DRM-free audiobooks. 

[![Download on the App Store](Assets/app-store-badge.svg)](https://itunes.apple.com/us/app/bookplayer-audio-book-player/id1138219998?ls=1&mt=8)

<img src="https://raw.githubusercontent.com/GianniCarlo/Audiobook-Player/master/Assets/list_screenshot.png" width="350" />
<img src="https://raw.githubusercontent.com/GianniCarlo/Audiobook-Player/master/Assets/player_screenshot.png" width="350" />

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
- [@pichfl](https://github.com/pichfl) - UI Design, Artwork, Refactoring
- [@vab9](https://github.com/vab9) - AirDrop Support

A full list of all contributors can be found [on GitHub.](https://github.com/GianniCarlo/Audiobook-Player/graphs/contributors)

## Dependencies

Managed with [Carthage](https://github.com/Carthage/Carthage)

- [Chameleon](https://github.com/ViccAlexander/Chameleon) for colors
- [MBProgressHUD](https://github.com/jdg/MBProgressHUD) for loading wheels
- [MarqueeLabel](https://github.com/cbpowell/MarqueeLabel) for scrolling labels

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
- Book image (part of app icon) made by [Freepik](http://www.flaticon.com/authors/freepik) from [www.flaticon.com](http://www.flaticon.com)
- Speaker image (part of app icon) made by [Madebyoliver](http://www.flaticon.com/authors/madebyoliver) from [www.flaticon.com](http://www.flaticon.com)
- App icon and screenshot template generator from https://appicontemplate.com/

## License

Licensed under [GNU GPL v. 3.0](https://opensource.org/licenses/GPL-3.0). See `LICENSE` for details.
