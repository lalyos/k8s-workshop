#!/bin/bash

WORKING_NS="default"

assign-role-to-ns() {
  declare desc="creates namespace restricted serviceaccount"
  declare namespace=${1}
  : ${namespace:? required}

  cat << EOF
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: sa-${namespace}
  namespace: ${namespace}

---
kind: Role
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: role-${namespace}
  namespace: ${namespace}
rules:
- apiGroups: ["", "extensions", "apps", "autoscaling"]
  resources: ["*"]
  verbs: ["*"]
- apiGroups: ["batch"]
  resources:
  - jobs
  - cronjobs
  verbs: ["*"]

---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: rb-${namespace}
  namespace: ${namespace}
subjects:
- kind: ServiceAccount
  name: sa-${namespace}
  namespace: ${namespace}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: role-${namespace}
EOF
}

ns-config() {
  declare namespace=${1} ca=${2} token=${3} server=${4:-kubernetes.default.svc.cluster.local}
  : ${namespace:? required}
  : ${ca:? required}
  : ${token:? required}

    cat << EOF
apiVersion: v1
clusters:
- cluster:
    server: https://${server}
    certificate-authority-data: ${ca}
  name: lokal
contexts:
- context:
    cluster: lokal
    namespace: ${namespace}
    user: default
  name: default
current-context: default
kind: Config
preferences: {}
users:
- name: default
  user:
    token: ${token}
EOF
}

config-reader-token() {
  #kubectl create clusterrole config-reader --resource=configmaps --verb=*
  #kubectl create serviceaccount config-reader
  #kubectl create clusterrolebinding crb-config-reader --clusterrole=config-reader --serviceaccount=default:config-reader
  #kubectl create clusterrolebinding crb-config-reader-full --clusterrole=cluster-admin --serviceaccount=default:config-reader

  #ca=$(kubectl config view --minify --flatten -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')
  ca=$(kubectl config view --minify --flatten -o go-template='{{ index (index .clusters 0).cluster "certificate-authority-data" }}')

  apiserver=$(kubectl get svc kubernetes -n $WORKING_NS -o jsonpath='{.spec.clusterIP}')
  ns-config default $ca $(token default config-reader) ${apiserver}
}

token() {
    declare namespace=${1} serviceAccount=${2}
    : ${namespace:? required}
    : ${serviceAccount:=sa-${namespace}}

    if [[ "Darwin" == $(uname) ]]; then
      BASE64_OPTIONS="-D"
    else 
      BASE64_OPTIONS="-d"
    fi

    kubectl get secrets \
      -n ${namespace} \
      -o jsonpath="{.items[?(@.metadata.annotations['kubernetes\.io/service-account\.name'] == '${serviceAccount}' )].data.token}" \
       | base64 $BASE64_OPTIONS
}

## kubectl wait isnt available with v1.10
wait-for-deployment() {
  declare deployment=${1}
  : ${deployment:? required}

  while ! [[ 1 -eq $(kubectl get deployments -n $WORKING_NS ${deployment} -o jsonpath='{.status.readyReplicas}' 2> /dev/null) ]]; do
    echo -n .
    sleep 1
  done
}

namespace() {
    declare namespace=${1}
    : ${namespace:? required}

    kubectl create ns ${namespace}
    assign-role-to-ns ${namespace} | kubectl create -f -

    kubectl create clusterrolebinding crb-${namespace} --clusterrole=lister --serviceaccount=${namespace}:sa-${namespace}
    kubectl create clusterrolebinding crb-cc-${namespace} --clusterrole=common-config --serviceaccount=${namespace}:sa-${namespace}
    
    #ca=$(kubectl config view --minify --flatten -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')
    ca=$(kubectl config view --minify --flatten -o go-template='{{ index (index .clusters 0).cluster "certificate-authority-data" }}')

    token=$(token ${namespace})
    apiserver=$(kubectl get svc -n $WORKING_NS kubernetes -o jsonpath='{.spec.clusterIP}')
    kubectl create -n $WORKING_NS secret generic ${namespace} --from-file=config.yaml=<(ns-config ${namespace} $ca $token $apiserver)
}

