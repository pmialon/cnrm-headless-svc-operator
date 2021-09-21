# cnrm-headless-svc-operator
Operator that creates eponymous headless kubernetes services to config-connector resources

This operator use [shell-operator](https://github.com/flant/shell-operator) to sync [Config Connector](https://cloud.google.com/config-connector/docs/overview)

This allow to create references in an application that will be stable accross environments.

For example, if you create a SQLInstance named *mydb*, in your application configuration file, you can use *mydb* as host instead of the SQLInstance IP.

By design we choose to operate on a single namespace, to limit the blast radius in case of an error. So you will have to deploy the operator in each namespace you want to operate.

This operator needs to be service and endpoint editor. It will have the ability to modify every services or endpoint in the namespace it will be deployed.

Only [RedisInstance](https://cloud.google.com/config-connector/docs/reference/resource-docs/redis/redisinstance)  and [SQLInstance](https://cloud.google.com/config-connector/docs/reference/resource-docs/sql/sqlinstance) are now supported.

## Quickstart

```
kubectl apply -f https://raw.githubusercontent.com/pmialon/cnrm-headless-svc-operator/main/kustomize/install.yaml
```

See the created services:
```
kubectl get svc -l managed.by=cnrm-headless-svc -w
```

## Build instructions

```
docker build -t "registry.mycompany.com/shell-operator:cnrm-headless-svc-operator" .
```

```
docker push "registry.mycompany.com/shell-operator:cnrm-headless-svc-operator"
```
