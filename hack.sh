#!/usr/bin/env bash

# init-caddy-light
# k cp ~/prj/k8s-workshop/hack.sh $(k get po -l run=user0 -ojsonpath='{.items[0].metadata.name}'):/root/
## inside use0:
# . hack.sh ; save-functions

install-bashrc() {
  ## !!! NOTE: this should be run in workshop namespace
  ## appned this single line to the end of ~/.bashrc :
  ## echo 'curl -sLo /tmp/functions.sh http://presenter/functions.sh && . /tmp/functions.sh
  for d in $(kubectl get deployment -o name -l user) ; do
    echo "---> $d"
    kubectl exec $d -it -- bash -xc "echo 'curl -sLo /tmp/functions.sh http://presenter/functions.sh && . /tmp/functions.sh' >> /root/.bashrc"
  done
}

hint() {
 curl -s http://presenter/.bash_history | tail -${1:-1}
}

debug() {
    if ((DEBUG)); then
       echo "===> [${FUNCNAME[1]}] $*" 1>&2
    fi
}
save-functions() {
    declare desc="saves all bash function into a file"
    : ${WEBDAVURL:=presenter}

    debug $desc
    declare -f > $HOME/functions.sh
    declare -f > $HOME/public/functions.sh

    echo download it from http://${WEBDAVURL}/functions.sh
}

main() {
  # if last arg is -d sets DEBUG
  [[ ${@:$#} =~ -d ]] && { set -- "${@:1:$(($#-1))}" ; DEBUG=1 ; } || :

  if [[ $1 =~ :: ]]; then
    debug DIRECT-COMMAND  ...
    command=${1#::}
    shift
    $command "$@"
  else
    debug default-command
    save-functions
  fi
}

fixdns_() {
  cat >/etc/resolv.conf <<EOF
search $NS.svc.cluster.local workshop.svc.cluster.local svc.cluster.local cluster.local europe-west3-b.c.cs-k8s.internal c.cs-k8s.internal google.internal
nameserver 10.88.0.10
EOF
}

nodeports ()
{
    echo "===> NodePort services:";
    kubectl get svc -o jsonpath="{range .items[?(.spec.type == 'NodePort')]} {.metadata.name} -> http://n1.k8z.eu:{.spec.ports[0].nodePort} {'\n'}{end}";
    echo
}

install-envsubst() {
  type envsubst &> /dev/null || apt-get install -y gettext-base
}

diffp() {
  declare desc="diff local file with presenter version"
  declare file=${1}
  : ${file:? required}
  shift
  : ${WEBDAVURL:=presenter}

  fullpath=$(readlink -f $file)
  url=http://${WEBDAVURL}${fullpath#$HOME}

  diff $@ $file <(curl -s http://${WEBDAVURL}${fullpath#$HOME})

}

distribute-file() {
    declare desc="distributes a local file via webdav"
    declare file=${1}
    : ${WEBDAVURL:=presenter}

    : ${file:? required}
    debug ${desc} : ${file}

    fullpath=$(readlink -f $file)
    url=http://${WEBDAVURL}${fullpath#$HOME}
    debug $url

    #type envsubst &> /dev/null || apt-get install -y gettext-base
    cat > $HOME/eval <<EOF
    curl -s $url | envsubst | kubectl apply -f -
EOF
}

install-kubeval() {
  export KUBEVAL_SCHEMA_LOCATION=https://raw.githubusercontent.com/yannh/kubernetes-json-schema/master
  curl -sL https://github.com/instrumenta/kubeval/releases/latest/download/kubeval-$(uname)-amd64.tar.gz | tar -C /usr/local/bin -xz kubeval
}

install-k9s() {
  curl -sL https://github.com/derailed/k9s/releases/download/v0.24.2/k9s_Linux_x86_64.tar.gz | tar -xz -C /usr/local/bin/ k9s

  kubectl config set-cluster local --server https://kubernetes.default --insecure-skip-tls-verify
  kubectl config set-credentials token --token $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
  kubectl config set-context training --user token --cluster local --namespace $NS
  kubectl config use-context training
}

krew-lly(){
  kubectl krew index add lly https://github.com/lalyos/kubectl-ing \
  ;kubectl krew install lly/ing
}

krew-examples() {
  kubectl krew index add cs https://github.com/ContainerSolutions/kubernetes-examples.git
  kubectl krew install cs/examples
}

steal() {
  declare desc="interactively (select) steals yaml files from presenter via webdav"
  select f in $(curl -s presenter|sed 's/<D/\n<D/g'|sed -n '/href/ s/<[^>]*>//gp'|sort|grep yaml);
  do
      curl presenter/${f};
      break;
  done
}

zz() {
    history -p '!!' | tee $HOME/eval | tee $HOME/public/eval
}

lazy() {
  declare desc="downloads a file from master session, and evals it"

  curl -s http://presenter/eval | BASH_ENV=<(echo alias k=kubectl) bash -O expand_aliases -x
}

load-functions() {
    curl -sLo /tmp/functions.sh http://presenter/functions.sh
    . /tmp/functions.sh
    echo "---> functions loaded ..." 1>&2
}

echo "---> $BASH_SOURCE reloaded ..." 1>&2

alias r=". $HOME/hack.sh"
alias rr=". $HOME/hack.sh; save-functions"

[[ "$0" == "$BASH_SOURCE" ]] && main "$@" || true