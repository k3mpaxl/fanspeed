#!/bin/bash

# Copyright (C) 2017  Gregor Bonney
#
# Version 2.0
#
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 3
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

LOGFILE=/var/log/fanspeed.log
ECFILE=/etc/fanspeed/probook_ec.pl
COUNTER=0

######################################################

initFan()
{
  setFan 80
#  sleep 2
  $ECFILE FANOFF
}

setFan()
{
  SPEED=$1
  $ECFILE := 0x2F $SPEED
}

getTempAvg()
{
  CUR=0
  CPUTEMP=0

  while [ $CUR -lt $INTERVAL ]
  do
    #TMP=$(sensors | grep Physical | cut -b 18-19)
    TMP=$(cat /sys/class/hwmon/hwmon*/device/temp1_input | cut -b1-2)
    #TMP=$(sensors | grep "Physical" | awk '{print $4}' | tr -d '+°C' | cut -b 1-2)
    ((CPUTEMP=$CPUTEMP+$TMP))
    ((CUR=$CUR+1))
    sleep 1
  done
  ((CPUTEMP=$CPUTEMP/$INTERVAL))
}

detectNewSpeed()
{
  ((COUNTER=$COUNTER+$INTERVAL))

  if [ $CPUTEMP -le $TEMPFANSTARTSPEED ]
  then
    # CPU COOLED DOWN
     ((INTERVAL=$STEPS))
    if [ $LASTSPEED -gt 75 ]
    then
      if [ $COUNTER -gt $THROTTLEOFF ]
      then
        # STOP FAN AFTER CPU COOLED DOWN
        NEWSPEEDF=FF
      fi
    elif [ "$NEWSPEEDF" == "FF" ]
    then
      NEWSPEEDF=FF
    else
      ((NEWSPEEDF=$NEWSPEEDF+$INTERVAL))
    fi
  elif [ $CPUTEMP -gt $TEMPFANMAXSPEED ]
  then
    # CPU VERY HOT!!!
    NEWSPEEDF=0
    resetCounter
    ((INTERVAL=10))
  else
    # CPU TEMP IS BETWEEN START AND MAX SPEED
    if [ $CPUTEMP -le $LASTTEMP ]
    then
      if [ $COUNTER -gt $THROTTLESEC ]
      then
        #calculate fanspeed after $THROTTLESEC seconds
        calculateFanSpeed
        resetCounter
      fi
    else
      # CPU TEMP RAISED -> CALCULATE AGILITY
      calculateFanSpeed
      calculateNextInterval
      resetCounter
    fi
  fi

  echo $TEMPFANSTARTSPEED:$CPUTEMP:$TEMPFANMAXSPEED:$NEWSPEEDF:$NEXTINT:$INTERVAL:$THROTTLESEC:$COUNTER
  #printf "TMIN:%d TCUR:%d TMAX:%d FSPEED:%s SLEEP:%d CNT:%d\n" $TEMPFANSTARTSPEED $CPUTEMP $TEMPFANMAXSPEED $NEWSPEEDF $INTERVAL $COUNTER

  if [ "$LASTSPEED" != "$NEWSPEEDF" ]
  then
    setFan $NEWSPEEDF
  fi

  ((LASTTEMP=$CPUTEMP))
  ((LASTSPEED=$NEWSPEEDF))
}

calculateFanSpeed() {
  ((LASTSPEED=$NEWSPEEDF))
  ((NEWSPEEDF=($CPUTEMP-$TEMPFANMAXSPEED)*($CPUTEMP+$TEMPFANMAXSPEED)))
  ((NEWSPEEDF=$NEWSPEEDF*-24/1000))
  #if [ "$LASTSPEED" != "FF" ]; then
  #  ((TST=$LASTSPEED+$INTERVAL))
  #  if [ $TST -le $NEWSPEEDF ]
  #  then
  #    ((NEWSPEEDF=$LASTSPEED+$INTERVAL))
  #  fi
  #fi
}

resetCounter() {
  ((COUNTER=0))
}

calculateNextInterval() {
  #calculate next interval
  NEXTINT=0
  for i in `seq 0 $STEPS`;
  do
    if [ $NEXTINT -le $CPUTEMP ]
      then
      ((NEXTINT=($TEMPFANSTARTSPEED+(($TEMPFANMAXSPEED-$TEMPFANSTARTSPEED)*$i/$STEPS))))
      ((INTERVAL=1+$STEPS-$i))
    fi
  done
}

##################################################


sleep 10

initFan

#use the average temperature of $INTERVAL seconds
INTERVAL=5
#throttle down after $THROTTLESEC seconds
THROTTLESEC=30
#set fan off after on lowest setting for $THROTTLEOFF seconds
THROTTLEOFF=80
#temperatures in celsius
TEMPFANSTARTSPEED=52 #56
TEMPFANMAXSPEED=80

STEPS=8


NEWSPEEDF=74
LASTTEMP=55
LASTSPEED=75

while [ true ]
do
  getTempAvg
  detectNewSpeed
done
