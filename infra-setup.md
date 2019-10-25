this document explains how to set up the infrastructure for a workshop.

To set up the infrastucture, you can use Google Shell, with all the tools
preinstalled, and authenticated against the CS account.
Just use this url: [CloudShell](https://console.cloud.google.com/cloudshell/open?git_repo=https://github.com/lalyos/k8s-workshop&tutorial=infra-setup.md
)

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
- default node pool with 3 instances
- second pool with 3 preemptible instances

```
echo ${clusterName:=workshop}
echo ${clusterVersion:=$(gcloud container get-server-config  --format="value(validMasterVersions[0])" 2>/dev/null)}
echo ${machineType:=n1-standard-2}
echo ${defPoolSize:=3}
echo ${preemPoolSize:=3}
echo ${zone:=europe-west3-b}

gcloud beta container \
      --project "container-solutions-workshops" \
      clusters create "${clusterName}" \
      --zone "${zone}" \
      --username "admin" \
      --cluster-version ${clusterVersion} \
      --machine-type "${machineType}" \
      --image-type "UBUNTU" \
      --disk-type "pd-standard" \
      --disk-size "100" \
      --metadata disable-legacy-endpoints=true \
      --scopes "https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append" \
      --num-nodes "${defPoolSize}" \
      --enable-cloud-logging \
      --enable-cloud-monitoring \
      --no-enable-ip-alias \
      --network "projects/container-solutions-workshops/global/networks/default" \
      --addons HorizontalPodAutoscaling \
      --enable-autoupgrade \
      --enable-autorepair \
 && gcloud beta container \
      --project "container-solutions-workshops" \
      node-pools create "pool-1" \
      --cluster "${clusterName}" \
      --zone "${zone}" \
      --node-version ${clusterVersion} \
      --machine-type "${machineType}" \
      --image-type "UBUNTU" \
      --disk-type "pd-standard" \
      --disk-size "100" \
      --metadata disable-legacy-endpoints=true \
      --scopes "https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append" \
      --preemptible \
      --num-nodes "${preemPoolSize}" \
      --no-enable-autoupgrade \
      --enable-autorepair
```

checking the GKE cluster 
```
gcloud container clusters list
```

get kubectl credentials
```
gcloud container clusters get-credentials workshop --zone=${zone}
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

The script will install the offitial nginx ingress controller.
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
Please note, the first couple may take more time, as the docker image should be pulled on each node.

To create more user sssions use the following line
```
for u in user{2..15}; do dev $u; done
```


## Enable ssh

Sometimes the web based sessions are loosing connection. Proxies and websockets sometimes dont like eachother. Ssh to the rescue.

To make user sessions available as via ssh:
```
#kubectl apply -f https://raw.githubusercontent.com/lalyos/k8s-sshfront/master/sshfront.yaml

## fix default ns issue
curl  -s https://raw.githubusercontent.com/lalyos/k8s-sshfront/master/sshfront.yaml \
  | sed "s/default/$workshopNamespace/" \
  | kubectl apply -f -
```

now pods can be accesed via ssh. the following will print instructions:
```
echo ssh $(kubectl get no -o jsonpath='{.items[0].status.addresses[?(.type=="ExternalIP")].address}')   -p $(kubectl get svc sshfront -o jsonpath='{.spec.ports[0].nodePort}')   -l PODNAME
```

to get user session authentications 2 steps needed:
- users itself has to register their ssh publey (store it in a cm by the ssh-pubkey function)
- admin has to set a common env variable (in the common cm) to point to the ssh svc NodePort.

update the file 'common.env' with something like:
```
...
SSH_DOMAIN=n1.k8z.eu
SSH_PORT=32531
...
```

than update and distribute the common env to all user session
```
update-common-env
```

than users can retrieve the common envs in their session by the **common-env** function

## Self Service portal

After creating the user sessions, its hard to distribute/assign the session urls.

There is a small gitter authentication based web app, where participants can get an unused
session assigned to them.
More details and the process toget GITTER credentials is described: https://github.com/lalyos/gitter-scripter

```
export GITTER_OAUTH_KEY=xxxxxxx
export GITTER_OAUTH_SECRET=yyyyyyy
kubectl create secret generic gitter \
  --from-literal=GITTER_OAUTH_KEY=$GITTER_OAUTH_KEY \
  --from-literal=GITTER_OAUTH_SECRET=$GITTER_OAUTH_SECRET
# todo automate setting of gitter room:

export workshopNamespace=workshop
export domain=k8z.eu
curl -sL https://raw.githubusercontent.com/lalyos/gitter-scripter/master/gitter-template.yaml \
  | envsubst \
  | kubectl apply -f -

export gitterRoom=lalyos/earthport
kubectl patch deployments gitter --patch '{"spec":{"template":{"spec":{"$setElementOrder/containers":[{"name":"gitter"}],"containers":[{"$setElementOrder/env":[{"name":"GITTER_ROOM_NAME"},{"name":"DOMAIN"}],"env":[{"name":"GITTER_ROOM_NAME","value":"'${gitterRoom}'"}],"name":"gitter"}]}}}}'
```

The users can self service at: http://session.k8z.eu
