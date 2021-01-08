#!/bin/bash

print_help() {
  echo " "
  echo "Help:"
  echo "Only one of either -c or -l can be supplied. File Copy or Cert Install"
  echo "  -l FULL_PATH_TO_LOCALFILE"
  echo "  -d FULL_DESTINATION_PATH"
  echo "  -g GUEST_CLUSTER_NAME"
  echo "  -s SUPERVISOR_NAMESPACE_OF_GUEST_CLUSTER"
  echo "  -c FULL_PATH_TO_CERT"
  echo "  -r SYSTEMCTL_SERVICE_TO_RESTART"
  exit 1
}


while [[ "$1" =~ ^- && ! "$1" == "--" ]]; do
  case $1 in
    -h | --help )
      print_help
      exit 1
      ;;

    -l | --local )
      shift; file=$1
      ;;

    -d| --destination )
      shift; destination=$1
      ;;

    -g| --gcname )
      shift; gcname=$1
      ;;

    -s| --svnamespace )
      shift; svnamespace=$1
      ;;

    -c| --capath )
      shift; capath=$1
      ;;

    -r| --restart )
      shift; service=$1
      ;;

    *)
      echo "Invalid option"
      print_help
      ;;

  esac; shift
done
if [[ "$1" == '--' ]]; then shift; fi

if [[ -z "${gcname}" || -z "${svnamespace}" ]]; then
  echo "-g and -s are required"
  exit
elif [[ -n "${capath}" ]]; then
  if [[ -n "${file}" || -n "${destination}" ]]; then
    echo "-c cannot be used with -l or -d."
    exit
  fi
elif [[ -n "${service}" && -z "${file}" && -z "${destination}" ]]; then
  echo "Just a service restart"  
elif [[ -z "${file}" || -z "${destination}" ]]; then
  echo "If copying a file, -l and -d must not be blank"
  exit
else
  echo "Setting dir name"
  dir=$(dirname $destination)
fi


workdir="/tmp/${svnamespace}-${gcname}"
mkdir -p ${workdir}
sshkey=${workdir}/gc-sshkey # path for gc private key
gckubeconfig=${workdir}/kubeconfig # path for gc kubeconfig
timestamp=$(date +%F_%R)
#dir=$(dirname $destination)

pre_check() {
  ssh -q -i ${sshkey} -o StrictHostKeyChecking=no vmware-system-user@${node_ip} "sudo [ ! -d ${dir} ] && echo 'Creating ${dir}' && sudo mkdir -p ${dir} || echo 'Directory exists'"

  ssh -q -i ${sshkey} -o StrictHostKeyChecking=no vmware-system-user@${node_ip} "sudo [ -f ${destination} ] && echo 'Creating backup' && sudo cp ${destination} ${destination}.bk-$(date +%F_%R) || echo 'No pre-existing file at ${destination}'"
}


copyfile() {
  node_ip=$1
  filepath=$2
  destination=$3

  pre_check
  [[ $? == 0 ]] && scp -q -i ${sshkey} -o StrictHostKeyChecking=no ${filepath} vmware-system-user@${node_ip}:/tmp/copied_file
  [[ $? == 0 ]] && ssh -q -i ${sshkey} -o StrictHostKeyChecking=no vmware-system-user@${node_ip} "sudo mv /tmp/copied_file ${destination} && sudo chown root:root ${destination} || echo 'Failed to move file'"
}


installCA() {
  node_ip=$1
  capath=$2
  scp -q -i ${sshkey} -o StrictHostKeyChecking=no ${capath} vmware-system-user@${node_ip}:/tmp/ca.crt
  [[ $? == 0 ]] && ssh -q -i ${sshkey} -o StrictHostKeyChecking=no vmware-system-user@${node_ip} sudo cp /etc/pki/tls/certs/ca-bundle.crt /etc/pki/tls/certs/ca-bundle.crt_bk.${timestamp}

  [[ $? == 0 ]] && ssh -q -i ${sshkey} -o StrictHostKeyChecking=no vmware-system-user@${node_ip} 'sudo cat /etc/pki/tls/certs/ca-bundle.crt /tmp/ca.crt > /tmp/ca-bundle.crt'
  [[ $? == 0 ]] && ssh -q -i ${sshkey} -o StrictHostKeyChecking=no vmware-system-user@${node_ip} sudo mv /tmp/ca-bundle.crt /etc/pki/tls/certs/ca-bundle.crt
}


restart_service() {
  node_ip=$1
  ssh -q -i ${sshkey} -o StrictHostKeyChecking=no vmware-system-user@${node_ip} "sudo systemctl daemon-reload && sudo systemctl restart ${service} || echo 'Failed to restart ${service}'"
}


### Main
# get guest cluster private key for each node
export KUBECONFIG=/tanzuconfigs/kubeconfig
kubectl config use-context ${svnamespace}
kubectl get secret -n ${svnamespace} ${gcname}"-ssh" -o jsonpath='{.data.ssh-privatekey}' | base64 -d > ${sshkey}
[ $? != 0 ] && echo " please check existence of guest cluster private key secret" && exit
chmod 600 ${sshkey}

#get guest cluster kubeconfig
kubectl get secret -n ${svnamespace} ${gcname}"-kubeconfig" -o jsonpath='{.data.value}' | base64 -d > ${gckubeconfig}
[ $? != 0 ] && echo " please check existence of guest cluster private key secret" && exit

# get IPs of each guest cluster nodes
iplist=$(KUBECONFIG=${gckubeconfig} kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}')

for ip in ${iplist}; do

  if [[ -n "${file}" ]]; then
    echo "Copying ${file} to node ${ip}:${destination}"
    copyfile ${ip} ${file} ${destination} && echo "Successfully copied $file to node ${ip}:${destination}" || echo "Failed to copy $file to node ${ip}:${destination}"
  fi

  if [[ -n "${capath}" ]]; then
    echo "Installing root ca into node ${ip}"
    installCA ${ip} ${capath} && echo "Successfully installed root ca into node ${ip}" || echo "Failed to install root ca into node ${ip}"
  fi

  if [[ -n "${service}" ]]; then
    echo "Restarting ${service} on ${ip} ... this can take a few seconds"
    restart_service ${ip}
    [[ $? = 0 ]] && echo "${service} restarted" || echo "Failed to restart ${service}"
  fi

done

sleep 3600