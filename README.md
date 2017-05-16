![Platforms](https://img.shields.io/badge/platforms-macOS%20%7C%20Linux-lightgrey.svg)

# linuxmain-generator

Automatically add code to Swift Package Manager projects to run unit tests on Linux.

```text
Usage: linuxmain-generator
  -o,--overwrite:
      Replace <test directory>/LinuxMain.swift if it already exists.
  -c,--checkOnly:
      Do not modify any file. Exits with 0 if test cases are in sync, otherwise exits with 1.
  --testdir <test directory>:
      The path to the directory with the unit tests. Default = 'Tests'.
  <directory>:
      The project root directory. Default = './'.
```

_This project exists mainly to demonstrate the usage of the [FileSmith](https://github.com/kareman/FileSmith) and [Moderator](https://github.com/kareman/Moderator) projects. Check out [valeriomazzeo/linuxmain-generator](https://github.com/valeriomazzeo/linuxmain-generator) for more features._

## Installation

### Homebrew

```bash
brew tap valeriomazzeo/linuxmain-generator
brew install linuxmain-generator
```

### Manual

```bash
git clone https://github.com/valeriomazzeo/homebrew-linuxmain-generator
cd homebrew-linuxmain-generator
swift build -c release
cp .build/release/linuxmain-generator /usr/local/bin/linuxmain-generator
```

## License

Released under the MIT License (MIT), http://opensource.org/licenses/MIT

Originally forked from https://github.com/kareman/linuxmain-generator
