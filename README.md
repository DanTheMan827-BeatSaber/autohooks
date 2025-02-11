# Auto Hooks

Auto Hooks is a header-only library designed to simplify the process of creating hooks by providing a quick and easy way to install all of them in your `load()` and `late_load()` methods.

```c++
extern "C" __attribute__((visibility("default"))) void load() {
    // Initialize il2cpp functions
    il2cpp_functions::Init();

    // install early hooks
    Logger.info("Installing {} early hook{}", EARLY_HOOK_COUNT, EARLY_HOOK_COUNT == 0 || EARLY_HOOK_COUNT > 1 ? "s" : "");
    INSTALL_EARLY_HOOKS();
    Logger.info("Finished installing early hook{}", EARLY_HOOK_COUNT == 0 || EARLY_HOOK_COUNT > 1 ? "s" : "");
}

extern "C" __attribute__((visibility("default"))) void late_load() {
    // Install late hooks
    Logger.info("Installing {} late hook{}", LATE_HOOK_COUNT, LATE_HOOK_COUNT > 1 ? "s" : "");
    INSTALL_LATE_HOOKS();
    Logger.info("Finished installing late hook{}", LATE_HOOK_COUNT == 0 || LATE_HOOK_COUNT > 1 ? "s" : "");
}
```

## Macros

- `MAKE_EARLY_*`

  - Creates a hook and registers it for installation with `INSTALL_EARLY_HOOKS()`

- `MAKE_LATE_*`

  - Creates a hook and registers it for installation with `INSTALL_LATE_HOOKS()`

- `MAKE_DLOPEN_*` — **NOT RECOMMENDED**
  - Creates a hook and immediately installs it when the library is loaded. This will install before any setup has been done, you have been warned.

### Hook Installation

- `INSTALL_EARLY_HOOKS()`

  - Installs all registered early hooks.

- `INSTALL_LATE_HOOKS()`

  - Installs all registered late hooks.

- `EARLY_HOOK_COUNT`

  - Returns the number of early hook installation functions that have been registered. This will be `0` after `INSTALL_EARLY_HOOKS()` has been called.

- `LATE_HOOK_COUNT`
  - Returns the number of late hook installation functions that have been registered. This will be `0` after `INSTALL_LATE_HOOKS()` has been called.

## QPM Scripts

- `qpm s build` to build.
- `qpm s clean` to build with a clean build path.
- `qpm s qmod` to package qmod.
- `qpm s copy` to copy the mod to the headset and (re)start the game with logging.
- `qpm s deepclean` to clean all artifacts and downloaded dependencies from the project directory.

## Credits

- [zoller27osu](https://github.com/zoller27osu), [Sc2ad](https://github.com/Sc2ad) and [jakibaki](https://github.com/jakibaki) - [beatsaber-hook](https://github.com/sc2ad/beatsaber-hook)
- [raftario](https://github.com/raftario)
- [Lauriethefish](https://github.com/Lauriethefish), [danrouse](https://github.com/danrouse) and [Bobby Shmurner](https://github.com/BobbyShmurner) for [this template](https://github.com/Lauriethefish/quest-mod-template)
