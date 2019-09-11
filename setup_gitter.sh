#!/bin/bash

# 
export workshopNamespace=workshop
export gitterRoom="ContainerSolutions/warsaw-workshop"

echo "Import gitter keys from gitter.env"
source gitter.env
echo "Create secrets"
kubectl create secret generic gitter \
  --from-literal=GITTER_OAUTH_KEY=$GITTER_OAUTH_KEY \
  --from-literal=GITTER_OAUTH_SECRET=$GITTER_OAUTH_SECRET

curl -sL https://raw.githubusercontent.com/lalyos/gitter-scripter/master/gitter-template.yaml \
  | envsubst \
  | kubectl apply -f -

kubectl patch deployments gitter --patch '{"spec":{"template":{"spec":{"$setElementOrder/containers":[{"name":"gitter"}],"containers":[{"$setElementOrder/env":[{"name":"GITTER_ROOM_NAME"},{"name":"DOMAIN"}],"env":[{"name":"GITTER_ROOM_NAME","value":"'${gitterRoom}'"}],"name":"gitter"}]}}}}'

