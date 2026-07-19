# HairColorPro — build the iPhone app from a Windows laptop

You have a **native iOS app** (Swift / SwiftUI). Apple only lets a native iPhone
app be compiled on a **Mac with Xcode** — there is no way to compile it directly
on Windows. So this kit does the next best thing:

1. **GitHub builds it for you on a real Mac in the cloud** (free) — fully automatic.
2. You download the finished app file (`.ipa`).
3. You install it onto your iPhone **from Windows** using **Sideloadly** + your
   free Apple ID.

No Mac required, no paid Apple Developer account required.

---

## What you need

- A **GitHub** account (free) — https://github.com
- Your **iPhone** + its USB cable
- Your **Apple ID** (a normal free Apple ID is fine)
- **Windows 10/11** (you have this)

---

## Step 1 — Put this project on GitHub

Pick **one** of the two ways below.

### Way A — GitHub Desktop (easiest, no commands)

1. Install **GitHub Desktop**: https://desktop.github.com — sign in with your
   GitHub account.
2. `File → Add local repository…` and choose this unzipped folder
   (the one that contains `project.yml` and the `HairColorPro` folder).
   If it says it's not a repository, click **"create a repository"** on that prompt.
3. Give it a name like `HairColorPro`, click **Create repository**.
4. Click **Publish repository** (top bar). Leave "Keep this code private" checked
   or unchecked — either works (see the note on minutes below). Click **Publish**.

### Way B — git command line

Open a terminal in this folder and run:

```bash
git init
git add .
git commit -m "HairColorPro iOS"
# create an empty repo named HairColorPro on github.com first, then:
git remote add origin https://github.com/YOUR_USERNAME/HairColorPro.git
git branch -M main
git push -u origin main
```

> **Public vs private repo:** GitHub Actions is **unlimited for public repos**.
> Private repos also get a free monthly allowance, but macOS build minutes count
> 10× against it. This code isn't sensitive, so **public is the safe choice** if
> you don't want to think about minutes. Either works for a few builds.

---

## Step 2 — Let the Mac build it (automatic)

The moment you push, GitHub starts building on a Mac. To watch/download:

1. Open your repo on **github.com**.
2. Click the **Actions** tab.
3. Click the latest run named **"Build iPhone app (unsigned IPA)"**.
   - A green ✓ = success (takes ~3–6 minutes).
   - If it's the first time and nothing ran, click **Run workflow** on the right.
4. Scroll to the bottom to the **Artifacts** section and download
   **`HairColorPro-unsigned-ipa`**. It's a `.zip` — open it and inside is
   **`HairColorPro-unsigned.ipa`**. That's your app.

> The `.ipa` is **unsigned** on purpose. Sideloadly signs it with *your* Apple ID
> during install in the next step — that's what makes it run on *your* iPhone.

---

## Step 3 — Install onto your iPhone from Windows (Sideloadly)

1. Install **iTunes** (the Apple version from apple.com, or Microsoft Store) and
   **iCloud for Windows** — Sideloadly needs Apple's drivers underneath.
2. Download and install **Sideloadly**: https://sideloadly.io (Windows).
3. Plug your **iPhone into the PC** with the cable. On the iPhone tap **Trust**,
   enter your passcode.
4. Open **Sideloadly**:
   - Your iPhone should appear in the **device** dropdown at the top.
   - In **Apple ID**, type your Apple ID email.
   - Drag **`HairColorPro-unsigned.ipa`** onto the Sideloadly window (or click the
     IPA field and pick it).
   - Click **Start**. Enter your Apple ID password when asked.
     (If you use 2-factor auth, create an **app-specific password** at
     https://account.apple.com → Sign-In & Security → App-Specific Passwords,
     and paste that instead.)
5. Wait for **"Done"**. The **HairColorPro** icon now appears on your iPhone.

### Step 4 — Trust the app, then open it

The first launch shows *"Untrusted Developer"*. On the iPhone:

**Settings → General → VPN & Device Management →** tap your Apple ID under
*Developer App* → **Trust**.

Now open **HairColorPro**. Tap **Upload Picture** or **Camera**, then
**Analyze Hair Color**.

> **The 7-day rule:** apps installed with a *free* Apple ID stop opening after
> **7 days**. To renew, just re-run Sideloadly (Step 3) — it re-signs for another
> 7 days and keeps your data. A paid Apple Developer account ($99/yr) extends this
> to a year, if you ever want that.

---

## Troubleshooting

- **Actions build failed (red ✗):** open the failed step's log. If it's about a
  *scheme not found*, check the "List schemes" step output and tell me — I'll
  adjust. Most failures on first setup are just the free-minutes note above
  (use a public repo).
- **iPhone not showing in Sideloadly:** make sure iTunes + iCloud for Windows are
  installed, use a *data* USB cable, and tap **Trust** on the phone.
- **"Unable to install" / provisioning:** your Apple ID can sign up to 3 apps and
  must not have hit its device limit. Sign in to the same Apple ID on the phone.
- **App won't open after a week:** that's the 7-day expiry — re-run Sideloadly.

---

## What's in this folder

| File | Purpose |
|---|---|
| `HairColorPro/` | The app's Swift source + `Resources/palette_chart.json` (41-shade chart) |
| `project.yml` | XcodeGen config — turns the sources into an Xcode project |
| `.github/workflows/ios-build.yml` | The automatic cloud-Mac build |
| `build_unsigned_ipa.sh` | One-command build **if you ever use a real Mac** |
| `.gitignore` | Keeps generated build files out of git |

## The app itself

Upload or shoot a photo → on-device Apple Vision segments the hair → dominant
color is measured in CIE-LAB → matched to the reference chart → you get the shade,
a full mixing/how-to formula, and the complete chart with your match highlighted.
Minimum iPhone OS: **iOS 16**.
