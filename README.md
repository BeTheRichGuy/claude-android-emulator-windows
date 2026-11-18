# claude-android-emulator-windows

Let Claude Code drive a local Android emulator on Windows: see the screen, tap, swipe, type and open apps. Free, no cloud phone.

This repo does not contain an emulator. It is a setup script that wires together two existing projects:

- [Android Emulator](https://developer.android.com/studio/run/emulator) by Google (Android SDK License)
- [mobile-mcp](https://github.com/mobile-next/mobile-mcp) by mobile-next (Apache-2.0), the MCP server Claude uses to control the phone

Everything is downloaded from the official sources when you run the script. No Google, Meta or mobile-next binaries are stored here.

## Requirements

- Windows 10 or 11, x64, with virtualization turned on (Windows Hypervisor Platform)
- [Node.js](https://nodejs.org) 20 or newer
- [Claude Code](https://docs.claude.com/en/docs/claude-code)
- About 4 GB of disk space and 8 GB of RAM or more

## Setup

```powershell
git clone https://github.com/BeTheRichGuy/claude-android-emulator-windows.git
cd claude-android-emulator-windows
powershell -ExecutionPolicy Bypass -File .\setup.ps1
```

The script, step by step (no administrator rights needed, safe to run again):

1. Java 17: Microsoft OpenJDK zip into `%LOCALAPPDATA%\Java`
2. Android command-line tools into `C:\Android\Sdk`
3. User environment variables: `JAVA_HOME`, `ANDROID_HOME`, `ANDROID_SDK_ROOT`, `ANDROID_USER_HOME`, `ANDROID_AVD_HOME`, `PATH`
4. Google's SDK licenses, which **you** read and accept, then platform-tools (adb), the emulator and the Android 15 Google Play image (about 2 GB)
5. A check that hardware acceleration works
6. A Pixel 7 virtual device named `claude`, with Play Store on, 4 GB RAM, host GPU and persistent storage
7. mobile-mcp, registered in Claude Code for all projects

Options: `-SdkRoot`, `-AndroidHome`, `-AvdName`, `-ApiLevel`, `-Device`, `-JdkRoot`, `-MobileMcpVersion`.

## Use

```bat
start-emulator.cmd
```

Then open a **new** Claude Code session (MCP servers load at session start) and ask, for example, "open the Play Store on the phone and search for a weather app".

Sign in to Google and to any app yourself in the emulator window. Do not give passwords to the agent.

## Windows pitfalls this script handles

| Problem | What the script does |
| --- | --- |
| The emulator fails on paths with non-ASCII characters (for example a Korean or Japanese user name under `C:\Users`) | Keeps the SDK and virtual devices under `C:\Android` and refuses non-ASCII paths |
| `winget install` of a JDK waits silently on a UAC prompt | Uses the JDK zip build in the user folder |
| `avdmanager` creates the device with Play Store off, 2 GB RAM and `disk.dataPartition.path=<temp>`, so app logins can disappear | Rewrites those lines in `config.ini` |
| mobile-mcp 1.0.17's bundled `mobilecli` (1.0.23) lists no local emulators on Windows even when `adb devices` shows them | Sets `MOBILEMCP_LEGACY_ROBOT=1` so mobile-mcp talks to adb directly |
| `avdmanager` prints `Error: Could not load devices from ...\devices.xml` | Harmless; the device is still created (the script checks for `config.ini`) |
| A first adb connection can leave an "Allow USB debugging?" prompt on the phone | Tick "Always allow from this computer" and tap Allow once |

mobile-mcp sends usage telemetry by default; the script turns it off with `MOBILEMCP_DISABLE_TELEMETRY=1`.

## Notes

- Many apps detect emulators. Expect extra security checks on sign-in, and follow the terms of service of any app you automate.
- Remove: `claude mcp remove mobile-mcp -s user`, then delete `C:\Android` and the user environment variables listed above.

## License

MIT for the files in this repo. The Android SDK, mobile-mcp and mobilecli keep their own licenses.

---

## 한국어 요약

Windows에서 구글 안드로이드 에뮬레이터를 깔고, mobile-mcp로 Claude Code에 연결하는 설치 스크립트입니다. 에뮬레이터를 새로 만든 것이 아니라 공식 도구를 받아 설정하고, 한글 사용자 경로 문제와 mobilecli가 에뮬레이터를 못 찾는 문제를 피해 갑니다. `setup.ps1`을 실행한 뒤 `start-emulator.cmd`로 켜고, 새 Claude Code 세션에서 쓰면 됩니다. 구글·앱 로그인은 직접 하세요.
