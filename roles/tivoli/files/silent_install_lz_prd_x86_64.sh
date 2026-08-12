#!/bin/bash
# Tivoli agent remote installation
# TASK0111321
ITMHOME=/opt/IBM/ITM
INSTALLHOME=/misc/software/IBM/TIVOLI/images/ITM63_07/agents
echo "Root is needed to install Tivoli"
test -x /bin/ksh && /bin/ksh ${INSTALLHOME}/install.sh -q -h ${ITMHOME} -p ${INSTALLHOME}/silent_install_lz_prd.txt
RC=$?
if [[ $? = "0" ]]; then
   echo "A zero return code was returned from ${INSTALLHOME}/install.sh script.  RC=$RC" 
   #Log installed product manifest
   test -f ${ITMHOME}/bin/cinfo && ${ITMHOME}/bin/cinfo -d |tee -a /tmp/install_sit.log
else
   echo "A nonzero return code was returned from install.sh script.  RC=$RC" |tee -a /tmp/install_sit.log
   exit $RC
fi
#Setting answer to y skips confirmation from user
answer=y
#echo "Proceed to configure agent lz? (y/n) DEFAULT = n"
#read answer
if [[ $answer = "y" ]]; then
   test -f ${ITMHOME}/bin/itmcmd && ${ITMHOME}/bin/itmcmd config -A -p ${INSTALLHOME}/silent_config_lz_prd.txt lz 
   sleep 10
   # Start the klzagent using the auto start script
   test -n /etc/init.d/ITMAgents1 && /etc/init.d/ITMAgents1 start
   # Create an install instance run log for this install
   ${ITMHOME}/bin/cinfo -r |tee -a $ITMHOME/logs/install_sit.log
fi

echo "`date` $INSTALLHOME/install_sit.sh" |tee -a /tmp/install_sit.log
