#!/bin/sh /etc/rc.common
# OpenVPN init script

START=80
STOP=85

OPENVPN_BIN="/usr/sbin/openvpn"
OPENVPN_CONFIG="/etc/openvpn/client.ovpn"
OPENVPN_AUTH="/etc/openvpn/login.conf"
LOG_FILE="/tmp/openvpn"

SUBNET="100"

DEVICE1="192.168.${SUBNET}.130"
DEVICE2="192.168.${SUBNET}.129"
DEVICE3="192.168.${SUBNET}.134"
DEVICE4="192.168.${SUBNET}.131"
DEVICE5="192.168.${SUBNET}.132"
DEVICE6="192.168.${SUBNET}.133"
DEVICES="$DEVICE2 $DEVICE4 $DEVICE3 $ROSA_NEXUS_10 $ROSA_NEXUS_5 $DEVICE1"

VPN_DEV="tun0"

start() {
  logger -s "Starting OpenVPN" 2>> $LOG_FILE
  $OPENVPN_BIN --config $OPENVPN_CONFIG --auth-user-pass $OPENVPN_AUTH --log $LOG_FILE --daemon &
  # Now it's time to fix the routing.
  # When we start the VPN the server is going to push a default gw that
  # we are not interested into.

  # Wait for 60 seconds until the network is up.
  logger -s "Waiting for the VPN to be established" 2>> $LOG_FILE
  sleep 60

  # Extract the VPN default GW.
  VPN_GW=$(/usr/sbin/ip route | awk '/0.0.0.0/ { print $3 }')
  logger -s "VPN GW: $VPN_GW"  2>> $LOG_FILE

  # Remove the default routes pushed by the VPN server.
  ip route del 128.0.0.0/1
  if [ $? -ne 0 ];
  then
    logger -s "Problems removing route for 128.0.0.0/1" 2>> $LOG_FILE
  fi
  ip route del 0.0.0.0/1
  if [ $? -ne 0 ];
  then
    logger -s  "Problems removing route for 0.0.0.0/1" 2>> $LOG_FILE
  fi
  logger -s "Removed default GWs pushed by VPN server" 2>> $LOG_FILE

  # Now it's time to configure some interesting routing for the linux devices.
  for device in $DEVICES;
  do
    iptables -t mangle -A PREROUTING -p tcp --dport 80 -s $device -j MARK --set-mark 1
    iptables -t mangle -A PREROUTING -p tcp --dport 443 -s $device -j MARK --set-mark 1
  done

  ip rule add fwmark 1 table vpn                                                    
  ip route add default via $VPN_GW dev $VPN_DEV table vpn                           
                                                                                       
  ip route flush cache                                                                 
  logger -s "Routing preferences completed" 2>> $LOG_FILE                              
}                                                                                      
                                                                                       
stop() {                                                                               
  echo "Not Implemented"                                    
}
