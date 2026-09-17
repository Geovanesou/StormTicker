# ⚡ StormTicker — Asynchronous Desktop News Matrix

[![Rainmeter](https://img.shields.io/badge/Rainmeter-4.5%2B-2563EB?style=for-the-badge&logo=windows&logoColor=white)](https://www.rainmeter.net/)
[![Version](https://img.shields.io/badge/Version-1.0.0-f59e0b?style=for-the-badge)](https://github.com/Geovanesou/StormTicker/releases)
[![License](https://img.shields.io/badge/License-Proprietary-D97706?style=for-the-badge)](LICENSE)
[![DeviantArt](https://img.shields.io/badge/DeviantArt-geovanesou-00E59B?style=for-the-badge&logo=deviantart&logoColor=black)](https://www.deviantart.com/geovanesou)

<p align="center">
  <img src="assets/stormticker-release.jpg" alt="StormTicker Release Showcase" width="100%">
</p>

> **A high-performance, asynchronous news ticker matrix for Rainmeter.**  
> Featuring hardware-accelerated DirectWrite text streaming, full visual source management without text editors, intelligent hover pauses, interactive mouse wheel scrubbing, and direct portal navigation.

---

## ⚡ Upgrade to StormTicker Pro (10 Channels)

Want to run up to **10 completely independent channels simultaneously** with individual speed controls, custom refresh cadences, and exclusive features?

👉 **[Unlock StormTicker Pro on DeviantArt](https://www.deviantart.com/geovanesou/art/1381771713)**

| Feature | StormTicker (Free) | StormTicker Pro |
|---|:---:|:---:|
| **Concurrent News Lines** | 3 Channels | **10 Channels** |
| **Pro Feature Showcase Stream** | ✅ Included | Full Matrix Mode |
| **Direct Portal Navigation** | ✅ Included | ✅ Included |
| **DirectWrite Hardware Acceleration** | ✅ 60 FPS | ✅ 60 FPS |
| **Smart Hover Freeze & Mouse Scrubbing** | ✅ Included | ✅ Included |
| **Individual Speed Tuning per Row** | Standard | **Full (0.5x to 1.5x)** |
| **Custom Refresh Intervals (15m to 6h)** | Standard | **Full Selector** |
| **Lifetime Updates & Priority Support** | Community | **VIP / Pro** |

---

## 📖 Overview

**StormTicker** is an original, ground-up desktop news ticker suite engineered for traders, developers, and information enthusiasts who want continuous, real-time market and news feeds without cluttering their workspace.

Running smooth, asynchronous news lines powered by Lua and DirectWrite, StormTicker streams real-time RSS/Atom headlines at a silky-smooth 50–60 FPS with sub-1% CPU footprint.

---

## 🌟 Key Features

### 🚀 Asynchronous DirectWrite Matrix
- **True Multi-Stream Concurrency:** Channels operate on independent speed factors, creating a dynamic, non-repetitive visual flow across your desktop.
- **Hardware-Accelerated Container Clipping:** Every channel is confined within a dedicated DirectWrite shape container, delivering flawless motion without screen tearing.
- **Direct Portal Navigation:** Clicking on any channel tag badge instantly opens the publication's root homepage directly in your default browser.
- **Seamless Infinite Loop:** Proprietary Lua wrap-around logic recycles headlines when the end of a batch is reached without stutter or visual jumps.
- **Dynamic Auto-Height:** The widget dynamically resizes its height to fit only active rows, cleanly stacking lines with zero wasted space.

### 🎛️ Visual Feed Manager (Zero Text Editors Required!)
- **Tabbed Settings GUI (`Settings.ini`):** Click the `⚙️` gear button to open a dynamic control center with dedicated tabs and independent toggles.
- **Native Edit Dialogs:** Click any visual Tag or URL box to edit feeds directly in a standard, focused Windows dialog without text editor headaches.

### 🧠 Smart Hover & Interactivity
- **Selective Row Freeze:** Sweeping your cursor over any channel pauses only that row for effortless reading, while the remaining rows continue streaming uninterrupted.
- **Interactive Mouse Scroll Scrubbing:** Roll the mouse wheel (Up/Down) over any hovered channel to scrub forward or backward through headlines in 50px increments at your own pace.
- **Extrapolated Multi-Line Tooltips:** Expanded 620px viewport with intelligent auto-wrapping prevents headline truncation.
- **Direct Article Dispatch:** Clicking on any paused or scrubbed headline instantly opens that exact story in your default browser.

---

## 📦 Installation & Setup

1. Make sure you have **[Rainmeter 4.5+](https://www.rainmeter.net/)** installed on Windows 10 or 11.
2. Clone or download the repository into your Rainmeter skins directory:
   ```bash
   git clone https://github.com/Geovanesou/StormTicker.git "%USERPROFILE%\Documents\Rainmeter\Skins\StormTicker"
   ```
3. Right-click the Rainmeter tray icon and select **Refresh all**.
4. In the Rainmeter Manage window, navigate to `StormTicker > StormTicker.ini` and click **Load**.
5. Click the **⚙️ FONTES** button in the header to customize your channels.

---

## 📄 License & Attribution

Copyright (c) 2026 **Geovane Souza** ([@Geovanesou](https://github.com/Geovanesou)). All Rights Reserved.  
Distributed under the [Proprietary Software License](LICENSE) for personal desktop customization.
