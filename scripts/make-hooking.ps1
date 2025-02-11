# This script reads the hooking.hpp file, finds all MAKE_HOOK definitions,
# and generates corresponding MAKE_EARLY_HOOK, MAKE_LATE_HOOK, and MAKE_DLOPEN_HOOK
# definitions.
#
# The output is saved to shared/hooks.hpp

param (
    # The input file to read the MAKE_HOOK definitions from
    [string]$inputFile = "./extern/includes/beatsaber-hook/shared/utils/hooking.hpp",

    # The output file to write the convenience macros to
    [string]$outputFile = "./shared/hooks.hpp"
)

Push-Location "$PSScriptRoot/.." # Change to the project root directory

# Create the output directory if it doesn't exist
if (-Not (Test-Path -Path "./shared" -PathType Container)) {
    New-Item -Path "./shared" -ItemType Directory
}

# Resolve the full paths for the input and output files
$inputFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($inputFile)
$outputFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($outputFile)

# Check if the extern directory exists
$externDir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath("./extern")
if (-Not (Test-Path -Path $externDir -PathType Container)) {
    # Run qpm restore if the extern directory does not exist
    Write-Output "Directory '$externDir' does not exist. Running 'qpm restore'..."
    qpm restore
}

# Check if the input file exists
if (-Not (Test-Path -Path $inputFile -PathType Leaf)) {
    Write-Error "Input file '$inputFile' does not exist or is not a file."
    exit 1
}

# Define the regex pattern to match MAKE_HOOK definitions
$pattern = (
    '(?ms)' + # Multiline and single-line mode
    '(?:^[ \t]*//[^\r\n]*\r?\n)+?' + # Match one or more lines of comments
    '^\s*#define\s+' + # Match the '#define' keyword with optional leading whitespace
    '(MAKE_HOOK(?:_\w+)?)' + # Capture the macro name (e.g., MAKE_HOOK, MAKE_HOOK_SOMETHING)
    '\(([^)]*)\)' + # Capture the macro parameters inside parentheses
    '((?:[^\n]*\\\r?\n)+(?:[^\n]+)?)' # Capture the macro body spanning multiple lines
)

# Read the file content
$fileContent = Get-Content -Path $inputFile -Raw

# Match the pattern and extract to an array
$matches = [regex]::Matches($fileContent, $pattern)

# Create an array to store the results
$resultArray = @()

# Iterate over the matches and add them to the result array
foreach ($match in $matches) {
    $resultArray += $match.Value
}

# Function to replace regex in a copy of the result values
function ReplaceMakeWithAuto {
    param (
        [array]$inputArray,
        [string]$modifier,
        [string]$macroPrefix = "INSTALL_HOOK_DEFERRED",
        [string]$macroSuffix = "",
        [string]$macroKeyword = "AUTO"
    )

    $outputArray = @()
    foreach ($item in $inputArray) {
        # This regex pattern matches lines that define a MAKE_HOOK macro and captures the parts to be replaced.
        # ^(\s*#define\s+MAKE_): Matches the start of the line, optional whitespace, '#define MAKE_' and captures it.
        # (HOOK): Matches 'HOOK' and captures it.
        # ([^(]+)?: Matches any characters except '(', capturing them if present.
        $lines = ([regex]::Replace($item, "(?ms)^(\s*#define\s+MAKE_)(HOOK)([^(]+)?", "`$1${macroKeyword}${modifier}_`$2`$3")) -split "`n"

        # Insert the macro installation line before the last line
        $lines[-1] = "$macroPrefix$modifier$macroSuffix(name_); \`n" + $lines[-1]

        # Trim trailing spaces from all lines
        $lines = $lines | ForEach-Object { $_.TrimEnd() }

        # Join the lines back into a single string
        $newItem = $lines -join "`n"

        # Add the modified item to the output array
        $outputArray += $newItem.Trim()
    }
    return $outputArray
}

