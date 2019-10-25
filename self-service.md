previously session urls contained a random prefix (for security), so it was
slow to distribute session urls to participants. The solution was a self-service
protal, where a trainee could log in via OAuth2 and grab an unassigned session.

Since we use basic auth now, the urls are simple (like userX.domain.com).
Of course now you have to distribute the credentials, but hey you can use
the same password for everybody ;)

## Self Service portal - depricated

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
