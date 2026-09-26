# AutoKDEWallet

**AutoKDEWallet** is a Python utility that automatically unlocks your KDE Wallet (KWallet) upon login using secure credentials stored in your system's TPM (Trusted Platform Module).

It eliminates the need to manually enter your wallet password every time you log in, while maintaining a high level of security by leveraging `systemd-creds` for hardware-bound encryption.

## How It Works

1.  **Secure Storage**: Your KWallet password is encrypted using `systemd-creds` and stored in a `password.cred` file. This file can only be decrypted by your specific user on your specific hardware (bound to the TPM).
2.  **Automatic Unlock**: A systemd user service starts `unlock.py` before Plasma (`graphical-session-pre.target`).
3.  **Hash Derivation**: The script reads the encrypted password, retrieves your wallet's salt, and calculates the PBKDF2-SHA512 hash KWallet expects (50,000 iterations, 56 bytes).
4.  **ksecretd handshake**: Since KDE Frameworks 6.29, `kwalletd` no longer exposes D-Bus `pamOpen`. The script starts `/usr/bin/ksecretd --pam-login`, writes the hash down the pipe, then sends the session environment over `kwallet5.socket`, which is what `pam_kwallet` does.

## Prerequisites

- **Linux with systemd** (v248 or newer recommended for `systemd-creds`).
- **KDE Plasma 6** with `ksecretd` (this machine: kwallet 6.30, Plasma 6.7).
- **TPM 2.0** enabled in your BIOS/UEFI.
- **Python 3** (stdlib only; `dbus-python` is not required).
- **Just** (Command runner, optional but recommended).

## Installation

### 1. Clone the Repository
```bash
git clone https://github.com/Himalian/autokdewallet.git
cd autokdewallet
```
use `just -l` to see all available commands.
```bash
> just -l
Available recipes:
    all
    clean
    enable                        # enable systemd service(user scope)
    generate_password password="" # use systemd-creds to generate password.cred
    install                       # install systemd service(user scope)
    run
    setup                         # install and enable service
```
### 2. Generate Encrypted Credentials
You need to encrypt your KWallet password use `systemd-creds`. Replace `YOUR_KWALLET_PASSWORD` with your real wallet password.

Using `just`:
```bash
just generate_password "YOUR_KWALLET_PASSWORD"
```

Or manually:
```bash
echo -n "YOUR_KWALLET_PASSWORD" | systemd-creds encrypt --user - password.cred
```

> **Note**: This creates a `password.cred` file, which is encrypted and bound to your TPM and user. It cannot be used on another machine.

### 3. Install the Service
The unit in this checkout is written for `/home/virtualguard/vg101/dev/autokdewallet`. It is installed to `~/.config/systemd/user/` and enabled for the next login. It is not started immediately, because starting it mid-session replaces the `ksecretd` Plasma already launched.

Using `just`:
```bash
just setup
```

Or manually:
```bash
mkdir -p ~/.config/systemd/user/
cp kwallet_auto_unlock.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user reenable kwallet_auto_unlock.service
```

## Usage

This machine uses SDDM autologin, so `pam_kwallet5.so` never receives a password and does not start `ksecretd`. The service is the unlock path. If you later switch to a password login, comment out the `pam_kwallet5.so` lines in `/etc/pam.d/sddm`, or PAM and this service will both try to own `kwallet5.socket`.

Once `password.cred` exists and the unit is enabled, the service runs at the next login. To unlock the wallet in the current session after creating the credential:

```bash
systemctl --user start kwallet_auto_unlock.service
```

### Manual Testing
You can run the unlock script manually to verify it works:

```bash
just run
# or
python3 unlock.py
```

### Cleaning Up
To remove Python cache files:
```bash
just clean
```

## Troubleshooting

If your wallet does not unlock automatically:

1.  **Check Service Status**:
    ```bash
    systemctl --user status kwallet_auto_unlock.service
    ```
2.  **Check Logs**:
    ```bash
    journalctl --user -u kwallet_auto_unlock.service
    ```
3.  **Verify TPM/Credentials**:
    Try decrypting the credential manually to ensure `systemd-creds` is working and the password is correct:
    ```bash
    systemd-creds decrypt --user password.cred -
    ```

## Files Structure

- **`unlock.py`**: Main script that orchestrates the unlocking.
- **`calculate_hash.py`**: Handles password decryption and KWallet-compatible hash generation.
- **`get_salt.py`**: Reads the KWallet salt from disk.
- **`kwallet_auto_unlock.service`**: Systemd service file.
- **`justfile`**: Command runner configuration.
