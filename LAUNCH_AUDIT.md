# MouseOn Launch Audit

**Generated:** 2026-02-09  
**Status:** `gh` CLI not available — issues listed below need to be created manually on GitHub.

---

## 1. Input Validation Audit

### Current State

The app stores settings via `UserDefaults` through `SettingsStore.swift`. Here's what exists and what's missing:

#### ✅ What's Already Good
- **Numeric ranges are clamped on load:** `opacity`, `autoHideSeconds`, `maxNameLength`, `largeCursorDuration`, `largeCursorSize` all use `.clamped(to:)` or range checks when loading from UserDefaults
- **Sliders/Steppers use `in:` ranges** in the UI, preventing out-of-range input via the GUI
- **Emoji input** is truncated to `prefix(2)` in `DisplayRow.emojiBinding`
- **Feature toggles** are decoded as `Codable` with safe Bool defaults

#### ❌ What's Missing

| Field | Issue | Risk | Recommendation |
|-------|-------|------|----------------|
| **Display aliases** (TextField) | No length limit, no character sanitization | Low (local-only storage) but could cause UI overflow | Add `.characterLimit()` or `.onChange` trim to ~50 chars |
| **Display aliases** | No character filtering | Could contain control chars, RTL markers, newlines | Strip control characters, limit to printable + emoji |
| **Color hex strings** | No validation that stored strings are valid hex | App handles gracefully (falls back to default) but stores garbage | Validate `#[0-9A-Fa-f]{6}` pattern before saving |
| **Aliases dict keys** | No validation of dictionary keys from UserDefaults | Tampered plist could inject arbitrary keys | Low risk — keys are display IDs, not user-facing |
| **Numeric values not clamped on save** | Values are clamped on load but not on save | Inconsistent — a crafted UserDefaults write could store out-of-range values until next load | Add clamping in `save()` or use property wrappers |
| **Emoji field** | `prefix(2)` is a rough heuristic for emoji length | Some emoji (flags, ZWJ sequences) are >2 UTF-16 code units | Use `prefix(1)` on `Character` level: `String(newValue.prefix(1))` where prefix operates on Characters |

#### Risk Assessment: **LOW**
This is a local macOS app with no network input, no server, no database. All input comes from the user's own UI or their own UserDefaults plist. Input validation improvements are good practice but not security-critical.

---

## 2. Sparkle Framework Research