# Call the function and print the modified array
$modifiedArray += @("/// Early Hooks`nnamespace {")
$modifiedArray += ReplaceMakeWithAuto -inputArray $resultArray -macroPrefix "MAKE_EARLY" -macroSuffix "_HOOK_INSTALL_WITH_AUTOLOGGER" -macroKeyword "EARLY"
$modifiedArray += ReplaceMakeWithAuto -inputArray $resultArray -modifier "_ORIG" -macroPrefix "MAKE_EARLY" -macroSuffix "_HOOK_INSTALL_WITH_AUTOLOGGER" -macroKeyword "EARLY"
$modifiedArray += @("}")

$modifiedArray += @("/// Late Hooks`nnamespace {")
$modifiedArray += ReplaceMakeWithAuto -inputArray $resultArray -macroPrefix "MAKE_LATE" -macroSuffix "_HOOK_INSTALL_WITH_AUTOLOGGER" -macroKeyword "LATE"
$modifiedArray += ReplaceMakeWithAuto -inputArray $resultArray -modifier "_ORIG" -macroPrefix "MAKE_LATE" -macroSuffix "_HOOK_INSTALL_WITH_AUTOLOGGER" -macroKeyword "LATE"
$modifiedArray += "}"

$modifiedArray += @("/// Dlopen Hooks`nnamespace {")
$modifiedArray += ReplaceMakeWithAuto -inputArray $resultArray -macroPrefix "INSTALL" -macroSuffix "_HOOK_ON_DLOPEN_WITH_AUTOLOGGER" -macroKeyword "DLOPEN"
$modifiedArray += ReplaceMakeWithAuto -inputArray $resultArray -modifier "_ORIG" -macroPrefix "INSTALL" -macroSuffix "_HOOK_ON_DLOPEN_WITH_AUTOLOGGER" -macroKeyword "DLOPEN"
$modifiedArray += @("}")

# Write the output to the specified file
$outputContent = @"
/// @file $(Split-Path -Path $($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($outputFile)) -Leaf)
/// @brief Contains convenience macros to create hooks and register for user-initiated
/// installation at a later time with the INSTALL_EARLY_HOOKS and INSTALL_LATE_HOOKS macros
/// or automatically installed on dlopen.
///
/// IMPORTANT: This file is automatically generated.
/// Do not edit this file directly. Any changes made to this file will be overwritten.
/// Please modify the make-hooking script that generates this file instead.

#pragma once
#include "beatsaber-hook/shared/utils/hooking.hpp"

/// @brief This namespace is internal to the AutoHooks library and should not be used directly.
/// Anything in this namespace is not part of the public API.  Use the macros provided.
namespace __AutoHooksInternal__ {
    /**
     * @brief The DeferredHooks class manages the registration and installation of
     * hook functions.
     *
     * This class provides a mechanism to register hook installation functions that
     * can be called later to install hooks. It maintains a list of installation
     * functions and provides methods to add to this list and to call all registered
     * functions at a later time.
     */
    class DeferredHooks {
       public:
        /// @brief The HookType enum class represents the type of hook.
        enum class HookType { Early, Late };

       private:
        /// @brief Returns the list of hook installation functions for the specified type.
        /// @param type The type of hooks to get the installation functions for.
        /// @return A reference to the list of installation functions.
        inline static std::vector<void (*)()>& getInstallFuncs(HookType type) {
            switch (type) {
                case ::__AutoHooksInternal__::DeferredHooks::HookType::Early:
                    static std::vector<void (*)()> earlyInstallFuncs;
                    return earlyInstallFuncs;

                case ::__AutoHooksInternal__::DeferredHooks::HookType::Late:
                    static std::vector<void (*)()> lateInstallFuncs;
                    return lateInstallFuncs;
            }
        }

       public:
        /// @brief A logger context for the DeferredHooks class.
        inline static constexpr auto logger = Paper::ConstLoggerContext(MOD_ID);

        /// @brief Adds a hook installation function to the specified list.
        /// @param type The type of hook to add the installation function to.
        /// @param installFunc The installation function to add.
        inline static void addInstallFunc(HookType type, void (*installFunc)()) {
            getInstallFuncs(type).push_back(installFunc);
        }

        /// @brief Calls all installation functions added via addInstallFunc and
        /// then clears the list.
        /// @param type The type of hooks to install.
        inline static void installHooks(HookType type) {
            auto installFuncs = getInstallFuncs(type);

            for (auto& func : installFuncs) {
                func();
            }

            // Why would we need to keep these around?
            installFuncs.clear();
        }

