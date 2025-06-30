#!/bin/bash
set -e -u

# Function to wait for unoserver to start
wait_for_unoserver() {
    echo "Waiting for unoserver to start on port 2003..."
    while ! netstat -tln | grep -q 2003; do
        sleep 1
    done
    echo "unoserver started."
}

export PS1='\u@\h:\w\$ '

# Build unoserver command dynamically based on environment variables
build_unoserver_command() {
    local cmd="unoserver"

    # Add interface parameter (always needed for non-interactive mode)
    if [ ! -t 0 ]; then
        cmd="$cmd --interface 0.0.0.0"
    fi

    # Add conversion-timeout if set
    if [ -n "${CONVERSION_TIMEOUT:-}" ]; then
        cmd="$cmd --conversion-timeout $CONVERSION_TIMEOUT"
    fi

    # Add stop-after if set
    if [ -n "${STOP_AFTER:-}" ]; then
        cmd="$cmd --stop-after $STOP_AFTER"
    fi

    echo "$cmd"
}

# Export the command for supervisord to use
export UNOSERVER_COMMAND=$(build_unoserver_command)

echo "using: $(libreoffice --version)"
echo "unoserver command: $UNOSERVER_COMMAND"

# if tty then assume that container is interactive
if [ ! -t 0 ]; then
    echo "Running unoserver-docker in non-interactive."
    echo "For interactive mode use '-it', e.g. 'docker run -v /tmp:/data -it unoserver/unoserver-docker'."

    # default parameters for supervisord
    export SUPERVISOR_NON_INTERACTIVE_CONF='/supervisor/conf/non-interactive/supervisord.conf'

    # run supervisord in foreground
    supervisord -c "$SUPERVISOR_NON_INTERACTIVE_CONF"
else
    echo "Running unoserver-docker in interactive mode."
    echo "For non-interactive mode omit '-it', e.g. 'docker run -p 2003:2003 unoserver/unoserver-docker'."

    # default parameters for supervisord
    export SUPERVISOR_INTERACTIVE_CONF='/supervisor/conf/interactive/supervisord.conf'
    export UNIX_HTTP_SERVER_PASSWORD=${UNIX_HTTP_SERVER_PASSWORD:-$(cat /proc/sys/kernel/random/uuid)}

    # run supervisord as detached
    supervisord -c "$SUPERVISOR_INTERACTIVE_CONF"

    # wait until unoserver started and listens on port 2002.
    wait_for_unoserver

    # if commands have been passed to container run them and exit, else start bash
    if [[ $# -gt 0 ]]; then
        eval "$@"
    else
        /bin/bash
    fi
fi
