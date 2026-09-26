all:
	just -l

# install runtime files into ~/.autokdewallet and the user unit
install:
	#!/usr/bin/env bash
	set -euo pipefail
	dest="${HOME}/.autokdewallet"
	mkdir -p "$dest"
	chmod 700 "$dest"
	cp unlock.py calculate_hash.py get_salt.py "$dest/"
	echo "Placed runtime scripts in $dest"
	if [[ -f password.cred ]]; then
		if [[ -e "$dest/password.cred" ]]; then
			echo "Kept existing $dest/password.cred" >&2
			echo "Remove ./password.cred or the installed file before replacing it." >&2
			exit 1
		fi
		mv password.cred "$dest/password.cred"
		chmod 600 "$dest/password.cred"
		echo "Moved password.cred to $dest/password.cred"
	fi
	mkdir -p "${HOME}/.config/systemd/user"
	cp kwallet_auto_unlock.service "${HOME}/.config/systemd/user/kwallet_auto_unlock.service"
	echo "Installed unit: ${HOME}/.config/systemd/user/kwallet_auto_unlock.service"
	if [[ ! -f "$dest/password.cred" ]]; then
		echo "Next: just generate_password 'YOUR_KWALLET_PASSWORD'"
		echo "Then: just enable"
	else
		echo "Next: just enable"
	fi

# enable the user service for the next login
enable:
	systemctl --user daemon-reload
	systemctl --user reenable kwallet_auto_unlock.service
	systemctl --user reset-failed kwallet_auto_unlock.service

# install runtime files and enable the user service
setup: install enable

# encrypt the wallet password into ~/.autokdewallet/password.cred
generate_password password="":
	#!/usr/bin/env bash
	set -euo pipefail
	password={{quote(password)}}
	if [[ -z "$password" ]]; then
		echo "Usage: just generate_password 'YOUR_KWALLET_PASSWORD'" >&2
		exit 1
	fi
	dest="${HOME}/.autokdewallet"
	mkdir -p "$dest"
	chmod 700 "$dest"
	printf '%s' "$password" | systemd-creds encrypt --user - "$dest/password.cred"
	chmod 600 "$dest/password.cred"
	echo "Wrote $dest/password.cred"

# run the unlocker installed in ~/.autokdewallet
run:
	#!/usr/bin/env bash
	set -euo pipefail
	script="${HOME}/.autokdewallet/unlock.py"
	if [[ ! -f "$script" ]]; then
		echo "Runtime is not installed. Run: just install" >&2
		exit 1
	fi
	exec python3 "$script"

clean:
	rm -rf __pycache__ ~/.autokdewallet/__pycache__
