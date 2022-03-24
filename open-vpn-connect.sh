#!/bin/bash

#
# open-vpn-connect.sh (ucivpnup.sh)
#
# From: http://www.socsci.uci.edu/~jstern/uci_vpn_ubuntu/ubuntu-openconnect-uci-instructions.html
#

# Edit the following down to the <<<END-EDIT>>> lines

#
# EXECUTABLE LOCATIONS
#
OPENVPN_EXE='/usr/sbin/openvpn'
OPENCONNECT_EXE='/usr/sbin/openconnect'
IP_EXE='/bin/ip'
if [[ ! -f "${OPENVPN_EXE}" ]]; then
	echo "ERROR: ${OPENVPN_EXE} does not exist on your system. Please install."
	exit 1
fi
if [[ ! -f "${OPENCONNECT_EXE}" ]]; then
	echo "ERROR: ${OPENCONNECT_EXE} does not exist on your system. Please install."
	exit 1
fi
if [[ ! -f "${IP_EXE}" ]]; then
	echo "ERROR: ${IP_EXE} does not exist on your system. Please install."
	exit 1
fi

#
# Where you will be connecting to for your VPN services
#
# It can be is the VPN server ip address and port.
#
# e.g.:
# VPN_HOST="171.110.129.81:10443"
#
# Also, it can be is a server URL too.
#
# e.g.:
# VPN_HOST="https://vpn.uci.edu"
#
# (required)
VPN_HOST="<IP_And_Port or Server_URL>"

#
# Your VPN server's username.
#
# At UCI, we use your UCINetID (all lower-case) for this.
#
# (required)
VPN_USER="<Your_Username>"

#
# Your VPN server's password.
#
# At UCI we use our UCINetID password.  Storing it
# in plain text here in this file is insecure, though. It is better to
# put your password into a $HOME/.authinfo file and use a 2nd script
# to read that password and echo it.  If I find the time, I will add
# that functionality to this script and the instructions. At least
# this will suffice for now, 'just to get things going'.
#
# On the other hand, if you leave VPN_PASSWD blank, or empty string, the
# script will prompt you for it.
#
# e.g.:
# VPN_PASSWD=""
#
# (optional)
VPN_PASSWD="<Your_Password>"

#
# VPN_GROUP
# At UCI, setting this will determine what permissions you have
# to access stuff, and for which sites your computer will use
# its VPN connection, and for which sites it will not.
#
# The possible values for VPN_GROUP at UCI are:
#   "Default-WebVPN"
#   "Merage"
#   "MerageFull"
#   "UCI"     <--- this will use the VPN address only for connections
#                  to UCI. all other connections will use your outside
#                  address. Normally this is all most users need.
#   "UCIFull" <--- this will use the VPN address for all connections.
#                  If you are going to be using UC-related sources
#                  that are off-campus, such as system-wide Melvyl
#                  library (melvyl.ucop.edu), then use this.
#
#VPN_GROUP="UCI"
#
# If you have no a VPN group, you can leave VPN_GROUP blank.
# (required)
VPN_GROUP=""

#
# where you want any output of status / errors to go
# (this should match same var in the ucivpndown script)
# (required)
OC_LOG="/tmp/OC_LOG.txt"

#
# VPN_SCRIPT:
#
# These are just guesses. If neither of these work on your
# system, you'll need to find where this is.
#
# (required)
#
if [[ -f "/usr/share/vpnc-scripts/vpnc-script" ]]; then
	VPN_SCRIPT="/usr/share/vpnc-scripts/vpnc-script"
elif [[ -f "/etc/openconnect/vpnc-script" ]]; then
	VPN_SCRIPT='/etc/openconnect/vpnc-script'
else
	echo "ERROR: I cannot find a 'vpnc-script' on your system. Please install via your distro's particular package manager."
	exit 1
fi	

# --<<<END-EDIT>>>--------------------------------------------------------
# (You should not have to change or edit anything below here)
# --<<<END-EDIT>>>--------------------------------------------------------

# become root if not already
if [ $EUID != 0 ]; then
	sudo "$0"
	exit $?
fi

# timestamp
echo "`date`: Script ${0} starting." >> "${OC_LOG}" 2>&1

#
# First job: make a copy of /etc/resolv.conf since this file gets
# replaced by vpnc-script and needs to be restored by ucivpndown
# when vpn is shut back down
#
cp /etc/resolv.conf /tmp/resolv.conf.tmp

