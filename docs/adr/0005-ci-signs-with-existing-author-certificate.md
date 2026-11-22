# CI signs releases with the existing author certificate

A Tizen TV installs an upgrade only when it carries the same author certificate as the installed app. CI therefore signs every release with the `samsucks` author certificate that `setup.sh` made, restored from GitHub secrets on the PeloNZ fork. CI never makes a new certificate. A new certificate would force every user to uninstall the app, and lose its settings, before the next upgrade. Losing the `.p12` or its password has the same effect, so keep a copy outside the `samsucks-home` volume.