        /// @brief Returns the number of hook installation functions that have
        /// been registered for the specified type.
        inline static int getHookCount(HookType type) {
            return getInstallFuncs(type).size();
        }
    };
}  // namespace __AutoHooksInternal__

/// AutoHooks Macros
namespace {

/// @brief Macro to automatically register a deferred early hook installation
/// function.
/// @param name_ The name of the hook to be installed.
#define MAKE_EARLY_HOOK_INSTALL_WITH_AUTOLOGGER(name_)                                                                         \
    __attribute((constructor)) void Hook_##name_##_Auto_Register() {                                                           \
        ::__AutoHooksInternal__::DeferredHooks::addInstallFunc(::__AutoHooksInternal__::DeferredHooks::HookType::Early, []() { \
            INSTALL_HOOK(::__AutoHooksInternal__::DeferredHooks::logger, name_);                                               \
        });                                                                                                                    \
    }

/// @brief Macro to automatically register a deferred early hook installation
/// function for original hooks.
/// @param name_ The name of the hook to be installed.
#define MAKE_EARLY_ORIG_HOOK_INSTALL_WITH_AUTOLOGGER(name_)                                                                    \
    __attribute((constructor)) void Hook_##name_##_Auto_Orig_Register() {                                                      \
        ::__AutoHooksInternal__::DeferredHooks::addInstallFunc(::__AutoHooksInternal__::DeferredHooks::HookType::Early, []() { \
            INSTALL_HOOK_ORIG(::__AutoHooksInternal__::DeferredHooks::logger, name_);                                          \
        });                                                                                                                    \
    }

/// @brief Macro to automatically register a deferred early direct hook
/// installation function.
/// @param name_ The name of the hook to be installed.
/// @param addr_ The address that should be hooked.
#define MAKE_EARLY_DIRECT_HOOK_INSTALL_WITH_AUTOLOGGER(name_, addr_)                                                           \
    __attribute((constructor)) void Hook_##name_##_Auto_Register() {                                                           \
        ::__AutoHooksInternal__::DeferredHooks::addInstallFunc(::__AutoHooksInternal__::DeferredHooks::HookType::Early, []() { \
            INSTALL_HOOK_DIRECT(::__AutoHooksInternal__::DeferredHooks::logger, name_, addr_);                                 \
        });                                                                                                                    \
    }

/// @brief Macro to automatically register a deferred early hook installation
/// function with specified logger.
/// @param logger_ The logger to be used during install.
/// @param name_ The name of the hook to be installed.
#define MAKE_EARLY_HOOK_INSTALL(logger_, name_)                                                                                \
    __attribute((constructor)) void Hook_##name_##_Auto_Register() {                                                           \
        ::__AutoHooksInternal__::DeferredHooks::addInstallFunc(::__AutoHooksInternal__::DeferredHooks::HookType::Early, []() { \
            INSTALL_HOOK(logger_, name_);                                                                                      \
        });                                                                                                                    \
    }

/// @brief Macro to automatically register a deferred early hook installation
/// function for original hooks with specified logger.
/// @param logger_ The logger to be used during install.
/// @param name_ The name of the hook to be installed.
#define MAKE_EARLY_ORIG_HOOK_INSTALL(logger_, name_)                                                                           \
    __attribute((constructor)) void Hook_##name_##_Auto_Orig_Register() {                                                      \
        ::__AutoHooksInternal__::DeferredHooks::addInstallFunc(::__AutoHooksInternal__::DeferredHooks::HookType::Early, []() { \
            INSTALL_HOOK_ORIG(logger_, name_);                                                                                 \
        });                                                                                                                    \
    }

/// @brief Macro to automatically register a deferred early direct hook
/// installation function with specified logger.
/// @param logger_ The logger to be used during install.
/// @param name_ The name of the hook to be installed.
/// @param addr_ The address that should be hooked.
#define MAKE_EARLY_DIRECT_HOOK_INSTALL(logger_, name_, addr_)                                                                  \
    __attribute((constructor)) void Hook_##name_##_Auto_Register() {                                                           \
        ::__AutoHooksInternal__::DeferredHooks::addInstallFunc(::__AutoHooksInternal__::DeferredHooks::HookType::Early, []() { \
            INSTALL_HOOK_DIRECT(logger_, name_, addr_);                                                                        \
        });                                                                                                                    \
    }

