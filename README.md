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
   vSphere Kubernetes supervisor namespace and create a KUBECONFIG file. This
   file will be placed in a volume under /tkgconfigs/kubeconfig and can be used
   for future commands.

2. ClusterConfig - This container uses the KUBECONFIG file to perform additional
   operations. The script within could be used to copy files over, restart
   services, reconfigure settings, etc.

## Instructions

1. Obtain the latest version of the linux `kubectl-vsphere` plugin from your
   Supervisor cluster and place it in the vlogins folder. There is a `.md` file
   in that directory as a placeholder. That file can be deleted when you've
   copied over the `kubectl-vsphere` plugin binary. Be sure you grab the `Linux`
   version.

2. Write your custom code. The clusterconfig/clusterconfig.sh script is what
   executes commands on the guest cluster. There are example configs in there
   already, but you should update the section labeled: 
   `#### YOUR CODE GOES IN THE SECTION BELOW!!!`
   with your own code to perform whatever configurations you need on those nodes.

3. Update the `docker-compose.yml` file with the image registry being used to
   store repos. You can do this by replacing the `IMAGE_REGISTRY_GOES_HERE`
   variable with your repo.

4. Build the docker images using the `docker-compose.yml` file by running:

``` 
docker compose build && docker compose push
```

The previous command will build both containers and push them to the image
registry you specified in step 2.

5. Update the `tkgconfig.yaml` file with the appropriate images.
   You can do this by replacing the `IMAGE_REGISTRY_GOES_HERE` placeholder with
   your own image registry. It should match the image registry used in step 2.

6. Update the deployment variable in the `tkgconfig.yaml` file to match your
   environment.

```cli
-- Arguments

-n: Supervisor Namespace where the guest cluster lives
-u: username for logging in
-p: password for logging in
-s: supervisor API Endpoint (What you'd use with the `kubectl vsphere login command after the `--server=` switch)
-g: guest cluster name
```

7. Deploy the `tkgconfig.yaml` manifest to a supervisor cluster's namespace
   where the guest cluster lives.

8. After the container is successfully deployed, it should perform the login,
   run the custom scripts and then sleep. You can delete the pod after this,
   automate the deletion, or keep it around for bastion pod. Note: the login is
   only good for 10 hours before the token expires. 