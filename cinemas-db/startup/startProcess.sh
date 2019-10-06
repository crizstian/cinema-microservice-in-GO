#!/bin/bash
set -e

echo "Proceeding with startup..."
echo "IS_PRIMARY = " $IS_PRIMARY

if [ $IS_PRIMARY == "true" ]; then
  export ip4_add=`hostname -i`

  consul-template -template "/data/admin/admin.js.ctmpl:/data/admin/admin.js" -once
  consul-template -template "/data/admin/grantRole.js.ctmpl:/data/admin/grantRole.js" -once
  consul-template -template "/data/admin/replica.js.ctmpl:/data/admin/replica.js" -once

  /var/tmp/start/startWithConfig.sh & 
  /var/tmp/start/initMongo.sh &
  wait
else 
  /var/tmp/start/startWithConfig.sh
fi