/// @brief Macro to automatically register a deferred late hook installation
/// function.
/// @param name_ The name of the hook to be installed.
#define MAKE_LATE_HOOK_INSTALL_WITH_AUTOLOGGER(name_)                                                                         \
    __attribute((constructor)) void Hook_##name_##_Auto_Register() {                                                          \
        ::__AutoHooksInternal__::DeferredHooks::addInstallFunc(::__AutoHooksInternal__::DeferredHooks::HookType::Late, []() { \
            INSTALL_HOOK(::__AutoHooksInternal__::DeferredHooks::logger, name_);                                              \
        });                                                                                                                   \
    }

/// @brief Macro to automatically register a deferred late hook installation
/// function for original hooks.
/// @param name_ The name of the hook to be installed.
#define MAKE_LATE_ORIG_HOOK_INSTALL_WITH_AUTOLOGGER(name_)                                                                    \
    __attribute((constructor)) void Hook_##name_##_Auto_Orig_Register() {                                                     \
        ::__AutoHooksInternal__::DeferredHooks::addInstallFunc(::__AutoHooksInternal__::DeferredHooks::HookType::Late, []() { \
            INSTALL_HOOK_ORIG(::__AutoHooksInternal__::DeferredHooks::logger, name_);                                         \
        });                                                                                                                   \
    }

/// @brief Macro to automatically register a deferred late direct hook
/// installation function.
/// @param name_ The name of the hook to be installed.
/// @param addr_ The address that should be hooked.
#define MAKE_LATE_DIRECT_HOOK_INSTALL_WITH_AUTOLOGGER(name_, addr_)                                                           \
    __attribute((constructor)) void Hook_##name_##_Auto_Register() {                                                          \
        ::__AutoHooksInternal__::DeferredHooks::addInstallFunc(::__AutoHooksInternal__::DeferredHooks::HookType::Late, []() { \
            INSTALL_HOOK_DIRECT(::__AutoHooksInternal__::DeferredHooks::logger, name_, addr_);                                \
        });                                                                                                                   \
    }

/// @brief Macro to automatically register a deferred late hook installation
/// function with specified logger.
/// @param logger_ The logger to be used during install.
/// @param name_ The name of the hook to be installed.
#define MAKE_LATE_HOOK_INSTALL(logger_, name_)                                                                                \
    __attribute((constructor)) void Hook_##name_##_Auto_Register() {                                                          \
        ::__AutoHooksInternal__::DeferredHooks::addInstallFunc(::__AutoHooksInternal__::DeferredHooks::HookType::Late, []() { \
            INSTALL_HOOK(logger_, name_);                                                                                     \
        });                                                                                                                   \
    }

/// @brief Macro to automatically register a deferred late hook installation
/// function for original hooks with specified logger.
/// @param logger_ The logger to be used during install.
/// @param name_ The name of the hook to be installed.
#define MAKE_LATE_ORIG_HOOK_INSTALL(logger_, name_)                                                                           \
    __attribute((constructor)) void Hook_##name_##_Auto_Orig_Register() {                                                     \
        ::__AutoHooksInternal__::DeferredHooks::addInstallFunc(::__AutoHooksInternal__::DeferredHooks::HookType::Late, []() { \
            INSTALL_HOOK_ORIG(logger_, name_);                                                                                \
        });                                                                                                                   \
    }

/// @brief Macro to automatically register a deferred late direct hook
/// installation function with specified logger.
/// @param logger_ The logger to be used during install.
/// @param name_ The name of the hook to be installed.
/// @param addr_ The address that should be hooked.
#define MAKE_LATE_DIRECT_HOOK_INSTALL(logger_, name_, addr_)                                                                  \
    __attribute((constructor)) void Hook_##name_##_Auto_Register() {                                                          \
        ::__AutoHooksInternal__::DeferredHooks::addInstallFunc(::__AutoHooksInternal__::DeferredHooks::HookType::Late, []() { \
            INSTALL_HOOK_DIRECT(logger_, name_, addr_);                                                                       \
        });                                                                                                                   \
    }

