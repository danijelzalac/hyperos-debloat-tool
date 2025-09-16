
# hyperos-debloat

Universal **HyperOS** debloat via **ADB** (no root). Device-agnostic: the script only disables packages that actually exist on your device.
- Profiles: `safe` (recommended), `optional` (aggressive), `all` (safe+optional)
- Reversible: uses `disable-user` first; falls back to `uninstall --user 0`
- Supports **dry-run**, **logs**, and **revert**
- Works on Linux/macOS (shell) and Windows (`.bat`)

> ⚠️ Disclaimer: Use at your own risk. Disabling/removing system apps can affect features and OTA updates. Always make a backup.



## Disclaimer

This software is provided **as-is**, without any warranties. By using it, **you accept all risks**. 
The author(s) and contributors **are not responsible** for any data loss, boot issues, feature regressions, 
voided warranties, or any other damage or consequences arising from the use of this tool. 
Not affiliated with Xiaomi/POCO/Redmi or any vendor.

---

## Quick start (Linux)

1) Install platform tools (ADB). Examples:
   - Fedora / Bazzite (immutable):
     ```bash
     sudo rpm-ostree install android-tools
     systemctl reboot
     ```
   - Ubuntu/Debian:
     ```bash
     sudo apt update && sudo apt install android-tools-adb android-tools-fastboot
     ```

2) Enable **USB debugging** on your phone (Developer options). If you see a `SecurityException`, also enable **USB debugging (Security settings)**.

3) Run:
```bash
# safe (recommended)
./debloat.sh --profile safe

# deeper cleanup
./debloat.sh --profile optional

# everything (safe + optional)
./debloat.sh --profile all

# dry-run (print planned actions only)
./debloat.sh --profile safe --dry-run

# revert all (enable/install-existing)
./debloat.sh --revert
```

Logs are written as `debloat-YYYY-MM-DD_HHMMSS.log` and a package inventory is saved as `packages-backup-YYYY-MM-DD.txt`.

---

## Quick start (Windows)

1) Install **Platform Tools** and ensure `adb.exe` is in your PATH.
2) Enable **USB debugging** on the phone.
3) Open **Command Prompt** in the repo folder and run one of:
```
debloat.bat safe
debloat.bat optional
debloat.bat all
debloat.bat revert
debloat.bat dryrun
```

The batch script will create a `packages-backup-YYYY-MM-DD.txt` and then apply the chosen profile.

---

## Profiles

Package lists live under `device-profiles/`:

- `hyperos-safe.txt` – ads/analytics (MSA), GetApps, Quick Apps, some Mi apps that have obvious alternatives.
- `hyperos-optional.txt` – deeper cleanup: Mi Cloud, TSM/Pay, SIM activation, wallpapers, scanner, partner bloat (Facebook bundle, Netflix stub, Amazon), etc.

> The scripts **protect** critical packages (Updater, Launcher, Security Center, SystemUI, Settings, Play Services/Store, Camera, Theme manager).

---

## Revert (per app)

```bash
# if it was disabled:
adb shell pm enable --user 0 <package>

# if it was "uninstalled for user 0":
adb shell cmd package install-existing --user 0 <package>
```

Contributions welcome: add device-specific lists or improvements as PRs.
