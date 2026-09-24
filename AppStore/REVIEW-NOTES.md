# App Review notes

Paste into **App Review Information → Notes**. Reply in Resolution Center with the
same answers where Apple asked for a message-thread response.

---

## Notes for the reviewer

Force is a prop for magicians, sold to performers rather than to the general public. It
presents a working calculator that, at a moment the performer chooses, displays a number
the performer picked in advance. The effect is that a spectator's own arithmetic appears
to land on a prediction the performer made earlier.

The calculator is deliberately unremarkable, because a spectator who notices anything
unusual about it has already seen through the trick. That means several controls are
intentionally concealed **from the spectator**. None of them are concealed from you, and
all of them are listed below.

### Answers to the previous review

**Price (Guideline 3.0).** Yes — **$49.99 is the intended price**. Force is a professional
magician's prop, not a mass-market utility.

**Equals after the selected count (Guideline 2.1).** With the defaults (force number
4,556,325, activation count 3): type any calculation, then press `=`. The first two
presses of `=` behave like a normal calculator (they show the true arithmetic result /
repeat). On the **third** press of `=`, the display shows **4,556,325** instead of the
arithmetic result. That is the force. Every other key does exactly what a calculator does.

**Support URL (Guideline 1.5).** Updated to a live page we control:
https://forcemagic.app/support

**Screenshots (Guideline 2.3.3).** This build is **iPhone only** (no iPad). New screenshots
show the real UI in use: force reveal, settings, QR/NFC share, and the performer home.
Please ignore any leftover iPad media; the app no longer targets iPad.

**NFC demo video (Guideline 2.1).** The app writes an App Clip invocation URL to a
standard NFC sticker from **QR Code & NFC → Write to NFC Sticker**. There is no pairing
or proprietary hardware — any NDEF-writable tag works. Hold the iPhone near the sticker
when the system NFC sheet appears; after writing, tapping the sticker on another iPhone
opens the Force App Clip. A short device recording of that write-and-tap flow is linked
or attached with this submission when available; until then the steps above reproduce it
on any NFC-capable iPhone with a blank sticker.

### The basic effect

1. Open the app. The first screen is the performer's setup: a force number, and how many
   presses of equals should pass before it appears.
2. Leave the defaults (force number 4556325, activation count 3) and tap **Open Force
   Calculator**.
3. Type `12 + 34 =`. The display shows `46`, the correct answer.
4. Press `=` twice more. On the third press the display shows **4,556,325** instead of
   the arithmetic result. That is the force.

Every other press of every other key does exactly what a calculator does.

### Concealed controls, in full

| Control | How it is triggered | What it does |
| --- | --- | --- |
| Force reveal | The Nth press of `=`, N set in settings | Replaces the result with the force number |
| Performer's crib | Long press the number readout for 0.6s | Shows a small badge with the current mode and the number equals will land on. Auto-hides after 1.5s |
| Leave the calculator | Long press the clock icon, top left, for 0.45s | Returns to the settings screen. There is no visible Back button, because a spectator seeing one would know this is not the system calculator |
| Mode switch | Single tap the icon at top right | Switches between a fixed force number and a number built from the current date and time |
| Quick force entry | Tap the clock icon, type a number, press `=`, then press one digit | Overrides the force number and activation count for this session only. Never written to storage |
| Perfect Plus | Enabled in settings. Press `+`, then turn the phone face down | Works out the number that makes the running total equal the force, and places it on the display while the screen is hidden. The keypad is deliberately inert while the phone is face down so a stray touch cannot disturb it |
| Start with Screenshot | Enabled in settings | See the note below |
| Live Peek | Enabled in settings | See the privacy note below |

### About "Start with Screenshot"

With this setting on, the app launches showing an image the performer chose from their
own photo library, and a tap anywhere opens the calculator. Performers use a photo of
their own Home Screen so that handing over an unlocked phone does not reveal which app
is running.

We want to flag this explicitly rather than have you find it. If you would prefer the app
not to be able to imitate the Home Screen, we will remove the setting — please tell us
and we will resubmit without it. It is not central to the product.

### On resemblance to Apple's Calculator

The calculator is styled to look ordinary, and it necessarily resembles a plain
four-function calculator. It does not claim to be Apple's Calculator, is not named after
it, and carries its own icon and app name. Its layout differs from Apple's: the top row
is backspace, AC and percent, there is no scientific mode, and the operator keys are
tinted in a colour the performer chooses. The app is listed under Entertainment, and the
App Store description states plainly that it is a magic trick.

### Privacy and the network

The app talks to one Cloudflare Worker service (`force-config.jonmobley.workers.dev`,
also on forcemagic.app) and sends only two things:

- **The performer's own settings**, so that a printed QR code or an NFC sticker keeps
  working after the performer changes the force number. No personal data.
- **Live Peek**, off by default. When the performer switches it on, the calculation the
  spectator types into the App Clip is sent so the performer can read it on their own
  phone. Entries are short numeric strings and operators, kept briefly for the
  performance, then expire automatically; the performer can clear them at any time.
  They are never associated with a person or a device identifier.

There are no accounts, no analytics, no advertising, and no third-party SDKs. Each
install generates a random identifier and a random token on the device; neither is
derived from anything about the user or the hardware.

### The App Clip

The App Clip is the spectator's side. The performer shares a QR code or NFC sticker, the
spectator's phone opens the same calculator, and the force works there identically. The
clip reads the performer's current settings from the service at launch. To test it, open
the QR Code & NFC screen in the app and scan the code shown with a second device.

### Contact

Happy to demonstrate the trick over a call if anything here is easier to see than to
read.
