#!/bin/sh
set -e

# echo Pre-start steps
echo "pre-steps start"

# WFS=/var/tmp/startup/wait-for-service
# #This can be over engineered to use a loop and eval, but it is okay
# if [ ! -z "$WAIT_FOR_SERVICE" ]; then
#     echo "Waiting for service [$WAIT_FOR_SERVICE]"
#     $WFS $WAIT_FOR_SERVICE
# fi
# if [ ! -z "$WAIT_FOR_SERVICE_1" ]; then
#     echo "Waiting for service [$WAIT_FOR_SERVICE_1]"
#     $WFS $WAIT_FOR_SERVICE_1
# fi
# if [ ! -z "$WAIT_FOR_SERVICE_2" ]; then
#     echo "Waiting for service [$WAIT_FOR_SERVICE_2]"
#     $WFS $WAIT_FOR_SERVICE_2
# fi
# if [ ! -z "$WAIT_FOR_SERVICE_3" ]; then
#     echo "Waiting for service [$WAIT_FOR_SERVICE_3]"
#     $WFS $WAIT_FOR_SERVICE_3
# fi


# if [ -f /var/tmp/startup/pre-start-app.sh ]
# then
#     echo "Executing pre-start-app.sh script"
#     chmod +x /var/tmp/startup/pre-start-app.sh
#     /var/tmp/startup/pre-start-app.sh
# fi

echo "pre-steps done"

exit 0
