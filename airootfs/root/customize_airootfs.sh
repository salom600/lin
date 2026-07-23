#!/usr/bin/env bash
#
# /root/customize_airootfs.sh
#
# This script is run by mkarchiso AFTER the airootfs has been populated
# from packages.x86_64 but BEFORE the squashfs image is created.
# It is the central place where we turn a stock Arch system into Lin OS.
#
# All commands here run inside the airootfs chroot, so paths are relative
# to the new system's root (/).
#
set -euo pipefail

echo "==> [lin] customize_airootfs.sh starting"

# ============================================================================
# 1. Locale generation
# ============================================================================
echo "==> [lin] generating locales"
locale-gen

# ============================================================================
# 2. Default user
# ============================================================================
echo "==> [lin] creating default user 'lin'"
if ! id lin >/dev/null 2>&1; then
    useradd -m -G wheel,sys,audio,video,network,storage,optical,power,lp,rfkill -s /usr/bin/zsh lin
fi
echo "lin:lin" | chpasswd
echo "root:lin" | chpasswd

# Sudoers: wheel group can sudo without password (live ISO only — installed
# system overrides this in Calamares users module).
echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/10-lin-wheel
chmod 0440 /etc/sudoers.d/10-lin-wheel

# ============================================================================
# 3. Enable services
# ============================================================================
echo "==> [lin] enabling systemd services"
systemctl enable \
    NetworkManager.service \
    systemd-resolved.service \
    systemd-timesyncd.service \
    bluetooth.service \
    haveged.service \
    tlp.service \
    acpid.service \
    upower.service \
    systemd-boot-update.service \
    sddm.service \
    lin-firstboot.service \
    lin-welcome.service \
    2>/dev/null || true

# Disable services we don't want on the live ISO
systemctl disable \
    systemd-networkd-wait-online.service \
    wpa_supplicant.service \
    2>/dev/null || true

# Mask the slow ones entirely
systemctl mask \
    systemd-networkd-wait-online.service \
    lvm2-monitor.service \
    2>/dev/null || true

# ============================================================================
# 4. SDDM display manager configuration
# ============================================================================
echo "==> [lin] configuring SDDM"
mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/lin.conf <<'EOF'
[Autologin]
User=lin
Session=hyprland

[Theme]
ThemeDir=/usr/share/sddm/themes
Current=lin
CursorTheme=breeze_cursors

[Users]
MaximumUid=60513
MinimumUid=1000
EOF

# ============================================================================
# 5. NetworkManager: don't wait for internet during boot (faster boot)
# ============================================================================
mkdir -p /etc/NetworkManager/conf.d
cat > /etc/NetworkManager/conf.d/lin-fastboot.conf <<'EOF'
[device]
# Don't keep wifi scanning all the time at idle (saves CPU)
wifi.powersave = 3

[connection]
# Default DHCP timeout shorter than the 45s default
ipv4.dhcp-timeout = 15
ipv6.dhcp-timeout = 15
EOF

# ============================================================================
# 6. Reflector: keep mirrors fresh
# ============================================================================
mkdir -p /etc/xdg/reflector
cat > /etc/xdg/reflector/reflector.conf <<'EOF'
--save /etc/pacman.d/mirrorlist
--country us,gb,de,fr,nl,jp,sg
--protocol https
--latest 20
--sort rate
EOF

# ============================================================================
# 7. TLP power management (idle 0% CPU)
# ============================================================================
mkdir -p /etc/tlp.d
cat > /etc/tlp.d/10-lin.conf <<'EOF'
# Aggressive power saving for idle 0% CPU target
CPU_SCALING_GOVERNOR_ON_AC=powersave
CPU_SCALING_GOVERNOR_ON_BAT=powersave
CPU_MIN_PERF_ON_AC=0
CPU_MAX_PERF_ON_AC=100
CPU_MIN_PERF_ON_BAT=0
CPU_MAX_PERF_ON_BAT=80
CPU_BOOST_ON_AC=1
CPU_BOOST_ON_BAT=0
SCHED_POWERSAVE_ON_AC=1
SCHED_POWERSAVE_ON_BAT=1
NMI_WATCHDOG=off
DISK_DEVICES="nvme0n1 sda"
DISK_APM_LEVEL_ON_AC="254 254"
DISK_APM_LEVEL_ON_BAT="128 128"
SOUND_POWER_SAVE_ON_AC=1
SOUND_POWER_SAVE_ON_BAT=1
SOUND_POWER_SAVE_CONTROLLER=Y
PCIE_ASPM_ON_AC=powersave
PCIE_ASPM_ON_BAT=powersave
WIFI_PWR_ON_AC=on
WIFI_PWR_ON_BAT=on
EOF

