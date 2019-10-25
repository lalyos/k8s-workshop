this document explains how to set up the infrastructure for a workshop.

To set up the infrastucture, you can use Google Shell, with all the tools
preinstalled, and authenticated against the CS account.
Just use this url: [CloudShell](https://console.cloud.google.com/cloudshell/open?git_repo=https://github.com/lalyos/k8s-workshop&tutorial=infra-setup.md
)

## ChangeLog 2019-10-25

- cluster creation is moved to a function `start-cluster`
- start-cluster and related config values are configurable in `.profile`
- basic auth for session urls (instead of random path prefix) - username: "user" passwd:[see variable](https://github.com/lalyos/k8s-workshop/blob/master/workshop-functions.sh#L130)
- uses latest available k8s version - see: [commit](https://github.com/lalyos/k8s-workshop/commit/3b1f59f8f444de8daacfd8d48e9efbd05c0773d4#diff-9cdb5a52952540ea9fa5d98c22de2c80R28)
- cluster is configurable via environment variables:
  - machineType (n1-standard-2)
  - defPoolSize (3)
  - preemPoolSize (3)
  - zone (europe-west3-b)
- istio and http lb is switched of by default (speedup start) - see: 403bc36d8c25f6173e04b8fca0d1a0c5a96c1601

## Configure Project

GCP sdk is used to perform cluster creation. The minimum you need is to set the
active project:
```
gcloud config set project  container-solutions-workshops
```

check for existing clusters:
```
gcloud container clusters list
```

## Start a new clusters

Lets start a 6 node cluster:
- default node pool with 3 instances
- second pool with 3 preemptible instances

You can change all default values in your profile.
```
cp .profile-example .profile
```

To load all helper functions (and activate/source you profile)
```
source workshop-functions.sh
```

Now you can create the GKE cluster. All config will be printed,
and you have a chance to review and cancel.
```
start-cluster
```

checking the GKE cluster 
```
gcloud container clusters list
```

get kubectl credentials
```
gcloud container clusters get-credentials workshop --zone=${zone}
```

## Initial setup

At the begining you have to create some cluster roles :
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

The script will install the official nginx ingress controller.
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

Sometimes the web based sessions are constantly dropping connection. Proxies and websockets sometimes dont like eachother. Ssh to the rescue.

To make user sessions available via ssh, first deploy the single ssh proxy to the cluster
```
init-sshfront
```

To configure ssh pubkeys, each user has to issue the `ssh-pubkey` command inside the session. It can take the pubkey from 2 sources:
- github
- stdin

The easiest way is to relay on github ssh keys (It will install all public ssh keys from github)
```
ssh-pubkey <GITHUB_USERNAME>
```

Or you can echo/curl your public key and pipe it to the `ssh-pubkey` command:
```
echo 'ssh-rsa AAAAB3NzaC1yc....gqvp1+Pil/4BWunWnXi3jT' | ssh-pubkey
```

On success the command will print the ssh command to use
```
configmap/ssh configured
You can now connect via:
  ssh userX@42.246.111.222 -p 31723
```