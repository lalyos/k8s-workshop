previously session urls contained a random prefix (for security), so it was
slow to distribute session urls to participants. The solution was a self-service
protal, where a trainee could log in via OAuth2 and grab an unassigned session.

Since we use basic auth now, the urls are simple (like userX.domain.com).
Of course now you have to distribute the credentials, but hey you can use
the same password for everybody ;)

## Self Service portal v2 (WIP) 

After creating the user sessions, its hard to distribute/assign the session urls.

There is a small gitter authentication based web app, where participants can get an unused
session assigned to them.
More details and the process toget GITTER credentials is described: https://github.com/lalyos/gitter-scripter

Run this line to setup gitter, don't forget to update .profile with credentials
```bash
setup-gitter
```

The users can self service at: http://session.${domain}
