#!/bin/bash

#
# open-vpn-disconnect.sh (ucivpndown.sh)
#
# From: http://www.socsci.uci.edu/~jstern/uci_vpn_ubuntu/ubuntu-openconnect-uci-instructions.html
#

#
# Where you want any output of status / errors to go
# (this should match same var in the open-vpn-connect.sh script)
# (required)
OC_LOG="/tmp/OC_LOG.txt"

OPENVPN_EXE='/usr/sbin/openvpn'
if [[ ! -f "${OPENVPN_EXE}" ]]; then
	echo "ERROR: ${OPENVPN_EXE} does not exist on your system. Please install."
	exit 1
fi

# ----------------------------------------------------------
# You should not have to change or edit anything below here
# ----------------------------------------------------------

# become root if not already
if [ $EUID != 0 ]; then
	sudo "$0"
	exit $?
fi

echo "`date`: Script ${0} starting." >> "${OC_LOG}" 2>&1

#
# Shut down openconnect process if one (or more) exists
#
# Find the pid(s) of any openconnect process(es)
pidofoc=`pidof openconnect`
# Use those pids to kill them
if [ "$pidofoc" != "" ]; then
	echo "`date`: Stopping openconnect PID ${pidofoc}." >> "${OC_LOG}" 2>&1
	kill -9 ${pidofoc} >> "${OC_LOG}" 2>&1
else
	echo "`date`: No openconnect found. (That's okay.) Continuing." >> "${OC_LOG}" 2>&1
fi

# Close down the tun1 openvpn tunnel
${OPENVPN_EXE} --rmtun --dev tun1 &>> "${OC_LOG}"

# Finally, restore the /tmp/resolv.conf
if [[ -f /tmp/resolv.conf ]]; then
	cp /tmp/resolv.conf /etc
fi

echo "`date`: ${0} script ending successfully." >> "${OC_LOG}" 2>&1
