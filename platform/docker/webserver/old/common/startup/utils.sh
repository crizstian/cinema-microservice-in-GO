#!/bin/sh
set -e

get_log_level() {
    if [ -n $LOG_LEVEL ]; then
    	case $LOG_LEVEL in
    		"debug")
    		log_level="debug"
    		;;
    		"warn")
    		log_level="warn"
    		;;
    		"err")
    		log_level="err"
            ;;
            *)
            log_level="info"
            ;;
    	esac
    fi
    echo $log_level
}
