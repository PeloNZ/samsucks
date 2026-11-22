# Items use Plex fields directly, with per-type adapters

Screens read Plex JSON fields (`grandparentThumb`, `viewedLeafCount`, `Media[0].Part[0].Stream`). We do not map Plex into a backend-neutral item shape. Apps that support several backends pay that cost; this app supports only Plex. New item types (track, album, photo) add one adapter entry for art, title, subtitle, badge, open and play.
