# NixOS on the ThinkPad T14s G3 — Setup Plan

Your machine: **Lenovo ThinkPad T14s Gen 3**, Intel 12th-gen (Alder Lake-U, likely i5-1240P/1250P), 16 GB RAM, 256 GB SSD. Integrated Iris Xe graphics (no dGPU), almost certainly an Intel AX211 Wi-Fi card. All of this is well-supported by current NixOS — no exotic driver work needed.

## Decisions baked into this plan

| Decision | Choice | Why |
|---|---|---|
| Config format | **Flakes** | Reproducible, and the right foundation if you later want to share modules with your Mac's nix-darwin flake |
| Window manager | **Sway** (Wayland) | Modern default, mature Home Manager support, i3-like keybind model so it'll feel familiar, less config churn than Hyprland |
| Disk layout | GPT + LUKS2 full-disk encryption + ext4, no separate `/home` | Laptop leaves the house; 256 GB doesn't justify partition-splitting complexity yet |
| Swap | zram, no swap partition | Saves disk space; hibernation can be added later if you want it |
| Login | `greetd` + `tuigreet` | Lightweight, keyboard-driven, no heavy display manager |
| Browser | Firefox via Home Manager | Best Wayland support of the mainstream browsers |
| Editor | `vim` (not neovim) via Home Manager's `programs.vim` | You said vim specifically — neovim migration is a good "further refine" step later |
| Mac | **Untouched.** New flake/repo, not merged into your existing nix-darwin config | Per your note — but I'll write the Home Manager modules (especially vim) so they're portable into that flake later with minimal changes |

Flag anything in that table you want to change — easiest to swap now than after we've written config around it.

## Deliberately deferred (v2 territory, not v1)

- Secure Boot / Lanzaboote (starting with Secure Boot **off** for simplicity)
- TPM2-backed LUKS auto-unlock (your T14s has a TPM; worth doing once the base system is solid)
- Fingerprint reader (Goodix reader on this model has poor/no mainline Linux support — skip it)
- Hibernation / swap-to-disk
- Merging this flake with your Mac's nix-darwin flake into one shared repo
- Neovim migration
- Hyprland, if Sway ends up feeling too plain

---

## Phase 0 — Before touching the ThinkPad

**You:**
- [ ] Since it's a used machine: boot into BIOS (Enter or F1 at the Lenovo splash) and confirm there's no unknown supervisor/BIOS password and no leftover corporate MDM/Absolute enrollment. If either is present, flag it — that needs resolving before anything else.
- [ ] If Windows is still on it and boots fine, optionally run Windows Update / Lenovo Vantage once to grab the latest BIOS firmware while it's easy to do (not required — `fwupdmgr` can do this from NixOS later too).
- [ ] Confirm boot mode is **UEFI** (not Legacy/CSM) in BIOS setup.
- [ ] Have a spare USB drive (8 GB+) and know where your dotfiles live currently (Mac nix-darwin repo path), just for reference — we won't touch it.

**Me:**
- [ ] Nothing yet — waiting on you to confirm the machine is clean and in UEFI mode.

---

## Phase 1 — Installer media