/// @brief Macro to automatically install a hook on dlopen with a logger.
#define INSTALL_HOOK_ON_DLOPEN_WITH_AUTOLOGGER(name_)                        \
    __attribute((constructor)) void Hook_##name_##_Dlopen_Install() {        \
        INSTALL_HOOK(::__AutoHooksInternal__::DeferredHooks::logger, name_); \
    }

/// @brief Macro to automatically install a direct hook on dlopen with a logger.
#define INSTALL_DIRECT_HOOK_ON_DLOPEN_WITH_AUTOLOGGER(name_, addr_)                        \
    __attribute((constructor)) void Hook_##name_##_Dlopen_Direct_Install() {               \
        INSTALL_HOOK_DIRECT(::__AutoHooksInternal__::DeferredHooks::logger, name_, addr_); \
    }

/// @brief Macro to automatically install an original hook on dlopen with a
/// logger.
#define INSTALL_ORIG_HOOK_ON_DLOPEN_WITH_AUTOLOGGER(name_)                        \
    __attribute((constructor)) void Hook_##name_##_Dlopen_Orig_Install() {        \
        INSTALL_HOOK_ORIG(::__AutoHooksInternal__::DeferredHooks::logger, name_); \
    }

/// @brief Macro to install a hook on dlopen with specified logger.
#define INSTALL_HOOK_ON_DLOPEN(logger, name_)                         \
    __attribute((constructor)) void Hook_##name_##_Dlopen_Install() { \
        INSTALL_HOOK(logger, name_);                                  \
    }

/// @brief Macro to install a direct hook on dlopen with specified logger.
#define INSTALL_DIRECT_HOOK_ON_DLOPEN(logger, name_, addr_)                  \
    __attribute((constructor)) void Hook_##name_##_Dlopen_Direct_Install() { \
        INSTALL_HOOK_DIRECT(logger, name_, addr_);                           \
    }

/// @brief Macro to install an original hook on dlopen with specified logger.
#define INSTALL_ORIG_HOOK_ON_DLOPEN(logger, name_)                         \
    __attribute((constructor)) void Hook_##name_##_Dlopen_Orig_Install() { \
        INSTALL_HOOK_ORIG(logger, name_);                                  \
    }

/// @brief Macro to install all registered early hooks.
#define INSTALL_EARLY_HOOKS() ::__AutoHooksInternal__::DeferredHooks::installHooks(::__AutoHooksInternal__::DeferredHooks::HookType::Early)

/// @brief Macro to install all registered late hooks.
#define INSTALL_LATE_HOOKS() ::__AutoHooksInternal__::DeferredHooks::installHooks(::__AutoHooksInternal__::DeferredHooks::HookType::Late)

/// @brief Returns the number of early hook installation functions that have
/// been registered.
#define EARLY_HOOK_COUNT ::__AutoHooksInternal__::DeferredHooks::getHookCount(::__AutoHooksInternal__::DeferredHooks::HookType::Early)

/// @brief Returns the number of late hook installation functions that have been
/// registered.
#define LATE_HOOK_COUNT ::__AutoHooksInternal__::DeferredHooks::getHookCount(::__AutoHooksInternal__::DeferredHooks::HookType::Late)

}  // namespace

$($modifiedArray -join "`n`n")
"@ -replace "`r", ""

if ($IsWindows) {
    $outputContent = ($outputContent -replace "`n", "`r`n")
}

# Check if the output file exists and read its content if it does
if (Test-Path -Path $outputFile -PathType Leaf) {
    $existingContent = Get-Content -Path $outputFile -Raw
}
else {
    $existingContent = ""
}

# Write the new content to the output file only if it differs from the existing content
if ($existingContent.Trim() -ne $outputContent.Trim()) {
    Set-Content -Path $outputFile -Value $outputContent -Force
    Write-Output "Output file '$outputFile' has been updated."
}
else {
    Write-Output "Output file '$outputFile' is already up-to-date."
}

Pop-Location
