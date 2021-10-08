#!/usr/bin/env bash

DEBUG=${DEBUG:=false}

source /hooks/common/functions

if [[ $1 == "--config" ]] ; then
  cat <<EOF
configVersion: v1
kubernetes:
- apiVersion: redis.cnrm.cloud.google.com/v1beta1
  kind: RedisInstance
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
          host=$(jq -r .[0].objects[$i].object.status.host $BINDING_CONTEXT_PATH)
          port=$(jq -r .[0].objects[$i].object.status.port $BINDING_CONTEXT_PATH)
          apply::svc RedisInstance $name $port
          apply::ep RedisInstance $name $port $host
        else
          [ $DEBUG = true ] && echo "Resource is not ready: Synchronization :: $name"
        fi

        garbage::collection RedisInstance
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
                host=$(jq -r .[$i].object.status.host $BINDING_CONTEXT_PATH)
                port=$(jq -r .[$i].object.status.port $BINDING_CONTEXT_PATH)
                apply::svc RedisInstance $name $port
                apply::ep RedisInstance $name $port $host
                [ $DEBUG = true ] && echo "Create RedisInstance: $watchEvent :: $name - $host - $port"
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
