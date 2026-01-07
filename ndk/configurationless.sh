#!/bin/bash

_term (){
    echo "Caugth signal SIGTERM !! "
    kill -TERM "$child" 2>/dev/null
}

function main() {

    # Associate a handler with signal SIGTERM
    trap _term SIGTERM

    ### Configure DNS servers
    sr_cli --candidate-mode  "system dns server-list [ 8.8.8.8 ] network-instance mgmt"
    ### Config ACL R23 or R24+
    sr_cli --candidate-mode acl cpm-filter ipv4-filter entry 1 match protocol tcp
    sr_cli --candidate-mode  acl cpm-filter ipv4-filter entry 1 action accept 
    #sr_cli --candidate-mode  acl acl-filter cpm type ipv4 entry 1 match ipv4 protocol tcp
    #sr_cli --candidate-mode acl acl-filter cpm type ipv4 entry 1 action accept 

    # Execute configs - Pause to avoid conflict with CLAB commits
    echo "Initializing agent venv" && sleep 10
    ### R23 gnmi
    sr_cli --candidate-mode  system gnmi-server admin-state enable
    sr_cli --candidate-mode --commit-at-end system gnmi-server network-instance mgmt delete tls-profile
    # R24 ACTIVATE THE GNMI SERVER -     ### Remove TLS profile to allow gnmic insecure
    #sr_cli --candidate-mode system grpc-server gnmi-server admin-state enable
    #sr_cli --candidate-mode system grpc-server gnmi-server unix-socket admin-state enable
    #sr_cli --candidate-mode --commit-at-end system grpc-server mgmt delete tls-profile

    # Set local variables
    #local virtual_env="/opt/srlinux/python/virtual-env/bin/activate"   ### default SRLinux venv
    local virtual_env="/etc/opt/srlinux/appmgr/venv-dev/bin/activate"   ### new App venv
    local main_module="/etc/opt/srlinux/appmgr/dcf-ztp/configurationless.py"

    # source the virtual-environment, which is used to ensure the correct python packages are installed,
    # and the correct python version is used
    # activate virtual env
    if [ -f "$virtual_env" ]; then
        echo "Using existing venv: $virtual_env"
        source "$virtual_env"
    else
        #echo "[WARN] Virtualenv not found in $virtual_env — running on default system python environment" => Error: externally-managed-environment
        echo "Create and activate new venv"
        sudo python3 -m venv /etc/opt/srlinux/appmgr/venv-dev
        source "$virtual_env"
    fi
    
    echo "Install pip at: $virtual_env"

    # install required tools
    #export PIP_CACHE_DIR=/etc/opt/srlinux/appmgr/cache/pip
    export PIP_CACHE_DIR=/etc/opt/srlinux/appmgr/venv-dev/.pip-cache
    ip netns exec srbase-mgmt pip3 install -U pip setuptools
    ip netns exec srbase-mgmt pip3 install srlinux-ndk==0.4.0   ### srlinux-ndk==0.5.0 changed many things
    ip netns exec srbase-mgmt pip3 install pygnmi
    ip netns exec srbase-mgmt pip3 install 'protobuf>3.20'
    ip netns exec srbase-mgmt pip3 install numpy

    # update PYTHONPATH variable with the agent directories and ndk bindings
    #export PYTHONPATH="$PYTHONPATH:/etc/opt/srlinux/appmgr/dcf-ztp:/usr/lib/python3.11/dist-packages/sdk_protos/:/usr/lib/python3.6/site-packages/sdk_protos:/etc/opt/srlinux/appmgr/venv-dev/lib/python3.6/site-packages"
    export PYTHONPATH="$PYTHONPATH:/etc/opt/srlinux/appmgr/dcf-ztp:/opt/srlinux/bin:/etc/opt/srlinux/appmgr/venv-dev/lib/python3.6/site-packages:/etc/opt/srlinux/appmgr/venv-dev/lib/python3.11/site-packages"
    #export PYTHONPATH="$PYTHONPATH:/etc/opt/srlinux/appmgr/user_agents:/opt/srlinux/bin:/etc/opt/srlinux/appmgr/venv-dev/lib/python3.6/site-packages"

    # Initializing agent Python 
    echo "Initializing agent" && sleep 30

	# start the agent in the background (as a child process)
    #python ${main_module} &
    python3 ${main_module} &

	# save its process id
    child=$! 

	# wait for the child process to finish
    wait "$child"

}

main "$@"
