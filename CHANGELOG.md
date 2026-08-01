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