### What is Sparkle?
[Sparkle](https://sparkle-project.org/) is the de facto standard for macOS OTA updates outside the Mac App Store. Used by apps like Firefox, VLC, Sketch.

### Integration Steps

#### A. Add Sparkle to the Project
```
// Swift Package Manager (recommended)
// In Xcode: File → Add Package Dependencies
// URL: https://github.com/sparkle-project/Sparkle
// Version: 2.x (latest stable)
```

Or via CocoaPods/Carthage, but SPM is cleanest for a modern Swift app.

#### B. Code Integration
```swift
// In MouseOnApp.swift or AppDelegate
import Sparkle

// Create updater controller
let updaterController = SPUStandardUpdaterController(
    startingUpdater: true,
    updaterDelegate: nil,
    userDriverDelegate: nil
)

// Add "Check for Updates" menu item bound to:
updaterController.checkForUpdates(nil)
```

For SwiftUI menu bar apps, add to the `Settings` scene or a menu:
```swift
Button("Check for Updates…") {
    updaterController.checkForUpdates(nil)
}
```

#### C. Info.plist Keys
```xml
<key>SUFeedURL</key>
<string>https://raw.githubusercontent.com/Omarabiakar18/MouseOn/main/appcast.xml</string>
<key>SUPublicEDKey</key>
<string>YOUR_ED25519_PUBLIC_KEY</string>
```

#### D. Server-Side: Appcast XML
Host an `appcast.xml` file (can be in the repo or on GitHub Pages):
```xml
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>MouseOn Updates</title>
    <item>
      <title>Version 1.1.0</title>
      <sparkle:version>1.1.0</sparkle:version>
      <sparkle:shortVersionString>1.1.0</sparkle:shortVersionString>
      <pubDate>Mon, 09 Feb 2026 00:00:00 +0000</pubDate>
      <enclosure
        url="https://github.com/Omarabiakar18/MouseOn/releases/download/v1.1.0/MouseOn-1.1.0.dmg"
        sparkle:edSignature="BASE64_SIGNATURE_HERE"
        length="12345678"
        type="application/octet-stream" />
      <sparkle:minimumSystemVersion>13.0</sparkle:minimumSystemVersion>
    </item>
  </channel>
</rss>
```

#### E. Hosting Updates
**GitHub Releases** works perfectly:
1. The existing `release.yml` workflow already creates DMG + ZIP and publishes to GitHub Releases
2. After each release, update `appcast.xml` with the new version info
3. Can automate appcast generation with `generate_appcast` tool from Sparkle

#### F. Code Signing Requirements
- **EdDSA (Ed25519):** Required for non-sandboxed apps. Generate with Sparkle's `generate_keys` tool
- **Apple code signing:** The current workflow uses `CODE_SIGN_IDENTITY="-"` (ad-hoc). For Sparkle to work well:
  - Minimum: Ed25519 signing (Sparkle's own mechanism)
  - Recommended: Developer ID certificate for notarization + Gatekeeper
  - The Ed25519 key pair is generated once, public key goes in Info.plist, private key signs releases

#### G. Workflow Enhancement
Add to the release workflow:
```yaml
- name: Sign for Sparkle
  run: |
    # Generate signature for the DMG
    ./bin/sign_update "dist/MouseOn-${VERSION}.dmg"
```

### Effort Estimate: ~2-4 hours for basic integration

---

## 3. Existing CI/CD Assessment

### `.github/workflows/release.yml` ✅
- Triggers on version tags (`v*`) or manual dispatch
- Builds release archive on macOS 14
- Creates DMG with `create-dmg` (with `hdiutil` fallback)
- Creates ZIP
- Publishes to GitHub Releases
- **Missing:** Code signing (uses ad-hoc), notarization, Sparkle signature, universal binary (arm64 only)

### `.github/workflows/ci.yml`
- Exists (not inspected in detail)

---

## 4. GitHub Issues for Launch

> **⚠️ `gh` CLI not available.** Create these issues manually on GitHub.

### App Issues

#### Issue #1: Integrate Sparkle for OTA Updates
**Labels:** `enhancement`, `app`, `priority:high`

Add Sparkle 2.x framework for automatic update checking:
- [ ] Add Sparkle via SPM
- [ ] Add `SUFeedURL` and `SUPublicEDKey` to Info.plist
- [ ] Generate Ed25519 key pair
- [ ] Add "Check for Updates" option in settings/menu
- [ ] Create initial `appcast.xml`
- [ ] Update release workflow to generate Sparkle signatures
- [ ] Update release workflow to auto-update appcast.xml

#### Issue #2: Add Input Validation for Display Aliases
**Labels:** `enhancement`, `app`, `priority:medium`

TextField for display aliases has no constraints:
- [ ] Add max length limit (~50 characters)
- [ ] Strip control characters and newlines
- [ ] Fix emoji binding to use Character-level prefix instead of UTF-16
- [ ] Add hex color validation before saving
- [ ] Clamp numeric values on save (not just load)

#### Issue #3: Improve DMG Build Workflow
**Labels:** `enhancement`, `ci`, `priority:high`

Enhance `release.yml`:
- [ ] Build universal binary (arm64 + x86_64) with `ONLY_ACTIVE_ARCH=NO` + multi-destination
- [ ] Add Developer ID code signing (requires certificate in GitHub secrets)
- [ ] Add notarization step (`xcrun notarytool`)
- [ ] Add Sparkle EdDSA signature generation
- [ ] Auto-generate/update appcast.xml
- [ ] Add CHANGELOG generation from git commits

#### Issue #4: Add App Notarization
**Labels:** `enhancement`, `app`, `priority:high`

Apple notarization for Gatekeeper:
- [ ] Obtain Apple Developer ID certificate
- [ ] Add `notarytool` step to release workflow
- [ ] Staple notarization ticket to DMG
- [ ] Remove "right-click to open" instruction from release notes

---

### Website Issues

#### Issue #5: Mobile Responsive Design
**Labels:** `enhancement`, `website`, `priority:high`

Ensure the MouseOn website renders well on mobile devices:
- [ ] Test all breakpoints (320px, 768px, 1024px, 1440px)
- [ ] Fix any horizontal overflow
- [ ] Ensure touch targets are ≥44px
- [ ] Test on iOS Safari and Chrome

#### Issue #6: Add Open Graph and Meta Tags
**Labels:** `enhancement`, `website`, `priority:high`

For social sharing and SEO:
- [ ] Add `og:title`, `og:description`, `og:image`, `og:url`
- [ ] Add Twitter Card meta tags (`twitter:card`, `twitter:image`)
- [ ] Add `<meta name="description">` tag
- [ ] Create OG image (1200×630px) with app screenshot/branding

#### Issue #7: Add Favicon
**Labels:** `enhancement`, `website`, `priority:medium`

- [ ] Create favicon.ico (16x16, 32x32)
- [ ] Add apple-touch-icon (180x180)
- [ ] Add site.webmanifest for PWA metadata

#### Issue #8: Add sitemap.xml and robots.txt
**Labels:** `enhancement`, `website`, `priority:medium`

- [ ] Create `sitemap.xml` with all pages
- [ ] Create `robots.txt` allowing all crawlers
- [ ] Submit sitemap to Google Search Console

#### Issue #9: Add CTA Download Button
**Labels:** `enhancement`, `website`, `priority:high`

- [ ] Add prominent "Download" button linking to latest GitHub Release
- [ ] Consider dynamic link to latest release via GitHub API
- [ ] Add system requirements info (macOS 13+)

#### Issue #10: Add Cookie/Privacy Notice
**Labels:** `enhancement`, `website`, `priority:low`

- [ ] If using analytics, add cookie consent banner
- [ ] If no cookies/analytics, add a simple privacy statement
- [ ] Link to privacy policy

---

### Marketing Issues

#### Issue #11: Prepare Launch Post
**Labels:** `marketing`, `priority:high`

- [ ] Write launch blog post / announcement
- [ ] Prepare Twitter/X thread with GIFs showing features
- [ ] Create short demo video (30-60s)

#### Issue #12: Create Social Media Assets
**Labels:** `marketing`, `priority:medium`

- [ ] App icon in various sizes for social profiles
- [ ] Feature screenshots with macOS frame mockups
- [ ] Animated GIF showing cursor tracking in action
- [ ] Banner images for Twitter, GitHub repo

#### Issue #13: Product Hunt Launch
**Labels:** `marketing`, `priority:medium`

- [ ] Create Product Hunt maker profile
- [ ] Prepare launch assets (gallery images, description, tagline)
- [ ] Schedule launch for a Tuesday (best day)
- [ ] Prepare "first comment" with backstory

---

### Legal Issues

#### Issue #14: Create Privacy Policy / Data Handling Docs
**Labels:** `legal`, `priority:high`

- [ ] Document what data the app collects (stats file only, local)
- [ ] Create privacy policy page on website
- [ ] Add privacy info to App Store listing (if applicable)
- [ ] Document that no data leaves the device

#### Issue #15: GDPR Compliance Review
**Labels:** `legal`, `priority:medium`

- [ ] Confirm no personal data is transmitted
- [ ] If analytics added to website, ensure GDPR consent
- [ ] Add data deletion instructions (delete app = delete data)

---

### SEO Issues

#### Issue #16: Google Search Console Setup
**Labels:** `seo`, `priority:medium`

- [ ] Verify domain ownership in Google Search Console
- [ ] Submit sitemap
- [ ] Monitor indexing

#### Issue #17: Bing Webmaster Tools + IndexNow
**Labels:** `seo`, `priority:low`

- [ ] Register with Bing Webmaster Tools
- [ ] Implement IndexNow for instant index notification
- [ ] Add IndexNow key file to website root

---

### Payment Issues

#### Issue #18: Resolve Payment Provider (Paddle vs FastSpring)
**Labels:** `business`, `priority:high`

Decide on payment/licensing provider for paid version (if applicable):
- [ ] Research Paddle for macOS apps (handles EU VAT)
- [ ] Research FastSpring as alternative
- [ ] Decide free vs freemium vs paid model
- [ ] Implement license key validation if going paid
- [ ] Note: Can defer if launching as free/open-source

---

## 5. Summary

| Category | Issues | Critical for Launch |
|----------|--------|-------------------|
| App | 4 issues (#1-4) | Sparkle + notarization |
| Website | 6 issues (#5-10) | OG tags + CTA button |
| Marketing | 3 issues (#11-13) | Launch post |
| Legal | 2 issues (#14-15) | Privacy policy |
| SEO | 2 issues (#16-17) | Post-launch OK |
| Payment | 1 issue (#18) | Only if going paid |

### Minimum Viable Launch Checklist
1. ✅ DMG build workflow exists
2. ⬜ Add notarization (or accept "right-click to open" UX)
3. ⬜ OG tags + meta tags on website
4. ⬜ Download CTA button on website
5. ⬜ Privacy policy (even a simple one)
6. ⬜ Launch announcement post
7. ⬜ Sparkle integration (can be v1.1 — not blocking v1.0)
