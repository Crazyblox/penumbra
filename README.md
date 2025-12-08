# About:
Penumbra is a versatile and modular Luau graphics rendering pipeline providing developers in CPU-only spaces a GLSL-like workflow, with the obvious difference being that shaders run directly in the Luau language.

Penumbra includes 11 example fragment shaders, along with other directories such as EOTF (sRGB/lRGB), Tonemapping & Synchronization between render threads for convolutional kernel shaders.

# Requirements:
Penumbra requires setting up a valid Pajamas runtime.
For roblox users, there is a 'no tools required' step-by-step readme for getting Pajamas set up.
Link: https://github.com/Crazyblox/Pajamas

# Roblox - Setup:
Roblox studio's file sync feature can read from disk and import directly into studio, so we will need to perform the following steps:
- 1: In roblox studio, go to 'File -> Beta Features -> Script Sync', enable it, close the beta window, then restart studio.
- 2: On your PC, make a copy of Penumbra (This directory) and store it on your PC in a location that makes sense to you.
(A .zip folder is provided if you're unfamiliar with using git clone, although it will be susceptible to being out of date.)
- 3: With an open place in roblox studio, create a folder where you intend to store the Penumbra project. Ensure the directory you are storing Penumbra in supports Actors.
- 4: Right click on the created folder, go to 'Script Sync -> Sync with Directory...'.
- 5: In the OS file selection popup, ensure that you have selected your copy of 'Penumbra'.
- 6: Roblox studio will ask which version to keep. Ensure you click on 'disk version', as we want studio to read the files from disk.
(Note that while script sync is enabled, there will be a symbol with 2 arrows in the explorer widget, symbolising that these directories are synced - Any edits made in and out of studio will directly update the files stored on your own system.)

### Roblox - Disclaimer:
This setup process requires the use of a roblox studio beta feature, and as such reliability cannot be guaranteed for using in any context beyond attempting to import the files into studio itself.

# Setup - Others:
Penumbra is intended to be supported right out of the gate wherever Pajamas can run and that the Pajamas plugin modules that Penumbra requires is available in the given runtime.