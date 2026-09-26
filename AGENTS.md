# autokdewallet

A Python utility for automatically unlocking KDE Wallet (KWallet) using TPM-backed credentials via `systemd-creds`.

## Project Overview

The `autokdewallet` project aims to provide a seamless login experience for KDE users by automatically unlocking the default wallet (`kdewallet`) using a password securely stored in the system's TPM. It derives the PBKDF2-SHA512 hash and feeds it to `ksecretd --pam-login`, because D-Bus `pamOpen` was removed in KDE Frameworks 6.29.

### Key Technologies

- **Python 3**: Core logic for hash derivation and the `ksecretd` PAM handshake. No third-party libraries.
- **ksecretd**: Started as `ksecretd --pam-login <pipe-fd> <socket-fd>` with `PAM_KWALLET5_LOGIN` set. The 56-byte hash goes down the pipe; the session environment goes over `$XDG_RUNTIME_DIR/kwallet5.socket`.
- **systemd-creds**: Used to encrypt and decrypt the wallet password using the TPM.
- **Systemd User Services**: The unit is `Type=simple`, wanted by `graphical-session-pre.target`, and stays alive as `ksecretd`'s parent.

### Architecture

- **`unlock.py`**: The main entry point. It retrieves the password, loads the salt, derives the hash, starts `ksecretd`, and completes the PAM handshake. `just install` copies the runtime scripts to `~/.autokdewallet`; the user unit runs that copy, not the git checkout. On this machine the daemon is `/usr/bin/ksecretd` (kwallet 6.30). SDDM autologin means pam_kwallet does not launch the daemon.
- **`calculate_hash.py`**: Contains the logic to retrieve the password from `systemd-creds` and implement the PBKDF2-SHA512 hashing algorithm (50,000 iterations, 56-byte output) to match KWallet's internal requirements.
- **`get_salt.py`**: Utility to read the binary salt from `~/.local/share/kwalletd/kdewallet.salt`.
- **`justfile`**: A `just` task runner configuration for common operations like installation and credential generation.
- **`kwallet_auto_unlock.service`**: A systemd user service definition to run the script automatically upon login.

## Building and Running

The project uses `just` as a command runner.

### Initial Setup

1.  **Generate Credentials**:
    Encrypt your KWallet password using TPM:
    ```bash
    just generate_password password="your_actual_wallet_password"
    ```
    This creates `~/.autokdewallet/password.cred`.

2.  **Install Service**:
    Copy the systemd service to the user configuration and enable it:
    ```bash
    just install
    ```

### Manual Execution

To test the unlocker manually:
```bash
just run
```

### Cleanup

To remove Python bytecode caches:
```bash
just clean
```

## Development Conventions

- **Dependencies**: Requires `python3`. `dbus-python` is not used.
- **Security**: The `password.cred` file is encrypted for the current user/hardware. Avoid sharing this file.
- **KWallet Version**: Plasma 6 / kwallet >= 6.29 (`ksecretd`). This machine is kwallet 6.30.0 and Plasma 6.7.5.
- **Hash Parameters**: Iterations and key size are strictly defined to match KWallet's `kwalletbackend.h` (`PBKDF2_SHA512_ITERATIONS` 50000, `PBKDF2_SHA512_KEYSIZE` 56).
