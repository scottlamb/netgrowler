#!/bin/sh
# vim: noet

# Fake notifications for screenshot purposes.
# I like to make screenshots with white windows underneath so the translucent
# windows look right on my website with a white background. Faking the
# notifications makes it a little easier to do, since I can control the number
# and such.

growlnotify \
    --appIcon 'AirPort Admin Utility' \
    'AirPort connected' <<EOF
Joined network.
SSID:		Zorg
BSSID:	00:03:93:E8:DA:D1
EOF

growlnotify \
    --appIcon 'Internet Connect' \
    'IP address acquired' <<EOF
New primary IP.
Type:	Private
Address:	172.16.1.2
EOF
