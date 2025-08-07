# PurgePoint

PurgePoint is a minimal, secure macOS menu bar utility designed to overwrite free space on internal or external drives — helping prevent the recovery of deleted files.

## ✨ Key Features

- Overwrites free space with junk data to prevent forensic recovery  
- Supports internal and external volumes  
- Live progress updates via menu bar  
- Optional 2GB safety buffer to avoid disk full errors  
- Native macOS app, optimized for Apple Silicon  
- Sandboxed, no tracking, no unnecessary permissions  
- App Store-compliant (auto-launch removed)  
- Local-only processing, no data leaves the machine  

## 🚀 Getting Started

### Build & Run

1. Open `PurgePoint.xcodeproj` in Xcode  
2. Ensure your signing identity is valid (App Store or Developer ID)  
3. Build and run the app as a standard macOS menu bar utility  

### App Store Prep

- ✅ Hardened Runtime enabled  
- ✅ Notarized with `xcrun notarytool`  
- ✅ App Sandbox enabled  
- ✅ Login item removed as per App Store guidelines  
- ✅ Live updates and decimal precision added for clarity  

### Example Notarization Command

```bash
xcrun notarytool submit /path/to/PurgePoint.zip \
  --keychain-profile "YourKeychainProfile" \
  --wait
```

## 🛡️ What It Does (and Doesn’t)

### ✅ Does

- Fills free space with large junk files to prevent recovery of deleted data  
- Creates a temporary folder (`bigfilefill`) during overwrite, then deletes it  
- Shows current wipe progress and estimated free space  
- Preserves a 2GB safety buffer by default  

### ❌ Doesn’t

- Recover deleted files  
- Analyze disk usage  
- Modify or delete existing user files  
- Reveal or catalog what's been deleted  
- Interact with cloud storage or external services  

## 📁 Repository Structure

```
PurgePoint/
├── MenuBarController.swift
├── WipeManager.swift
├── SettingsManager.swift
├── Resources/
│   └── Assets.xcassets
├── Info.plist
└── ...
```

## 🧠 FAQ / Clarifications

**Why overwrite free space?**  
Deleted files are often recoverable using forensic tools until the storage space they occupied is physically overwritten. PurgePoint fills that space with random junk data to prevent recovery.

**Can’t I just do this with Terminal?**  
Technically yes, but doing so incorrectly can corrupt your drive or trigger excessive SSD wear. PurgePoint handles the process safely, with guardrails and a clear interface.

**Is this secure erasure?**  
PurgePoint does not overwrite individual files. It overwrites *unused* space. If you want to securely delete specific files, use `srm` in Terminal or a tool designed for file shredding.

**What’s in the junk data?**  
The app writes large files filled with random, non-sensitive byte data (e.g., `/dev/urandom` or nulls) to simulate realistic overwrite conditions.

**Why does it sometimes start slow?**  
macOS caches disk availability and may delay new file writes on SSDs. Once large file writes begin, progress should accelerate.

**What about SSD wear?**  
PurgePoint preserves a safety buffer, doesn't touch system partitions, and isn't meant for daily use. For casual security hygiene, monthly usage is more than sufficient.

## 🏁 Status

PurgePoint is actively maintained and ready for public release. Feedback and improvements welcome via private repo or future public issues.

---

© 2025 WetSadTears Studios. All rights reserved.
