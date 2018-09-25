#!/bin/bash

readonly PROGNAME=$(basename $0)
readonly PROGDIR=$(readlink -m $(dirname $0))
readonly ARGS="$@"

set -o errexit

usage() {
	cat <<- EOF
  usage: $PROGNAME options
  
  This script is used to deploy an openshift cluster to AWS. 
  

  OPTIONS:
     -d --deploy          Deploy an Openshift instance to AWS
     -s --setup-only      Only run setup on the hosts.
     -r --pre-req-only    Only run the openshift pre-reqs
     -c --cluster-only    Only run the cluster deployment
     -o --openshift-only  Only run the openshift configure playbook
     -f --fetch-config    Fetches the .kube config so you can connect to the openshift cluster as system:admin after setup
     -e --enable-recycler Enables the openshift recycler pods
     -h --help            Display this help
  
  Examples:
     Run deployment:
     $PROGNAME --deploy

	EOF
}

cmdline() {
    # got this idea from here:
    # http://kirk.webfinish.com/2009/10/bash-shell-script-to-use-getopts-with-gnu-style-long-positional-parameters/
    local arg=
    for arg
    do
        local delim=""
        case "$arg" in
            #translate --gnu-long-options to -g (short options)
            --deploy)           args="${args}-d ";;
            --setup-only)       args="${args}-s ";;
            --pre-req-only)     args="${args}-r ";;
            --cluster-only)     args="${args}-c ";;
            --openshift-only)   args="${args}-o ";;
            --fetch-config)     args="${args}-f ";;
            --enable-recycler)  args="${args}-e ";;
            --help)             args="${args}-h ";;
            #pass through anything else
            *) [[ "${arg:0:1}" == "-" ]] || delim="\""
                args="${args}${delim}${arg}${delim} ";;
        esac
    done

    #Reset the positional parameters to the short options
    eval set -- $args

    while getopts "dsrchofe" OPTION
    do
         case $OPTION in
         d)
             readonly DEPLOY=true
             ;;
         s)
             readonly SETUP=true
             ;;
         r)
             readonly PREREQ=true
             ;;
         c)
             readonly CLUSTER=true
             ;;
         o)
             readonly OPENSHIFT=true
             ;;
         f)
             readonly FETCH=true
             ;;
         e)
             readonly RECYCLER=true
             ;;
         h)
             usage
             exit 0
             ;;
        esac
    done

    return 0
}

setup(){
  ansible-playbook playbooks/setup/setup.yml
}

pre-req(){
  ansible-playbook /usr/share/ansible/openshift-ansible/playbooks/prerequisites.yml
}

deploy_cluster(){
  ansible-playbook /usr/share/ansible/openshift-ansible/playbooks/deploy_cluster.yml
}

configure_openshift(){
  ansible-playbook playbooks/configure/configure.yml
}

fetch_config(){
  ansible masters[0] -m fetch -a'src=/root/.kube/config dest=~/.kube/config flat=yes'
}

enable_recycler(){
  ansible-playbook playbooks/configure/enable_recycler.yml
}

main(){

  cmdline $ARGS

  if [[ $DEPLOY ]]; then 
    setup
    pre-req
    deploy_cluster
    fetch_config
    enable_recycler
    configure_openshift
  elif [[ $SETUP ]]; then
    setup
  elif [[ $PREREQ ]]; then
    pre-req
  elif [[ $CLUSTER ]]; then
    deploy_cluster
  elif [[ $OPENSHIFT ]]; then
    configure_openshift
  elif [[ $FETCH ]]; then
    fetch_config
  elif [[ $RECYCLER ]]; then
    enable_recycler
  fi
}
main

