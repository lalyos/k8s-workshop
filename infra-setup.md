this document explains how to set up the infrastructure for a workshop

## Configure Project

```
gcloud config set project  container-solutions-workshops
```

list existing clusters

```
gcloud container clusters list
```

## start a new clusters

Lets start a 6 node cluster:
- default node pool with 3 n1-standard-2 instances
- second pool with 3 preemptible n1-standard-2 instances

```
gcloud beta container \
      --project "container-solutions-workshops" \
      clusters create "workshop" \
      --zone "europe-west3-b" \
      --username "admin" \
      --cluster-version "1.12.7-gke.10" \
      --machine-type "n1-standard-2" \
      --image-type "UBUNTU" \
      --disk-type "pd-standard" \
      --disk-size "100" \
      --metadata disable-legacy-endpoints=true \
      --scopes "https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append" \
      --num-nodes "3" \
      --enable-cloud-logging \
      --enable-cloud-monitoring \
      --no-enable-ip-alias \
      --network "projects/container-solutions-workshops/global/networks/default" \
      --addons HorizontalPodAutoscaling,HttpLoadBalancing,Istio \
      --istio-config auth=MTLS_PERMISSIVE \
      --enable-autoupgrade \
      --enable-autorepair \
 && gcloud beta container \
      --project "container-solutions-workshops" \
      node-pools create "pool-1" \
      --cluster "workshop" \
      --zone "europe-west3-b" \
      --node-version "1.12.7-gke.10" \
      --machine-type "n1-standard-2" \
      --image-type "UBUNTU" \
      --disk-type "pd-standard" \
      --disk-size "100" \
      --metadata disable-legacy-endpoints=true \
      --scopes "https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append" \
      --preemptible \
      --num-nodes "3" \
      --no-enable-autoupgrade \
      --enable-autorepair
```

checking the GKE cluster 
```
gcloud container clusters list
```
## Starting Workshop infra on gke

You need to set up the following 2 env vars:
```
export workshopNamespace=workshop
export domain=k8z.eu
export gitrepo=https://github.com/lalyos/timber
```

First you have to load the helper bash functions:
```
source workshop-functions.sh
```

## Initial setup

At the begining you have to create some cluster roles ...

```
init
```

if you get some errors try to re-run it. The functions is idempotent, so its safe to re-run.

## Ingress setup

By default GKE is using a Google specific LoadBalancer implementation for ingresses.
The issue with that one:
- its slow
- it costs $$$
- when lot of partacipiants start to create a bunch of ingresses, it gets really slow, and **paid** LB  are created

Therefore :
- disable the default LoadBalancer backed ingress controller
- deploy the vanilla nginx-ingresses

```
init-ingress
```

Disabling the LoadBalancer is a manual step, you have to perform in Cloud console.
The script will check, and in case its not disabled yet, it will give
you instructions how to disable it on the UI.

If istio add-on is enabled than this step can take a couple of minutes ...
To check that your cluster is available after the changes list nodes:

```
kubectl get no -o wide
```

To check that the nginx ingress is fully deployed, list resources in the **ingress-nginx**

```
kubectl get all -n ingress-nginx
```

DNS setup

 Follow the instructions of `init-ingress` function about the IP adress of the deployed ingress controller.
 

## Create user sessions

For testing the environment lets just create the **user0** session, which will be used by the presenter.

```
dev user0
```
