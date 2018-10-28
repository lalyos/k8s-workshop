export EXTERNAL=$(curl -s http://metadata/computeMetadata/v1beta1/instance/network-interfaces/0/access-configs/0/external-ip)

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
  <SOME_COMMAND> | ${FUNCNAME[0]}
USAGE
    fi
  else
    kubectl create configmap ssh --from-literal="key=$(cat)"  --dry-run -o yaml | kubectl apply -f -  
  fi
}

list-common-env() {
  kubectl get configmaps -n default common -o go-template='{{range $k,$v := .data}}{{printf "export CM_%s=%s\n" $k $v}}{{end}}'
}

common-env() {
  eval $(list-common-env)
  printenv | grep CM_
}

zed-usage() {
  cat <<USAGE
###########################################
# - install as a Chrome App:
#  https://chrome.google.com/webstore/detail/zed-code-editor/pfmjnmeipppmcebplngmhfkleiinphhp?hl=en
# 
# - click on "Remote Folder"
###########################################
USAGE
  ZED_USAGE_SHOWN=1
}

zed() {
  if pgrep zed &> /dev/null; then
    echo zed is already running, to stop: pkill zed
    return
  fi

  [[ "$ZED_USAGE_SHOWN" ]] || zed-usage

  if ! [[ "$CM_ZED" ]]; then
    echo 'CM_ZED env variable is required. Use: common-env'
    return
  fi

  zedrem -u $CM_ZED &
}

cd

alias motd='cat /etc/motd'
motd