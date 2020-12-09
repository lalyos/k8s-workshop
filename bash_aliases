export EXTERNAL=$(curl -s http://metadata/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip -H 'Metadata-Flavor: Google')

export NODE_IP=$(kubectl get no $NODE -o jsonpath='{.status.addresses[1].address}')

. /etc/bash_completion

ssh-pubkey() {
  declare githubUser=${1}

  if [ -t 0 ]; then
    if [[ $githubUser ]]; then
      curl -sL https://github.com/${githubUser}.keys|kubectl create configmap ssh --from-literal="key=$(cat)"  --dry-run -o yaml | kubectl apply -f -
    else
      cat << USAGE
Configures ssh public key from stdin or github
usage:
  ${FUNCNAME[0]} <GITHUB_USERNAME>
or
  <SOME_COMMAND_PRINTS_PUBKEY> | ${FUNCNAME[0]}
USAGE
      return
    fi
  else
    kubectl create configmap ssh --from-literal="key=$(cat)"  --dry-run -o yaml | kubectl apply -f -
  fi

  sshPort=${CM_SSH_PORT:=$(kubectl get svc sshfront -n workshop -o jsonpath='{.spec.ports[0].nodePort}')}
  sshHost=${CM_SSH_DOMAIN:=$(kubectl get no -o jsonpath='{.items[0].status.addresses[1].address}')}
  echo -e "You can now connect via:\n  ssh ${NS}@${sshHost} -p ${sshPort}"
}

nodeports() {
  echo "===> NodePort services:"
  kubectl get svc -o jsonpath="{range .items[?(.spec.type == 'NodePort')]} {.metadata.name} -> http://$EXTERNAL:{.spec.ports[0].nodePort} {'\n'}{end}"
  echo
}

ingresses() {
  echo "===> Ingresses:"
  kubectl get ing -o jsonpath='{range .items[*]} http://{.spec.rules[0].host}{"\n"}{end}'
  echo
}

svc() {
 nodeports
 ingresses
}

list-common-env() {
  kubectl get configmaps -n default common -o go-template='{{range $k,$v := .data}}{{printf "export CM_%s=%s\n" $k $v}}{{end}}'
}

common-env() {
  eval $(list-common-env)
  printenv | grep CM_
}

fix-kubectl-autocomp() {
  [[ $KUBECTL_AUTOCOMP_FIXED ]] || source <(curl -Ls http://bit.ly/kubectl-fix)
}

prompt() {
  if grep promptline -q <<< "$PROMPT_COMMAND"; then
    unset PROMPT_COMMAND
    PS1=${PS1_ORIG:-$}
  else
	  PS1_ORIG="$PS1"
    . ~/.prompt.sh
  fi
}
prompt

cd
common-env &> /dev/null

kubectl config set-context default --namespace=$NS
kubectl config use-context default

fix-kubectl-autocomp

alias motd='cat /etc/motd'
alias help='{ command help; motd; }'

## kubernetes
alias k='kubectl'
alias kal='kubectl get all'
alias kg='kubectl get'
alias kgy='kubectl get -o yaml'
alias kgs='kubectl get -n kube-system'

alias aliascomp='complete -F _complete_alias'
for a in k kg kal kgy kgs; do
  aliascomp $a
done
motd