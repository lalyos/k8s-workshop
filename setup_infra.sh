PROJECT_ID=${PROJECT_ID:-"container-solutions-workshops"}
CLUSTER_NAME=${CLUSTER_NAME:-"workshop"}
ZONE=${ZONE:-"europe-west3-b"}

gcloud beta container \
      --project "${PROJECT_ID}" \
      clusters create "${CLUSTER_NAME}" \
      --zone "${ZONE}" \
      --username "admin" \
      --machine-type "n1-standard-4" \
      --image-type "UBUNTU" \
      --disk-type "pd-standard" \
      --disk-size "100" \
      --metadata disable-legacy-endpoints=true \
      --scopes "https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append" \
      --num-nodes "3" \
      --enable-cloud-logging \
      --enable-cloud-monitoring \
      --no-enable-ip-alias \
      --network "projects/container-solutions-workshops/global/networks/default" \
      --addons HorizontalPodAutoscaling \
      --no-enable-autoupgrade \
      --enable-autorepair 
#cloud beta container \
#      --project "container-solutions-workshops" \
#      node-pools create "pool-1" \
#      --cluster "workshop" \
#      --machine-type "n1-standard-2" \
#      --image-type "UBUNTU" \
#      --disk-type "pd-standard" \
#      --disk-size "100" \
#      --metadata disable-legacy-endpoints=true \
#      --scopes "https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append" \
#      --preemptible \
#      --num-nodes "3" \
#      --no-enable-autoupgrade \
#      --enable-autorepairi \
#      --zone "europe-west3-b"