# ============================================================================
# 8. Lin OS custom scripts
# ============================================================================
mkdir -p /etc/lin /usr/local/bin

# /etc/lin/firstboot.sh — runs on first boot of the INSTALLED system
cat > /etc/lin/firstboot.sh <<'EOF'
#!/usr/bin/env bash
# First-boot wizard for installed Lin OS. Runs once via systemd.
set -euo pipefail
exec > >(systemd-cat -t lin-firstboot) 2>&1
echo "firstboot starting"

# Refresh mirror list with the fastest mirrors
if command -v reflector >/dev/null; then
    reflector --country us,gb,de,fr,nl,jp,sg --protocol https --latest 20 --sort rate --save /etc/pacman.d/mirrorlist || true
fi

# Populate pacman keyring
pacman-key --init
pacman-key --populate archlinux

# Chaotic-AUR keyring
if pacman -Qs chaotic-keyring >/dev/null 2>&1; then
    pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
    pacman-key --lsign-key 3056513887B78AEB
    pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' || true
fi

# Disable this service so it doesn't run again
systemctl disable lin-firstboot.service
echo "firstboot done"
EOF
chmod 0755 /etc/lin/firstboot.sh

# /etc/lin/welcome.sh — launches the Hyprland welcome app
cat > /etc/lin/welcome.sh <<'EOF'
#!/usr/bin/env bash
# Launches the Lin OS welcome window on first graphical login.
exec /usr/local/bin/lin-welcome
EOF
chmod 0755 /etc/lin/welcome.sh

# /etc/lin/install-store.sh — (re)installs the app store if missing
cat > /etc/lin/install-store.sh <<'EOF'
#!/usr/bin/env bash
# Installs bauh + pamac-aur + flatpak if any are missing.
set -e
sudo pacman -Syu --noconfirm --needed bauh pamac-aur flatpak
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || true
echo "Lin OS app store ready."
EOF
chmod 0755 /etc/lin/install-store.sh

# ============================================================================
# 9. lin-welcome — first-run graphical welcome
# ============================================================================
cat > /usr/local/bin/lin-welcome <<'EOF'
#!/usr/bin/env bash
# Lin OS welcome window — runs in a kitty window on first Hyprland login.
set -e
LANG="${LANG:-en_US.UTF-8}"
export LANG

# Pause to let Hyprland settle
sleep 2

kitty --title "Welcome to Lin OS" --class lin-welcome bash -c '
echo -e "\e[36m╔══════════════════════════════════════════════╗\e[0m"
echo -e "\e[36m║        Welcome to Lin OS 2026.07             ║\e[0m"
echo -e "\e[36m║       \"aurora\" — Lightweight & sleek         ║\e[0m"
echo -e "\e[36m╚══════════════════════════════════════════════╝\e[0m"
echo
echo "Your system is ready. A few things you can do:"
echo
echo "  \e[1m1.\e[0m Open the app store:        click the \e[1mLin Store\e[0m icon on the dock"
echo "  \e[1m2.\e[0m Install more apps:         Settings → Software Sources → Flathub"
echo "  \e[1m3.\e[0m Take a screenshot:         PrintScreen"
echo "  \e[1m4.\e[0m Open app launcher:         Super (Windows) key"
echo "  \e[1m5.\e[0m Open terminal:             Super + Enter"
echo "  \e[1m6.\e[0m Close window:              Super + Q"
echo
echo "Press \e[1mEnter\e[0m to dismiss this window."
read -r
'
EOF
chmod 0755 /usr/local/bin/lin-welcome

# lin-store — launches the app store
cat > /usr/local/bin/lin-store <<'EOF'
#!/usr/bin/env bash
# Launches the Lin OS app store (bauh by default, pamac fallback).
if command -v bauh >/dev/null 2>&1; then
    exec bauh "$@"
elif command -v pamac-manager >/dev/null 2>&1; then
    exec pamac-manager "$@"
else
    notify-send -u critical "Lin OS" "App store not installed. Run: sudo /etc/lin/install-store.sh"
    exit 1
fi
EOF
chmod 0755 /usr/local/bin/lin-store