#
# Make an openvpn tunnel (interface), and if successful, use it to
# connect to our Cisco server. Script will hold with connection
# running until you hit Ctrl-C from the keyboard.
#
numtuns=`${IP_EXE} link show tun1 2> /dev/null | wc -l`
if [ "${numtuns}" -eq 0 ]; then
	echo "`date`: Creating tun1 openvpn interface." >> "${OC_LOG}" 2>&1
	${OPENVPN_EXE} --mktun --dev tun1 >> "${OC_LOG}" 2>&1
	# check successful, else quit
	if [ $? -eq 0 ]; then
		echo "`date`: tun1 openvpn interface created successfully." >> "${OC_LOG}" 2>&1
		# we only want to copy over the temporary conf file if we were successful in
		# connecting.  (If we copied over when we were *not* successful, we would end up
		# (in the open-vpn-disconnect.sh script) copying the wrong resolv.conf back to /etc/!)
		cp /tmp/resolv.conf.tmp /tmp/resolv.conf
	else
		echo "`date`: Problems creating tun1 openvpn interface. Exiting 1." >> "${OC_LOG}" 2>&1
		exit 1
	fi
else
	echo "`date`: tun1 openvpn interface already exists. Exiting." >> "${OC_LOG}" 2>&1
	exit 0
fi

#
# Turn on tun1 openvpn interface. If it is already on, it won't hurt
# anything.
#
echo "`date`: Turning tun1 on." >> "${OC_LOG}" 2>&1
ifconfig tun1 up >> "${OC_LOG}" 2>&1
#${IP_EXE} link set tun1 up "${OC_LOG}" 2>&1
# check successful, else quit
if [ $? -eq 0 ]; then
	echo "`date`: tun1 on." >> "${OC_LOG}" 2>&1
else
	echo "`date`: Problems turning tun1 on. (This may leave tun1 existing though.) Exiting 1." >> "${OC_LOG}" 2>&1
	exit 1
fi

#
# Check for any pre-existing openconnect connections. If one exists
# already, we will not create a new one.
#
pidofoc=`pidof openconnect`
echo "`date`: Running openconnect." >> "${OC_LOG}" 2>&1
if [ "$pidofoc" == "" ]; then
	if [ -z "$VPN_GROUP" ]; then
		if [ -z "$VPN_PASSWD" ]; then
			${OPENCONNECT_EXE} -b -s "${VPN_SCRIPT}" \
								--protocol="${PROTOCOL}" \
								--user="${VPN_USER}" \
								--interface="tun1" \
								"${VPN_HOST}" >> "${OC_LOG}" 2>&1
		else
			echo "${VPN_PASSWD}" | ${OPENCONNECT_EXE} -b -s "${VPN_SCRIPT}" \
								--protocol="${PROTOCOL}" \
								--user="${VPN_USER}" \
								--passwd-on-stdin \
								--interface="tun1" \
								"${VPN_HOST}" >> "${OC_LOG}" 2>&1
		fi
	else
		if [ -z "$VPN_PASSWD" ]; then
			${OPENCONNECT_EXE} -b -s "${VPN_SCRIPT}" \
								--protocol="${PROTOCOL}" \
								--user="${VPN_USER}" \
								--authgroup="${VPN_GROUP}" \
								--interface="tun1" \
								"${VPN_HOST}" >> "${OC_LOG}" 2>&1
		else
			echo "${VPN_PASSWD}" | ${OPENCONNECT_EXE} -b -s "${VPN_SCRIPT}" \
								--protocol="${PROTOCOL}" \
								--user="${VPN_USER}" \
								--passwd-on-stdin \
								--authgroup="${VPN_GROUP}" \
								--interface="tun1" \
								"${VPN_HOST}" >> "${OC_LOG}" 2>&1
		fi
	fi
else
	echo "`date`: Not initiating an openconnect session because one appears to already exist: PID=${pidofoc}" >> "${OC_LOG}" 2>&1
fi

# Give a chance for stuff to click into place..
sleep 3

# If you want, you can optionally show the new IP info to the user
# ip address show tun1

# And log same info
ip address show tun1 &>> "${OC_LOG}"

# End script
echo "`date`: ${0} script ending successfully." >> "${OC_LOG}" 2>&1
