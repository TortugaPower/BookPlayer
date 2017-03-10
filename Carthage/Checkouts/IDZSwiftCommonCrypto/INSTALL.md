# Installing IDZSwiftCommonCrypto

There are three ways to add IDZCommonCrypto to your project:
* Use CocoaPods
* Use Carthage
* Manually

## CocoaPods

If you are using CocoaPods, add the following to your Podfile:
```bash
pod 'IDZSwiftCommonCrypto', '~> 0.9.1'
```

Then, run the following command to install the IDZSwiftCommonCrypto pod:
```bash
pod install
```
## Carthage

If you are using Carthage, add the following to your Cartfile:

```bash
github "iosdevzone/IDZSwiftCommonCrypto"
```

Run `carthage` to build the framework and drag the built 'IDZCommonCrypto.framework' into your project or workspace.

## Manually

Since `CommonCrypto` is not a standalone module, you need to generate a fake module map to convince Xcode into allowing you to `import CommonCrypto`. The `GenerateCommonCryptoModule` script provides two methods for doing this. Which method you choose depends on whether you want to able to use `CommonCrypto` and, by extension, `IDZSwiftCommonCrypto` in playgrounds.

To make `CommonCrypto` available to frameworks and playground use the command:
```bash
    ./GenerateCommonCryptoModule iphonesimulator8.0
```

This command creates a `CommonCrypto.framework` in the SDK system library directory. You should now be able to use either `CommonCrypto` or `IDZSwiftCommonCrypto` in a playground simply importing them or in your own app project by dragging the `IDZSwiftCommonCrypto.xcodeproj` into your project.

If you do not want to add any files to your SDK you can use the command
```bash
    ./GenerateCommonCryptoModule iphonesimulator8.0 .
```
This method creates a `CommonCrypto` directory within the `IDZSwiftCommonCrypto` source tree, so the SDK directories are not altered, but the module is not available in playgrounds. To use the framework in your own project drag the `IDZSwiftCommonCrypto.xcodeproj` into your project and set the **Module Import Path** to the directory containing the `CommonCrypto` directory created by the script. For more about this, see my blog post [Using CommonCrypto in Swift](http://bit.ly/1xMAGQl)

```swift
import IDZSwiftCommonCrypto
```
