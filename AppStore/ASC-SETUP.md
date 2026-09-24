# App Store Connect setup checklist

Privacy policy (live): https://forcemagic.app/privacy

## App record

| Field | Value |
| --- | --- |
| Name | Force |
| Bundle ID | com.mobleypro.mobley.Force |
| SKU | force-calculator |
| Primary language | English (U.S.) |
| Category | Entertainment |
| Privacy Policy URL | https://forcemagic.app/privacy |
| Support URL | https://forcemagic.app/support |

Copy description, keywords, and promo text from [LISTING.md](LISTING.md).

## Privacy nutrition labels

Match [Force/PrivacyInfo.xcprivacy](../Force/PrivacyInfo.xcprivacy):

| Data type | Purpose | Linked to identity | Used for tracking |
| --- | --- | --- | --- |
| Other User Content (spectator calculation / settings) | App Functionality | No | No |

No Contact Info, Location, Identifiers, Purchases, Usage Data, Diagnostics, or Surroundings.

## App Clip

- Bundle ID: `com.mobleypro.mobley.Force.Clip`
- Advanced App Clip Experience invocation URL pattern:
  `https://appclip.apple.com/id?p=com.mobleypro.mobley.Force.Clip`
- Desired query: `id` (performer). Stickers use
  `https://appclip.apple.com/id?p=com.mobleypro.mobley.Force.Clip&id=<performer>`
- Header image: use screenshot `03-share-qr-nfc.png` cropped if Apple asks for a card image

## Screenshots

Upload from `Screenshots/iPhone-6.9/` (1320×2868, no alpha):

1. `01-force-reveal.png`
2. `02-settings.png`
3. `03-share-qr-nfc.png`
4. `04-performer-view.png`

## App Review

Paste [REVIEW-NOTES.md](REVIEW-NOTES.md) into App Review Information → Notes.
Attach a performance video. Contact: jonmobley@gmail.com

## Product decisions already made

- Deployment target: **iOS 17.0**
- **Keep** Start with Screenshot (disclosed in review notes)

## Automated ship (blocked only on Issuer ID)

API keys are already on disk:

- `~/.appstoreconnect/private_keys/AuthKey_M9XV4SS39X.p8` (Force Calculator, Admin)

This Mac has an **Apple Development** identity only — no **Apple Distribution**
certificate yet. Xcode will create one on first App Store export when signed in.

To finish ASC + upload in one shot, copy the Issuer ID from
[App Store Connect → Users and Access → Integrations → App Store Connect API](https://appstoreconnect.apple.com/access/integrations/api)
(the UUID above the keys table), then:

```bash
export APP_STORE_CONNECT_API_KEY_ID=M9XV4SS39X
export APP_STORE_CONNECT_API_ISSUER_ID='paste-uuid-here'
./AppStore/asc-ship.sh
```

Listing copy, privacy labels, App Clip notes, screenshots, and review notes are
ready in this folder.
