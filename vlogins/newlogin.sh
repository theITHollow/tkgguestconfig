#!/bin/bash

#Set Default Variables
VSPHERE_WITH_TANZU_CONTROL_PLANE_IP=${VSPHERE_WITH_TANZU_CONTROL_PLANE_IP:-sup.hollow.local}
VSPHERE_WITH_TANZU_USERNAME=${VSPHERE_WITH_TANZU_USERNAME:-"tanzu"}
VSPHERE_WITH_TANZU_PASSWORD=${VSPHERE_WITH_TANZU_PASSWORD:-""}
VSPHERE_WITH_TANZU_NAMESPACE=${VSPHERE_WITH_TANZU_NAMESPACE:-"utility"}
TKG_CHILD_CLUSTER=${TKG_CHILD_CLUSTER:-"utilitycluster"}
KUBECONFIG=${KUBECONFIG:-/tanzuconfigs/kubeconfig}

#Specify the KUBECONFIG Location
export KUBECONFIG=$KUBECONFIG
echo "KUBECONFIG PATH IS: $KUBECONFIG"

#Check for arguments that override the default variables. Set them if they exist.
while [[ "$1" =~ ^- && ! "$1" == "--" ]]; do
  echo $1 #For Troubleshooting args- uncomment
  case $1 in
    -s | --sup )
      shift; VSPHERE_WITH_TANZU_CONTROL_PLANE_IP=$1
      ;;

    -u| --user )
      shift; VSPHERE_WITH_TANZU_USERNAME=$1
      ;;

    -p| --pass )
      shift; VSPHERE_WITH_TANZU_PASSWORD=$1
      ;;

    -n| --namespace )
      shift; VSPHERE_WITH_TANZU_NAMESPACE=$1
      ;;

    -g| --guestcluster )
      shift; TKG_CHILD_CLUSTER=$1
      ;;

  esac; shift
done

echo "KUBECONFIG Located: $KUBECONFIG"

#Define where the binaries exist
KUBECTL_VSPHERE_PATH=/usr/local/bin/kubectl-vsphere
KUBECTL_PATH=/usr/local/bin/kubectl

#Run the login command
expect -c "
spawn $KUBECTL_VSPHERE_PATH login --server=$VSPHERE_WITH_TANZU_CONTROL_PLANE_IP --vsphere-username $VSPHERE_WITH_TANZU_USERNAME --tanzu-kubernetes-cluster-name=$TKG_CHILD_CLUSTER --tanzu-kubernetes-cluster-namespace=$VSPHERE_WITH_TANZU_NAMESPACE --insecure-skip-tls-verify
expect \"*?assword:*\"
send -- \"$VSPHERE_WITH_TANZU_PASSWORD\r\"
expect eof
"


#echo: "Command results:"
echo $KUBECTL_VSPHERE_LOGIN_COMMAND

#Set Context
#${KUBECTL_PATH} config use-context ${TKG_CHILD_CLUSTER}
echo "Cat the KUBECONFIG:"
cat $KUBECONFIG