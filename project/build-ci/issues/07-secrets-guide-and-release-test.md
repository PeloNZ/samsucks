# 07: Secrets guide and throwaway-release test

Status: ready-for-human
Blocked by: 06
Parent: `project/build-ci/spec.md`

## What to build

README steps that load the existing author certificate and its password into the fork's secrets, and keep a copy of the certificate outside the `samsucks-home` volume. Then a throwaway release that proves a CI-signed `.wgt` installs over the app already on the dev TV.

This ticket needs the developer: the certificate and password live on their machine, and the install needs their TV.

## Acceptance criteria

- [ ] The README lists the exact commands to base64 `samsucks.p12` from the `samsucks-home` volume and set `TIZEN_AUTHOR_P12_BASE64` and `TIZEN_CERT_PASSWORD` with `gh secret set` on `PeloNZ/samsucks`.
- [ ] The README tells the developer to keep a copy of the `.p12` and its password outside the volume, and says why (ADR 0005).
- [ ] The developer sets the secrets.
- [ ] Throwaway release: on a branch, set `config.xml` to a spare version, push the matching tag to the fork, and wait for the Release.
- [ ] The `.wgt` from that Release installs over the current app on the dev TV with no uninstall, and the app keeps its sign-in.
- [ ] The throwaway Release and tag are deleted afterwards.
- [ ] A tag that differs from `config.xml` fails the release job (run once, then delete the tag).

## Comments

Agent part done on `build-ci` (merge 9548925): README section with the `base64` and `gh secret set` commands for `TIZEN_AUTHOR_P12_BASE64` and `TIZEN_CERT_PASSWORD`, the backup advice with the ADR 0005 reason, and the tag steps. Criteria 1 and 2 are done. The commands were not run, because running them reads the certificate and sets secrets.

Left for the developer: set the secrets; the throwaway release; install the `.wgt` over the app on the dev TV; delete the Release and tag; run the mismatched-tag test.
