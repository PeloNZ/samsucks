# Build the feature registry with the second feature, not before

Movies and TV is the only feature today, so a registry seam has one adapter and is hypothetical. We build it when music or photos arrives, after the item-presentation and playback-session refactors. Until then `nav.js`, `home.js` `buildNav` and `plex/server.js` keep their fixed lists. Building the registry now would guess its shape from one case.
