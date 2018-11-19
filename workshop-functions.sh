#!/bin/bash

assign-role-to-ns() {
  declare desc="creates namespace restricted serviceaccount"
  declare namespace=${1}
  : ${namespace:? required}
  : ${workshopNamespace:? required}

  cat << EOF
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: sa-${namespace}
  namespace: ${workshopNamespace}
  labels:
    user: "${namespace}"
---
kind: Role
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: role-${namespace}
  namespace: ${namespace}
  labels:
    user: "${namespace}"
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
  labels:
    user: "${namespace}"
subjects:
- kind: ServiceAccount
  name: sa-${namespace}
  namespace: ${workshopNamespace}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: role-${namespace}
---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: rb-def-${namespace}
  namespace: ${namespace}
  labels:
    user: "${namespace}"
subjects:
- kind: ServiceAccount
  name: default
  namespace: ${mamespace}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: role-${namespace}
EOF
}

## kubectl wait isnt available with v1.10
wait-for-deployment() {
  declare deployment=${1}
  : ${deployment:? required}

  while ! [[ 1 -eq $(kubectl get deployments ${deployment} -o jsonpath='{.status.readyReplicas}' 2> /dev/null) ]]; do
    echo -n .
    sleep 1
  done
}

namespace() {
    declare namespace=${1}
    : ${namespace:? required}
    : ${workshopNamespace:? required}

    kubectl create ns ${namespace}
    kubectl label ns ${namespace} user=${namespace} 
    assign-role-to-ns ${namespace} | kubectl create -f -

    kubectl create clusterrolebinding crb-${namespace} --clusterrole=lister --serviceaccount=${workshopNamespace}:sa-${namespace}
    kubectl label clusterrolebinding crb-${namespace} user=${namespace} 
    kubectl create clusterrolebinding crb-cc-${namespace} --clusterrole=common-config --serviceaccount=${namespace}:sa-${namespace}
    kubectl label clusterrolebinding crb-cc-${namespace} user=${namespace} 
    
}

enable-namespaces() {
  if ! kubectl get validatingwebhookconfiguration workshopnamespacevalidator -o name 2> /dev/null ;then
    kubectl apply -f https://raw.githubusercontent.com/lalyos/k8s-ns-admission/master/deploy-webhook-job.yaml 
  fi 
  kubectl patch clusterrole lister --patch='{"rules":[{"apiGroups":[""],"resources":["nodes","namespaces"],"verbs":["*"]}]}'
}

disable-namespaces() {
  kubectl patch clusterrole lister --patch='{"rules":[{"apiGroups":[""],"resources":["nodes","namespaces"],"verbs":["get","list","watch"]}]} '
}

depl() {
  declare namespace=${1}
  : ${namespace:? required}
  : ${gitrepo:=https://github.com/ContainerSolutions/ws-kubernetes-essentials-app.git}

  local name=${namespace}

cat <<EOF
apiVersion: apps/v1beta1
kind: Deployment
metadata:
  labels:
    user: "${namespace}"
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
      serviceAccountName: sa-${name}
      volumes:
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
          - name: TILLER_NAMESPACE
            value: ${name} 
          - name: NODE
            valueFrom:
              fieldRef:
                fieldPath: spec.nodeName
          - name: SA
            valueFrom:
              fieldRef:
                fieldPath: spec.serviceAccountName
          - name: TERM
            value: xterm
        image: lalyos/k8s-workshop
        name: dev
        volumeMounts:
          - mountPath: /root/workshop
            name: gitrepo 
---
apiVersion: v1
kind: Service
metadata:
  labels:
    user: "${namespace}"
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
    declare namespace=${1}
    : ${namespace:? required}
    
    namespace ${namespace}
    namespace ${namespace}play
    kubectl create rolebinding crb-${namespace}-x \
      --role=role-${namespace}play \
      --namespace=${namespace}play \
      --serviceaccount=default:sa-${namespace}

    depl ${namespace}| kubectl create -f - 

    wait-for-deployment ${namespace}
    get-url ${namespace} 
}

presenter() {
   local pod=$(kubectl get po -l run=user0 -o jsonpath='{.items[0].metadata.name}')
   #kubectl exec -t $pod -- tmux new-session -s delme -d  2>/dev/null
   kubectl exec -it $pod -- tmux new-session -A -s presenter
}

presenter-url() {
    if ! kubectl get svc presenter &> /dev/null; then
      local pod=$(kubectl get po -l run=user0 -o jsonpath='{.items[0].metadata.name}')
      #kubectl exec -it $pod -- bash -c "gotty -p 8888 tmux attach -r -t presenter &"
      kubectl exec -it $pod -- bash -c "nohup /usr/local/bin/gotty -p 8888 --title-format=presenter tmux attach -r -t presenter &"
      kubectl expose deployment user0 --port 8888 --type=NodePort --name presenter
    fi

   externalip=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type == "ExternalIP")].address}') 
   kubectl get svc presenter -o jsonpath="open http://${externalip}:{.spec.ports[0].nodePort}"
   echo
}

get-url() {
    declare deployment=${1}

    : ${deployment:? required}
    pod=$(kubectl get po -lrun=${deployment} -o jsonpath='{.items[0].metadata.name}')
    rndPath=$(kubectl logs ${pod} |sed -n '/HTTP server is listening at/ s/.*:8080//p')
    externalip=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type == "ExternalIP")].address}') 
    kubectl get svc ${deployment} -o jsonpath="open http://${externalip}:{.spec.ports[0].nodePort}${rndPath}"
    echo
}

init() {
    : ${userEmail:=$(gcloud auth list --format="value(account)" --filter=status:ACTIV 2>/dev/null)}
    : ${workshopNamespace:=workshop}
    : ${gitrepo:=https://github.com/ContainerSolutions/ws-kubernetes-essentials-app.git}

    workshop-context
    init-firewall

    if ! kubectl get clusterrolebinding cluster-admin-binding &> /dev/null; then
      kubectl create clusterrolebinding cluster-admin-binding \
        --clusterrole cluster-admin \
        --user ${userEmail}
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
        kubectl label clusterrole common-config user=workshop
    fi
}

init-firewall() {
  if gcloud compute firewall-rules describe external-nodeports &> /dev/null; then
    echo "---> firewall is already opened for NodePorts"
    return
  fi

  echo "---> open up firewall for NodePorts (30000-32767)"
  gcloud compute firewall-rules create external-nodeports \
   --description="allow external access to k8s nodeport" \
   --direction=INGRESS \
   --priority=1000 \
   --network=default \
   --action=ALLOW \
   --rules=tcp:30000-32767 \
   --source-ranges=0.0.0.0/0
}

workshop-context() {
  : ${workshopNamespace:? required}

  if [[ "$KUBECONFIG" == "$PWD/config-workshop.yaml" ]]; then
    echo "---> workshop context already set. To return to original context:"
    echo "--->   export KUBECONFIG=$PWD/config-orig.yaml"
    return
  fi
  kubectl config view --minify --flatten > config-orig.yaml
  kubectl create ns ${workshopNamespace} 
  cp config-orig.yaml config-workshop.yaml 
  export KUBECONFIG=$PWD/config-workshop.yaml
  kubectl config set-context $(kubectl config current-context) --namespace=${workshopNamespace}
  echo "---> context set to use namespace: ${workshopNamespace}, by:"
  echo "export KUBECONFIG=$KUBECONFIG"
}

clean-user() { 
    ns=$1;
    : ${ns:?required};

    kubectl delete  ns,sa,clusterrolebinding,deployment,svc -l user=${ns}
}

main() {
  : DEBUG=1
  init

}