# lin-update — single command to update everything
cat > /usr/local/bin/lin-update <<'EOF'
#!/usr/bin/env bash
# Update pacman + AUR + flatpak in one go.
set -e
echo "==> Updating pacman packages..."
sudo pacman -Syu
if command -v flatpak >/dev/null 2>&1; then
    echo "==> Updating Flatpak apps..."
    flatpak update -y || true
fi
if command -v bauh >/dev/null 2>&1; then
    echo "==> Updating AUR + AppImage packages (bauh)..."
    bauh --update || true
fi
echo "==> Done."
EOF
chmod 0755 /usr/local/bin/lin-update

# ============================================================================
# 10. lin-firstboot.service — runs firstboot.sh on first boot of installed system
# ============================================================================
cat > /etc/systemd/system/lin-firstboot.service <<'EOF'
[Unit]
Description=Lin OS first-boot wizard
DefaultDependencies=no
After=local-fs.target pacman-init.service
Before=multi-user.target sddm.service
ConditionPathExists=!/var/lib/lin/.firstboot-done

[Service]
Type=oneshot
ExecStart=/etc/lin/firstboot.sh
ExecStartPost=/usr/bin/touch /var/lib/lin/.firstboot-done
RemainAfterExit=yes
StandardOutput=journal+console
StandardError=journal+console

[Install]
WantedBy=multi-user.target
EOF
mkdir -p /var/lib/lin

# lin-welcome.service — launches welcome app on first graphical login
cat > /etc/systemd/system/lin-welcome.service <<'EOF'
[Unit]
Description=Lin OS graphical welcome (one-shot)
After=sddm.service graphical-session.target
ConditionPathExists=!/var/lib/lin/.welcome-shown

[Service]
Type=oneshot
User=lin
Environment=DISPLAY=:0 WAYLAND_DISPLAY=wayland-1 XDG_RUNTIME_DIR=/run/user/1000
ExecStartPre=/usr/bin/sleep 10
ExecStart=/etc/lin/welcome.sh
ExecStartPost=/usr/bin/touch /var/lib/lin/.welcome-shown
RemainAfterExit=no

[Install]
WantedBy=graphical.target
EOF

# ============================================================================
# 11. Polkit rule: let the wheel group do administrative things without
#     interrupting with a password prompt every time (live ISO convenience)
# ============================================================================
cat > /etc/polkit-1/rules.d/10-lin-wheel.rules <<'EOF'
// Allow wheel group to do common admin tasks without password (live ISO)
polkit.addRule(function(action, subject) {
    if (subject.isInGroup("wheel")) {
        return polkit.Result.YES;
    }
});
EOF

# ============================================================================
# 12. XDG user directories
# ============================================================================
sudo -u lin xdg-user-dirs-update 2>/dev/null || true
mkdir -p /home/lin/{Desktop,Downloads,Documents,Music,Pictures,Videos,Public,Templates}
chown -R lin:lin /home/lin

# ============================================================================
# 13. Default shell for root
# ============================================================================
chsh -s /usr/bin/zsh root 2>/dev/null || true

# ============================================================================
# 14. Plymouth-free quiet boot (no splash, just clean kernel messages)
# ============================================================================
mkdir -p /etc/kernel
cat > /etc/kernel/cmdline <<'EOF'
quiet rw loglevel=3 systemd.show_status=false console=tty2
EOF

# ============================================================================
# 15. .zshrc for the live user — friendly prompt
# ============================================================================
cat > /home/lin/.zshrc <<'EOF'
# Lin OS default zshrc
autoload -Uz colors && colors
PS1='%F{cyan}lin%f@%F{blue}%m%f %F{yellow}%~%f %# '

# Aliases
alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias update='sudo pacman -Syu'
alias store='lin-store'
alias welcome='lin-welcome'

# History
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY HIST_IGNORE_DUPS HIST_IGNORE_SPACE

# Color on common commands
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias diff='diff --color=auto'
EOF
chown lin:lin /home/lin/.zshrc

# ============================================================================
# 16. Cleanup — remove stuff we don't need on the live ISO to save space
# ============================================================================
echo "==> [lin] cleaning up"
find /var/cache/pacman/pkg -type f -delete 2>/dev/null || true
rm -rf /var/cache/man 2>/dev/null || true
journalctl --vacuum-size=1K 2>/dev/null || true
rm -rf /var/log/journal/* 2>/dev/null || true
rm -rf /tmp/* 2>/dev/null || true

echo "==> [lin] customize_airootfs.sh done"
