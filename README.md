# tkgguestconfig
Application for updating TKG Guest Clusters and Nodes on vSphere 7 with Tanzu

## Purpose

The purpose of this project is to provide a mechanism to update Tanzu Kubernetes
Grid child clusters on VMware vSphere 7 with Tanzu.

TKG guest clusters often need special configurations updated to successfully
integrate into an environment. Configuring trusted certificates, etc.

## How

This project uses two containers.

1. vLogins - This container is used as an init container that will login to a
   vSphere Kubernetes supervisor namespace and create a KUBECONFIG file. 

2. ClusterConfig - This container uses the KUBECONFIG file to perform additional
   operations. The script within could be used to copy files over, restart
   services, reconfigure settings, etc.

## Instructions

1. Obtain the latest version of the linux kubectl-vsphere plugin from your
   Supervisor cluster and place it in the vlogins folder.

2. Build the vlogins container and push it to an available image registry.

3. Build the clusterconfig container and push it to an available image registry.

4. Update the tkgconfig.yaml file with the appropriate images and the arguments.

5. Deploy the script to a supervisor cluster.