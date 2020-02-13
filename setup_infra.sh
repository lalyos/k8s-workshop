PROJECT_ID=${PROJECT_ID:-"container-solutions-workshops"}
CLUSTER_NAME=${CLUSTER_NAME:-"workshop-marek-2"}
ZONE=${ZONE:-"europe-west3-b"}

gcloud beta container \
      --project "${PROJECT_ID}" \
      clusters create "${CLUSTER_NAME}" \
      --zone "${ZONE}" \
      --username "admin" \
      --machine-type "n1-standard-2" \
      --image-type "UBUNTU" \
      --disk-type "pd-standard" \
      --disk-size "100" \
      --metadata disable-legacy-endpoints=true \
      --scopes "https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append" \
      --num-nodes "3" \
      --no-enable-cloud-logging \
      --no-enable-cloud-monitoring \
      --no-enable-ip-alias \
      --network "projects/container-solutions-workshops/global/networks/default" \
      --addons HorizontalPodAutoscaling,Istio \
      --no-enable-autoupgrade \
      --enable-autorepair

gcloud  container clusters get-credentials "${CLUSTER_NAME}" --project "${PROJECT_ID}" --zone "${ZONE}"
