# QRMultiReader

An Android app (Flutter) that reads QR codes and collects them into a note.

- **Single scan** reads one code and adds it to the note.
- **Start chain** keeps the camera open and adds every new code until you stop.

Each scan is added to the note as:

```
Scan 1
<code>

Scan 2
<code>
```

The note is editable and can be copied or cleared from the app bar.

## Run

```bash
flutter pub get
flutter run
```

Built with [`mobile_scanner`](https://pub.dev/packages/mobile_scanner).

- History of every scan is kept on the device (app bar clock icon).
- Follows the system light/dark theme.

Source: https://github.com/angelgtrr/QRMultiReader

## Author

Created by angelgtrr.

## License

MIT, see [LICENSE](LICENSE).

## Releases

Pushing a tag like `v1.0.0` builds the APK on GitHub Actions and attaches it to a GitHub release:

```bash
git tag v1.0.0
git push origin v1.0.0
```