depl() {
  declare namespace=${1}
  : ${namespace:? required}
  : ${gitrepo:=https://github.com/ContainerSolutions/ws-kubernetes-essentials-app.git}

  local secret="${namespace}"
  #local number="${namespace#user}"
  #local name="dev${number}"
  local name=${namespace}

cat <<EOF
apiVersion: apps/v1beta1
kind: Deployment
metadata:
  labels:
    run: ${name}
  name: ${name}
spec:
  replicas: 1
  selector:
    matchLabels:
      run: ${name}
  template:
    metadata:
      labels:
        run: ${name}
    spec:
      volumes:
        - name: k8sconfig
          secret:
            secretName: ${secret}
        - name: gitrepo
          gitRepo:
            repository: ${gitrepo}
            directory: .
      containers:
      - args:
        - gotty
        - "-w"
        - "-r"
        - "--title-format=${name}"
        #- tmux
        - bash
        env:
          - name: NS
            value: ${name} 
          - name: TERM
            value: xterm
          - name: KUBECONFIG
            value: /root/.sa/config.yaml
        image: lalyos/k8s-workshop
        name: dev
        volumeMounts:
          - mountPath: /root/.sa
            name: k8sconfig
          - mountPath: /root/workshop
            name: gitrepo 
---
apiVersion: v1
kind: Service
metadata:
  labels:
    run: ${name}
  name: ${name}
spec:
  ports:
  - port: 8080
    protocol: TCP
    targetPort: 8080
  selector:
    run: ${name}
  type: NodePort
EOF
}

dev() {
    declare namespace=${1} gitrepo=${2:-https://github.com/ContainerSolutions/ws-kubernetes-essentials-app.git}
    : ${namespace:? required}
    
    namespace ${namespace}
    depl ${namespace} ${gitrepo}| kubectl create -n $WORKING_NS -f -

    wait-for-deployment ${namespace}
    get-url ${namespace} 
}

presenter() {
   local pod=$(kubectl get po -n $WORKING_NS -l run=user0 -o jsonpath='{.items[0].metadata.name}')
   #kubectl exec -t $pod -- tmux new-session -s delme -d  2>/dev/null
   kubectl exec -n $WORKING_NS -it $pod -- tmux new-session -A -s presenter
}

presenter-url() {
    if ! kubectl get svc -n $WORKING_NS presenter &> /dev/null; then
      local pod=$(kubectl get po -l run=user0 -o jsonpath='{.items[0].metadata.name}')
      #kubectl exec -it $pod -- bash -c "gotty -p 8888 tmux attach -r -t presenter &"
      kubectl exec -n $WORKING_NS -it $pod -- bash -c "nohup /usr/local/bin/gotty -p 8888 tmux attach -r -t presenter &"
      kubectl expose deployment user0 --port 8888 --type=NodePort --name presenter
    fi

   externalip=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type == "ExternalIP")].address}') 
   kubectl get svc -n $WORKING_NS presenter -o jsonpath="[presenter] open http://${externalip}:{.spec.ports[0].nodePort}"
   echo
}

get-url() {
    declare deployment=${1}

    : ${deployment:? required}
    pod=$(kubectl get po -n $WORKING_NS -lrun=${deployment} -o jsonpath='{.items[0].metadata.name}')
    rndPath=$(kubectl logs -n $WORKING_NS ${pod} |sed -n '/HTTP server is listening at/ s/.*:8080//p')
    externalip=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type == "ExternalIP")].address}') 
    kubectl get svc -n $WORKING_NS ${deployment} -o jsonpath="[${deployment}] open http://${externalip}:{.spec.ports[0].nodePort}${rndPath}"
    echo
}

init() {
    : ${USER_EMAIL:=$(gcloud auth list --format="value(account)" --filter=status:ACTIV)}
    if ! kubectl get clusterrolebinding cluster-admin-binding &> /dev/null; then
      kubectl create clusterrolebinding cluster-admin-binding \
        --clusterrole cluster-admin \
        --user ${USER_EMAIL}
     fi

    if ! kubectl get clusterrole lister &> /dev/null; then
      kubectl create clusterrole lister \
        --verb=get,list,watch \
        --resource=nodes,namespaces
    fi

    if ! kubectl get clusterrole common-config &> /dev/null; then
      kubectl create clusterrole common-config \
        --verb=list,get,watch \
        --resource=configmaps \
        --resource-name=common
    fi
    
    
}

main() {
  : DEBUG=1
  init

}
