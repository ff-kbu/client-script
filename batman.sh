#!/bin/sh

WIRELESS_INTERFACE=wlan0

# These values are batman specific.
# Do not change these unless you know what you are doing.
BATMAN_INTERFACE=bat0
BATMAN_MTU=1473

# kbu.freifunk.net specific values
# Do not change these unless you know what you are doing.
KBU_ESSID="mesh.freifunk.net"
KBU_FREQ=2412 # Unit: Mhz. This value is channel 1.
KBU_BSSID="12:22:b0:44:94:5d"

warn() {
	echo "$*" 1>&2
}

die() {
	echo "$*" 1>&2
	exit 1
}

case "$1" in
	start)
		echo -n "Configuring batman for kbu.freifunk.net..."
		# Load kernel module.
		modprobe batman-adv ||
			die "failed to load batman-adv kernel module"
		# Set ibss (ad-hoc) mode on the wireless interface.
		iw dev "$WIRELESS_INTERFACE" set type ibss ||
			die "failed to set mode ad-hoc"
		# Up the interface.
		ip link set dev "$WIRELESS_INTERFACE" up ||
			die "failed to up wireless interface"
		# Join the ad-hoc network. Needs an upped interface.
		# Note that the channel an the bssid must be set in order
		# for the join to work.
		iw dev "$WIRELESS_INTERFACE" ibss join "$KBU_ESSID" \
			"$KBU_FREQ" fixed-freq "$KBU_BSSID" ||
			die "failed to join the mesh network"
		# Now start batman-adv on the wireless interface.
		batctl interface add "$WIRELESS_INTERFACE" ||
			die "failed to batctl add wireless interface"
		# Reduce MTU on the batman interface to make some space for
		# the batman-adv header to packets.
		ip link set dev "$BATMAN_INTERFACE" mtu "$BATMAN_MTU" ||
			die "failed to shrink mtu on batman interface"
		# Attempt to get an ip address via dhcp.
		dhclient "$BATMAN_INTERFACE" ||
			die "dhclient failed"
	;;
	stop)
		# TODO: test dhclient stopping
		dhclient -r "$BATMAN_INTERFACE" ||
			warn "failed to terminate dhclient"
		batctl interface del "$WIRELESS_INTERFACE" ||
			warn "failed to batctl del wireless interface"
		iw dev "$WIRELESS_INTERFACE" ibss leave ||
			 warn "failed to leave the mesh network"
		ip link set dev "$WIRELESS_INTERFACE" down ||
			warn "failed to down wireless interface"
		iw dev "$WIRELESS_INTERFACE" set type managed ||
			 warn "failed to set mode managed"
	;;
esac
