## v1.2.1 - August 2026

* Limited generated `sAMAccountName` values to 20 characters.
* Retried username and common-name collisions with numeric suffixes while preserving the 20-character limit.
* Prevented collisions from reducing the number of users requested with `Count`.
* Made non-collision creation errors terminating so completed runs do not silently create fewer users than requested.

## v1.2.0 - August 2026

* Replaced `Get-Random` password generation with .NET cryptographic random-number generation.
* Guaranteed that generated passwords contain lowercase, uppercase, numeric, and special characters.
* Randomized password character positions with an unbiased shuffle.
* Removed plaintext passwords from verbose output.

## v1.1.0 - July 2026

* Converted the bundled first-name and last-name datasets from UTF-16 LE to UTF-8.
* Cached the name datasets when the module is imported instead of reading them for every generated user.
* Kept the cached name data private by disabling variable exports.

## v1.0.3 - July 2026

* Removed .git folder from package

## v1.0.2 - July 2026

* Fixed password generation to randomize individual characters. ([Issue #1](https://github.com/andrefaria24/adusergenerator/issues/1))

## v1.0.1 - January 2025

* Corrected required PowerShellVersion
