# assembler_write
A minimal platform for creating cheats for the games using assembly insn replacement at addr.

Everything must be done **by yourself** in the source code of the tweak. In the code you will see more documentation. Search in `Tweak.xm`. I use this tweak as a template for my own cheats that I write only for myself. Tested on games Terraria and Jelly Car Worlds. (Huge thanks to Re-Logic and Walaber for such awesome games!)

# Tested Devices and iOS Versions
- iPhone SE 2020: iOS 15.2 (19C56) - libhooker tweak injector
- iPhone SE 2016: iOS 15.8.4 (19H390) - libhooker tweak injector

# Usage
See in the code, there are not preferences for this tweak. Everything must be compiled from source.

# Possible problems
I have userspace PAC disabled on my iPhone SE 2020 with Fugu15_Rootful. I have not tested functionality of the project on devices with PAC enabled.

# Building 
Prerequisites:
- Make sure you have theos installed
- Make sure you have specified your sdks in Makefile
Now you can simply run `make package` or `make package THEOS_PACKAGE_SCHEME=rootless` depending on your jailbreak environment.
After that install it via sileo/cydia/zebra/ssh.

# License
Attribution-NonCommercial 4.0 International. See the `LICENSE` file.