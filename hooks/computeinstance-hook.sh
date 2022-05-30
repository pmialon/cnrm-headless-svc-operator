#!/usr/bin/env bash

DEBUG=${DEBUG:=false}

source /hooks/common/functions

if [[ $1 == "--config" ]] ; then
  cat <<EOF
configVersion: v1
kubernetes:
- apiVersion: compute.cnrm.cloud.google.com/v1beta1
  kind: ComputeInstance
  executeHookOnEvent: ["Added", "Modified", "Deleted"]
  namespace:
    nameSelector:
      matchNames: ["${NAMESPACE}"]
EOF
else
  [ $DEBUG = true ] && cp $BINDING_CONTEXT_PATH /tmp/
  [ $DEBUG = true ] && echo "BINDING_CONTEXT_PATH $BINDING_CONTEXT_PATH"
  type=$(jq -r .[0].type $BINDING_CONTEXT_PATH)

  case $type in
    Synchronization)
      for i in $(seq 0 $(jq -r '.[].objects | length - 1' $BINDING_CONTEXT_PATH))
      do
        name=$(jq -r .[0].objects[$i].object.metadata.name $BINDING_CONTEXT_PATH)
        status=$(jq -r ".[0].objects[$i].object.status.conditions[] | select(.type | contains (\"Ready\")) | .status" $BINDING_CONTEXT_PATH)

        if [[ $status == "True" ]] ; then
          host=$(jq -r .[0].objects[$i].object.spec.networkInterface[0].networkIpRef.external $BINDING_CONTEXT_PATH)
          apply::svc ComputeInstance $name 80
          apply::ep ComputeInstance $name 80 $host
        else
          [ $DEBUG = true ] && echo "Resource is not ready: Synchronization :: $name"
        fi

        garbage::collection ComputeInstance
      done
      ;;
    Event)
      for i in $(seq 0 $(jq -r '. | length - 1' $BINDING_CONTEXT_PATH))
      do
        watchEvent=$(jq -r ".[$i].watchEvent" $BINDING_CONTEXT_PATH)
        case $watchEvent in
          Added|Modified)
            name=$(jq -r .[$i].object.metadata.name $BINDING_CONTEXT_PATH)
            if [[ ! $(jq -r ".[$i].object.status.conditions" $BINDING_CONTEXT_PATH) == null ]] ; then
              status=$(jq -r ".[$i].object.status.conditions[] | select(.type | contains (\"Ready\")) | .status" $BINDING_CONTEXT_PATH)
              if [[ $status == "True" ]] ; then
                host=$(jq -r .[$i].object.spec.networkInterface[0].networkIpRef.external $BINDING_CONTEXT_PATH)
                apply::svc ComputeInstance $name 80
                apply::ep ComputeInstance $name 80 $host
                [ $DEBUG = true ] && echo "Create ComputeInstance: $watchEvent :: $name - $host - $port"
              else
                [ $DEBUG = true ] && echo "Resource is not ready: $watchEvent :: $name"
              fi
            else
              [ $DEBUG = true ] && echo "Resource has no status defined"
            fi
            ;;
          Deleted)
            name=$(jq -r .[$i].object.metadata.name $BINDING_CONTEXT_PATH)
            kubectl delete ep $name
            kubectl delete svc $name
            [ $DEBUG = true ] && echo "Delete the resource: $watchEvent :: $name"
            ;;
          *)
            [ $DEBUG = true ] && echo "This Event type **${watchEvent}** is not supported"
            ;;
        esac
      done
      ;;
    *)
      [ $DEBUG = true ] && echo "Nothing to be done for $type"
      ;;
  esac
  exit 0
fi
