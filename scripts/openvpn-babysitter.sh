#!/bin/bash
#
# Script that takes care of bringing up the VPN connection
# with Spain if it goes down.
##########################################################

OPENVPN_INTERFACE=tun0
OPENVPN_LOGS=/tmp/openvpn-es
OPENVPN_RUNNING_LOGS=/tmp/openvpn-running-logs
TMP_LOGS=/tmp/kaka-openvpn
# Threshold is 5000 KB.
STORAGE_THRESHOLD=5000
# We want to store the last 20000k lines of the health checks
# done by this script.
RUNNING_LOGS_THRESHOLD=20000

# Reviews the amout of storage used by the VPN logs as we do not have
# too much space. We just have ~10 MB available so we should ensure
# we just use < 50% of this storage.
review_log_storage() {         
  # Check the logs from the process.
  size=`du -k ${OPENVPN_LOGS} | awk '{ print $1 }'`
  if [ $size -gt $STORAGE_THRESHOLD ];
  then
    tail -n 100 $OPENVPN_LOGS > $TMP_LOGS
    mv $TMP_LOGS $OPENVPN_LOGS
  fi

  # Check the logs from this script.
  touch $OPENVPN_RUNNING_LOGS
  lines=`cat $OPENVPN_RUNNING_LOGS | wc -l`
  if [ $lines -gt $RUNNING_LOGS_THRESHOLD ];
  then
    tail -n $RUNNING_LOGS_THRESHOLD > $TMP_LOGS
    mv $TMP_LOGS $OPENVPN_RUNNING_LOGS
  fi
}

start_vpn() {
  echo `date`: starting OPENVPN-es
  /etc/init.d/openvpn-es start
  echo `date`: OPENVPN-es started
}

main() {
  # First of all check the logs, to avoid eating up much space.
  review_log_storage

  ifconfig $OPENVPN_INTERFACE > /dev/null
  if [ $? -eq 0 ];
  then
    echo `date`: VPN is alive >> $OPENVPN_RUNNING_LOGS
    exit 0;
  fi

  echo `date`: VPN is not alive >> $OPENVPN_RUNNING_LOGS
  processes_running=`ps | grep openvpn-es`
  if [ $processes_running -eq 1 ];
  then
    start_vpn
    exit 0
  fi
  echo The process is running, this is weird. >> $OPENVPN_RUNNING_LOGS
  openvpn_pid=`ps | grep openvpn | awk '{ print $1 }' | head -n 1`
  kill -KILL $openvpn_pid
  if [ $? -ne 1 ];
  then
    echo We failed to kill the openvpn process. >> $OPENVPN_RUNNING_LOGS
  fi
  start_vpn
}

main

