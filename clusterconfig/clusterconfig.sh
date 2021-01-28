#!/bin/bash

sshkey="/tanzuconfigs/sshkey"
gckubeconfig="/tanzuconfigs/kubeconfig"

print_help() {
  echo " "
  echo "Help:"
  echo "  -g GUEST_CLUSTER_NAME"
  echo "  -n SUPERVISOR_NAMESPACE_OF_GUEST_CLUSTER"
  exit 1
}

while [[ "$1" =~ ^- && ! "$1" == "--" ]]; do
  case $1 in
    -h | --help )
        print_help
        exit 1
        ;;

    -g| --guestcluster )
        shift; guestcluster=$1
        ;;

    -n| --namespace )
        shift; namespace=$1
        ;;

    *)
        echo "Invalid option"
        print_help
        ;;

  esac; shift
done

#Precheck to see if files exist
pre_check() {
  ssh -q -i ${sshkey} -o StrictHostKeyChecking=no vmware-system-user@${node_ip} "sudo [ ! -d ${dir} ] && echo 'Creating ${dir}' && sudo mkdir -p ${dir} || echo 'Directory exists'"

  ssh -q -i ${sshkey} -o StrictHostKeyChecking=no vmware-system-user@${node_ip} "sudo [ -f ${destination} ] && echo 'Creating backup' && sudo cp ${destination} ${destination}.bk-$(date +%F_%R) || echo 'No pre-existing file at ${destination}'"
}

#Use to copy a file to each node
copyfile() {
  node_ip=$1
  filepath=$2
  destination=$3

  pre_check
  [[ $? == 0 ]] && scp -q -i ${sshkey} -o StrictHostKeyChecking=no ${filepath} vmware-system-user@${node_ip}:/tmp/copied_file
  [[ $? == 0 ]] && ssh -q -i ${sshkey} -o StrictHostKeyChecking=no vmware-system-user@${node_ip} "sudo mv /tmp/copied_file ${destination} && sudo chown root:root ${destination} || echo 'Failed to move file'"
}

#Use to restart a system service
service_restart() {
    node_ip=$1
    service=$2

    echo "Restarting ${service} on ${node_ip} ... this can take a few seconds"
    ssh -q -i ${sshkey} -o StrictHostKeyChecking=no vmware-system-user@${node_ip} "sudo systemctl daemon-reload && sudo systemctl restart ${service} || echo 'Failed to restart ${service}'"

}
#Get SSH Key
kubectl config use-context ${namespace} --kubeconfig=${gckubeconfig}
kubectl get secret -n ${namespace} ${guestcluster}"-ssh" -o jsonpath='{.data.ssh-privatekey}' --kubeconfig=${gckubeconfig} | base64 -d > ${sshkey}
[ $? != 0 ] && echo " please check existence of guest cluster private key secret" && exit
chmod 600 ${sshkey}

#Get IP addresses of nodes
kubectl config use-context ${guestcluster} --kubeconfig=${gckubeconfig}
iplist=$(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}' --kubeconfig=${gckubeconfig})

echo "Cluster Node IPs"
echo $(kubectl get nodes)

#### YOUR CODE GOES IN THE SECTION BELOW!!!
# Within the for loop, commands will be executed for each host in the cluster
# Commands written in the for loop are for example purposes and do not need tto
# be kept.
###########################################

# Loop to run commands against each node
for ip in ${iplist}; do

# Example Routine -- Copy containerd config file to each host.
# Requires the config.toml file to be built into the container. If you add the 
# file to the existing directory before the build, that is sufficient. A
# config.toml file is there as an example. 
  echo "Updating Containerd Config"
  copyfile ${ip} config.toml /etc/containerd/config.toml && echo "Successfully copied config.toml to node ${ip}:/etc/containerd/config.toml" || echo "Failed to copy config.toml to node ${ip}:/etc/containerd/config.toml"

# Another common configuration is to copy certificates to your nodes 
# specifically if you're setting up a custom image registry.
# Again, requires the cert to be build into the container. An example ca.crt
# file is in the directory structure.
  echo "Copying ca certs"
  copyfile ${ip} ca.crt /etc/ssl/certs/ca.crt && echo "Successfully installed root ca into node ${ip}" || echo "Failed to install root ca into node ${ip}"

# Restart a system service - Typically after files are copied over
# This example uses containerd as the example service.
  service_restart ${ip} containerd  && echo "Successfully restarted containerd on node ${ip}" || echo "Failed to restart containerd on node ${ip}"

done

# Container sleeps to keep it running for exec or troubleshooting purposes.
sleep 3600

# You can also execute kubectl commands by using the
# --kubeconfig=${gckubeconfig} switch
