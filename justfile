all:
	just -l

# install systemd service(user scope)
install:
	mkdir -p ~/.config/systemd/user/
	cp kwallet_auto_unlock.service ~/.config/systemd/user/

# enable the user service for the next login
enable:
	systemctl --user daemon-reload
	systemctl --user reenable kwallet_auto_unlock.service
	systemctl --user reset-failed kwallet_auto_unlock.service

# install and enable service
setup: install enable
# use systemd-creds to generate password.cred
generate_password password="":
	@echo -n "{{ password }}" | systemd-creds encrypt --user - password.cred

run:
	python3 unlock.py

clean:
	rm -rf __pycache__
