apply::svc() {

(cat <<EOF
apiVersion: v1
kind: Service
metadata:
  name: $2
  labels:
    app.kubernetes.io/managed-by: cnrm-headless-svc
    kind: $1
spec:
  clusterIP: None
  ports:
    - protocol: TCP
      port: $3
      targetPort: $3
EOF
) | kubectl apply -f -

}


apply::ep() {

(cat << EOF
apiVersion: v1
kind: Endpoints
metadata:
  name: $2
  labels:
    app.kubernetes.io/managed-by: cnrm-headless-svc
    kind: $1
subsets:
  - addresses:
      - ip: $4
    ports:
      - port: $3
        protocol: TCP
EOF
) | kubectl apply -f -

}


garbage::collection() {

for svc in $(kubectl get svc -l "kind=$1,app.kubernetes.io/managed-by=cnrm-headless-svc" -o jsonpath='{.items[*].metadata.name}')
do
  if [[ -z $(jq -r ".[0].objects[] | select (.object.metadata.name | contains(\"${svc}\"))" $BINDING_CONTEXT_PATH) ]] ; then
    kubectl delete svc ${svc}
    kubectl delete ep ${svc}
  fi
done
}