**You:**
- [ ] Download the current NixOS stable ISO (26.05 "Yarara" as of now — check nixos.org/download for whatever's newest when you actually do this) — get the **Graphical** or **Minimal** ISO, doesn't matter much since we'll drive it from a TTY either way.
- [ ] Write it to the USB drive from your Mac. Easiest: [balenaEtcher](https://etcher.balena.io/), or `dd` if you're comfortable in Terminal:
  ```
  diskutil list                      # find the USB disk, e.g. /dev/disk4
  diskutil unmountDisk /dev/disk4
  sudo dd if=nixos.iso of=/dev/rdisk4 bs=4m status=progress
  ```
  (use `rdisk4` not `disk4` — much faster on macOS)

**Me:**
- [ ] On standby to help debug if `dd` or Etcher errors out.

---

## Phase 2 — BIOS setup on the ThinkPad

**You:**
- [ ] Enter BIOS setup (Enter/F1 at boot).
- [ ] Disable **Secure Boot**.
- [ ] Disable **Fast Boot / Fast Startup** if present (can prevent the USB boot menu from appearing reliably).
- [ ] Leave TPM enabled (we'll use it in v2).
- [ ] Save and reboot, tap **F12** for the one-time boot menu, and boot from your USB stick.

**Me:**
- [ ] Nothing to do yet.

---

## Phase 3 — Partition & base install

Once you're at the NixOS installer TTY:

**You:**
- [ ] Get online. Ethernet just works; for Wi-Fi run `nmtui` and connect.
- [ ] Confirm you're online: `ping -c3 nixos.org`
- [ ] Run `lsblk` and **paste the output back to me** — I need the exact device name (almost certainly `/dev/nvme0n1`, but confirm) before I hand you partitioning commands.

**Me (once I have your `lsblk` output):**
- [ ] Write a `disko.nix` config for you — GPT with a ~512 MiB FAT32 ESP and a LUKS2 container holding a single ext4 root, targeting the confirmed device. This makes partitioning/formatting/mounting a single declarative command instead of a manual `parted`/`cryptsetup`/`mkfs` dance (though I'll give you the manual fallback too, in case disko has a hiccup on first try).

**You:**
- [ ] Run the disko command I give you (something like `nix run github:nix-community/disko -- --mode disko ./disko.nix`). You'll be prompted to set your LUKS passphrase here — pick something you'll type every boot.
- [ ] Run `nixos-generate-config --no-filesystems --root /mnt` and **paste me the generated `hardware-configuration.nix`** (cat it out, or `nano`/copy from the installer).

**Me (once I have your hardware config):**
- [ ] Assemble the full `flake.nix` + `configuration.nix` + Home Manager modules (see Phase 4) tailored to your actual hardware output, and give you the exact files to create plus the `nixos-install` command to run.

---

## Phase 4 — The flake

Rough shape of what I'll hand you once Phase 3's checkpoint is done:

```
thinkpad-nixos/
├── flake.nix
├── hosts/thinkpad-t14s/
│   ├── configuration.nix        # system-level: networking, sway enable, pipewire, tlp, etc.
│   └── hardware-configuration.nix   # from your lsblk/generate-config output
└── home/
    ├── common.nix                # git, shell basics
    ├── vim.nix                   # ← the portable one, written to be Mac-flake-compatible later
    ├── sway.nix                  # keybinds, waybar, foot terminal, wofi launcher
    └── firefox.nix
```

System-level pieces `configuration.nix` will set up:
- `networking.networkmanager.enable = true`
- `hardware.enableRedistributableFirmware = true` (needed for the AX211 Wi-Fi and Intel microcode)
- `services.pipewire` (+ rtkit) for audio
- `services.tlp.enable = true` and `services.thermald.enable = true` for battery/thermal on this chip
- `services.fwupd.enable = true` so you can run `fwupdmgr` for BIOS/firmware updates going forward
- `services.greetd` with `tuigreet` launching Sway
- Home Manager wired in as a NixOS module (so `nixos-rebuild switch` rebuilds both system and user config in one command — mirrors how nix-darwin + Home Manager work together on your Mac)

`home/vim.nix` will be intentionally self-contained: sane defaults (line numbers, sensible indentation, incremental search, etc.) plus a small, easy-to-extend plugin list — nothing Linux-specific baked in — so that dropping the same file into your Mac's home-manager modules later should just work.

**You:**
- [ ] Nothing yet — this phase is me drafting, based on what you paste me from Phase 3.

**Me:**
- [ ] Draft all the files above and walk you through exactly where to place them and what `nixos-install` command to run.

**You (after I hand you the files):**
- [ ] Get the files onto `/mnt` (either `git clone` the repo if you've pushed it somewhere reachable from the installer, or just `nano` them in directly for this first pass).
- [ ] Run `nixos-install --flake .#thinkpad-t14s`, set your user password when prompted.
- [ ] Reboot, remove the USB stick.

---

## Phase 5 — First boot & verification

**You, checking off as you go:**
- [ ] `greetd`/`tuigreet` shows up and you can log in
- [ ] Sway launches, you can open a terminal (default keybind will be `$mod+Return`)
- [ ] Wi-Fi connects via `nmtui`/`nmcli`
- [ ] Firefox launches and loads a page
- [ ] `vim` opens with the expected settings
- [ ] Touchpad and brightness keys work
- [ ] Paste me anything that doesn't work — journalctl/sway errors, failed builds, whatever

**Me:**
- [ ] Debug whatever you paste back until Phase 5's checklist is all green.

---

## Phase 6 — Later refinements (not blocking "usable")

Once the above is solid, in whatever order you like:
- TPM2 auto-unlock for LUKS (`systemd-cryptenroll`)
- Re-enable and configure Secure Boot with Lanzaboote
- Migrate `vim` → `neovim` with a proper plugin manager
- Extract `home/vim.nix` (and maybe `sway.nix`) into your Mac's nix-darwin flake so it's genuinely one config feeding both machines
- Hibernation support
- Waybar theming, wofi/swaylock styling to taste

---

### Quick reference: what you'll paste back to me, and when
1. `lsblk` output — before I write the disko config
2. Generated `hardware-configuration.nix` — before I assemble the flake
3. Any install/build errors during `nixos-install`
4. Any first-boot errors from the Phase 5 checklist
