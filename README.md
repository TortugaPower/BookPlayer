[![BookPlayer - A wonderful player for your M4B/M4A/MP3 based audiobooks.](./.github/readme-header@2x.png)](https://itunes.apple.com/us/app/bookplayer-audio-book-player/id1138219998?ls=1&mt=8)

<p align="center">
    <a href="https://itunes.apple.com/us/app/bookplayer-audio-book-player/id1138219998?ls=1&amp;mt=8">
        <img src="./.github/app-store-badge.svg" alt="Download on the App Store">
    </a>
</p>

[![Four screenshots of BookPlayer on the iPhone X. Showing Player, Import options, the Library and, a playlist](./.github/readme-screenshots@2x.png)](https://itunes.apple.com/us/app/bookplayer-audio-book-player/id1138219998?ls=1&mt=8)

Please visit our [Wiki](https://github.com/TortugaPower/BookPlayer/wiki) for our
[FAQ](https://github.com/TortugaPower/BookPlayer/wiki/FAQ) and
[guides](https://github.com/TortugaPower/BookPlayer/wiki/Developer-Guide) on how to add new themes and icons to the app.

## Features

### Import

- Using [AirDrop](https://support.apple.com/en-us/HT204144#receive) from your Mac or iOS device
- From [Files](https://support.apple.com/en-us/ht206481) and other apps on your device
- Via [File Sharing](https://support.apple.com/en-us/HT201301) in iTunes on your Mac or PC
- Zip archives are supported and can be turned into playlists automatically

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
- Smart rewind
- Volume Boost
- Support for remote events from headset buttons and the lock screen
- Sleep timer with adjustable duration
- Support for VoiceOver
- Dark mode for night owls

### BookPlayer Plus

- Support Open Source development
- Additional color themes
- Select from alternative App Icons

### Upcoming features

See [our Roadmap on GitHub](https://github.com/GianniCarlo/Audiobook-Player/projects/1) for details.

### Supported locales & Languages

- English
- Czech (Petr Kabrna)
- German ([@pichfl](https://github.com/pichfl), Fabian Schalle
- Russian ([@Nibelungc](https://github.com/Nibelungc), Andrey Kozlov, [@carcade](https://github.com/carcade) & Eugene
  Newfield)
- Spanish ([@GianniCarlo](https://github.com/GianniCarlo))
- Swedish ([@hypeitinc](https://github.com/hypeitinc))
- Chinese Simplified ([@wangqj](https://twitter.com/wangqj))
- Danish (Carl Houmøller)
- Dutch (Miguel De Pelsmaeker)
- French (Christophe Vergne)
- Romanian (Alexandru Hamuraru)
- Turkish (Selçuk Onuk)
- Italian (Alessio Franceschi)
- Ukranian (Oleh)
- Slovak (Peter Skladaný)
- Portuguese (Vitor Jacinto)
- Polish (Konrad Kwapisz)
- Hungarian (Gábor Sári)
- Arabic (John Hamo & Monther Qandeel)
- Finnish ([@akirataguchi115](https://github.com/akirataguchi115))

Help us to [translate BookPlayer](#localisation).

## Contributing

Pull requests and ideas are always welcomed. Please
[open an issue](https://github.com/TortugaPower/BookPlayer/issues/new?assignees=&labels=bug&template=bug.md) if you have any suggestions or found a bug.
👍 See our [Contribution Guidelines](./CONTRIBUTING.md) for details, and our [Setup Guide](https://github.com/TortugaPower/BookPlayer/wiki/Developer-Guide#setting-up-the-project) for setting up your local environment.

If you enjoy BookPlayer, we would be glad if you consider writing a review on the
[App Store.](https://itunes.apple.com/us/app/bookplayer-audio-book-player/id1138219998?ls=1&mt=8)

### Maintainers

- [@GianniCarlo](https://github.com/GianniCarlo) - Original Idea & Creation
- [@pichfl](https://github.com/pichfl) - UI Design & Artwork

### Contributors

- [@bryanrezende](https://github.com/bryanrezende) - Smart rewind
- [@e7mac](https://github.com/e7mac) - Speed control, Autoplay
- [@gpambrozio](https://github.com/gpambrozio) - Volume Boost
- [@vab9](https://github.com/vab9) - AirDrop Support
- [@atomicguy](https://github.com/atomicguy) - Zip Support
- [@ryantstone](https://github.com/ryantstone) - VoiceOver Support

A full list of all contributors can be found
[on GitHub.](https://github.com/GianniCarlo/Audiobook-Player/graphs/contributors)

### Community

[Join us on our new Discord server](https://discord.gg/MjCUXgU) if you want to contribute or talk to other people using
BookPlayer. Keep in mind that [you should file issues](#contributing) when you find bugs or have ideas for new features.
Discord is a chat platform and while the maintainers will drop by once in a while, it is still a chat and not a
bugtracker.

### Localisation

[![Localization generously sponsored by Lokalise, the best platform for adding lodalization to your applications](./.github/lokalise@2x.png)](https://lokalise.com/)

If you want to help translating BookPlayer into your own language, send as an email at support@bookplayer.app so we can
invite you to Lokalise.

## Dependencies

Managed with the [Swift Package Manager](https://swift.org/package-manager/)

- [Alamofire](https://github.com/Alamofire/Alamofire) for downloading books via url scheme actions
- [ColorCube](https://github.com/pixelogik/ColorCube) for extracting artwork colors
- [DeviceKit](https://github.com/dennisweissmann/DeviceKit) for device information used in support requests
- [Kingfisher](https://github.com/onevcat/Kingfisher) for contributors' profile pictures
- [MarqueeLabel](https://github.com/cbpowell/MarqueeLabel) for scrolling labels
- [DirectoryWatcher](https://github.com/GianniCarlo/DirectoryWatcher) for events on the document's folder
- [Sentry](https://github.com/getsentry/sentry-cocoa) for crash reporting
- [Sweetercolor](https://github.com/jathu/sweetercolor) for handling artwork colors
- [SwiftyStoreKit](https://github.com/bizz84/SwiftyStoreKit) for the tip jar
- [ZipArchive](https://github.com/ZipArchive/ZipArchive) for zip files

Managed with [Homebrew](https://brew.sh)

- [SwiftLint](https://github.com/realm/SwiftLint)
- [SwiftFormat](https://github.com/nicklockwood/SwiftFormat)

## License

Licensed under [GNU GPL v. 3.0](https://opensource.org/licenses/GPL-3.0). See `LICENSE` for details.
