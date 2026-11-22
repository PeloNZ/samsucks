# SamSUCKS

A Plex client for Samsung Tizen TVs.

## Builds and releases

**Release build**:
The app as it ships to users. It runs on the TV alone and contains no dev tooling.
_Avoid_: prod build

**Dev build**:
The app with the perf overlay, log forwarding and remote control, for the developer's TV only.
_Avoid_: debug build

**Author certificate**:
The key that signs every package of the app. All versions must carry the same one, or a TV refuses the upgrade.
_Avoid_: signing key, cert

**Signing profile**:
A named pair of the author certificate and Samsung's public distributor certificate, which the Tizen CLI uses to sign a package.
_Avoid_: security profile
