# Test kernel to remote vlan connection

This example shows that NSCs can connect to a cluster external entity by a VLAN interface. The clients in this topology are running in different k8s namespaces and connecting to dfferent services provided by three endpoint.
NSCs are using the `kernel` mechanism to connect to local forwarder.
Forwarders are using the `vlan` remote mechanism to set up the VLAN interface.

## Requires

Make sure that you have completed steps from [remotevlan](../../remotevlan) setup.

## Run

Create test namespace:

```bash
kubectl create ns ns-kernel2vlan-multins-1
kubectl create ns ns-kernel2vlan-multins-2
```

Create example directories to separate deployments:

```bash
mkdir -p ns-1 ns-2
```

Create first client:

```bash
cat > ns-1/first-client.yaml <<EOF
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: alpine-1
  labels:
    app: alpine-1
spec:
  replicas: 2
  selector:
    matchLabels:
      app: alpine-1
  template:
    metadata:
      labels:
        app: alpine-1
      annotations:
        networkservicemesh.io: kernel://private-bridge.ns-kernel2vlan-multins-1/nsm-1
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - alpine-1
            topologyKey: "kubernetes.io/hostname"
      containers:
      - name: alpine
        image: alpine:3.15.0
        imagePullPolicy: IfNotPresent
        stdin: true
        tty: true
EOF
```

Create NSE patch:

```bash
cat > ns-1/patch-nse.yaml <<EOF
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nse-remote-vlan
spec:
  template:
    spec:
      containers:
      - name: nse
        env:
          - name: NSM_CONNECT_TO
            value: "registry.nsm-system:5002"
          - name: NSM_SERVICES
            value: "private-bridge.ns-kernel2vlan-multins-1 { vlan: 0; via: gw1 }"
          - name: NSM_CIDR_PREFIX
            value: 172.10.1.0/24
EOF
```

Create customization file:

```bash
cat > ns-1/kustomization.yaml <<EOF
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: ns-kernel2vlan-multins-1

resources:
- first-client.yaml

bases:
- ../../../../apps/nse-remote-vlan

patchesStrategicMerge:
- patch-nse.yaml
EOF
```

Deployment in first namespace

```bash
 kubectl apply -k ./ns-1
```

Create second and third client:

```bash
cat > ns-2/second-client.yaml <<EOF
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: alpine-2
  labels:
    app: alpine-2
spec:
  replicas: 2
  selector:
    matchLabels:
      app: alpine-2
  template:
    metadata:
      labels:
        app: alpine-2
      annotations:
        networkservicemesh.io: kernel://blue-bridge.ns-kernel2vlan-multins-2/nsm-1
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - alpine-2
            topologyKey: "kubernetes.io/hostname"
      containers:
      - name: alpine
        image: alpine:3.15.0
        imagePullPolicy: IfNotPresent
        stdin: true
        tty: true
EOF
cat > ns-2/third-client.yaml <<EOF
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: alpine-3
  labels:
    app: alpine-3
spec:
  replicas: 2
  selector:
    matchLabels:
      app: alpine-3
  template:
    metadata:
      labels:
        app: alpine-3
      annotations:
        networkservicemesh.io: kernel://green-bridge.ns-kernel2vlan-multins-2/nsm-1
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - alpine-3
            topologyKey: "kubernetes.io/hostname"
      containers:
      - name: alpine
        image: alpine:3.15.0
        imagePullPolicy: IfNotPresent
        stdin: true
        tty: true
EOF
```

Create NSE patch:

```bash
cat > ns-2/patch-nse.yaml <<EOF
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nse-remote-vlan
spec:
  template:
    spec:
      containers:
      - name: nse
        env:
          - name: NSM_CONNECT_TO
            value: "registry.nsm-system:5002"
          - name: NSM_SERVICES
            value: "blue-bridge.ns-kernel2vlan-multins-2 { vlan: 300; via: gw1 }, green-bridge.ns-kernel2vlan-multins-2 { vlan: 400; via: gw1 }"
          - name: NSM_CIDR_PREFIX
            value: 172.10.2.0/24
EOF
```

Create customization file:

```bash
cat > ns-2/kustomization.yaml <<EOF
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: ns-kernel2vlan-multins-2

resources:
- second-client.yaml
- third-client.yaml

bases:
- https://github.com/networkservicemesh/deployments-k8s/apps/nse-remote-vlan?ref=58a90eb58a3e06f02cbd99c221b35327488025cc

nameSuffix: -bg

patchesStrategicMerge:
- patch-nse.yaml
EOF
```

Deployment in second namespace:

```bash
 kubectl apply -k ./ns-2
```

Create the last client:

```bash
cat > client.yaml <<EOF
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: alpine-4
  labels:
    app: alpine-4
spec:
  replicas: 2
  selector:
    matchLabels:
      app: alpine-4
  template:
    metadata:
      labels:
        app: alpine-4
      annotations:
        networkservicemesh.io: kernel://finance-bridge/nsm-1
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - alpine-4
            topologyKey: "kubernetes.io/hostname"
      containers:
      - name: alpine
        image: alpine:3.15.0
        imagePullPolicy: IfNotPresent
        stdin: true
        tty: true
EOF
```

Deploy the last client

```bash
 kubectl apply -n nsm-system -f client.yaml
```

Wait for applications ready:

```bash
kubectl -n ns-kernel2vlan-multins-1 wait --for=condition=ready --timeout=1m pod -l app=nse-remote-vlan
```

```bash
kubectl -n ns-kernel2vlan-multins-1 wait --for=condition=ready --timeout=1m pod -l app=alpine-1
```

```bash
kubectl -n ns-kernel2vlan-multins-2 wait --for=condition=ready --timeout=1m pod -l app=nse-remote-vlan
```

```bash
kubectl -n ns-kernel2vlan-multins-2 wait --for=condition=ready --timeout=1m pod -l app=alpine-2
```

```bash
kubectl -n ns-kernel2vlan-multins-2 wait --for=condition=ready --timeout=1m pod -l app=alpine-3
```

```bash
kubectl -n nsm-system wait --for=condition=ready --timeout=1m pod -l app=alpine-4
```

Create a docker image for test external connections:

```bash
cat > Dockerfile <<EOF
FROM alpine:3.15.0

RUN apk add ethtool

ENTRYPOINT [ "tail", "-f", "/dev/null" ]
EOF
docker build . -t rvm-tester
```

Setup a docker container for traffic test:

```bash
docker run --cap-add=NET_ADMIN --rm -d --network bridge-2 --name rvm-tester rvm-tester tail -f /dev/null
docker exec rvm-tester ip link set eth0 down
docker exec rvm-tester ip link add link eth0 name eth0.100 type vlan id 100
docker exec rvm-tester ip link add link eth0 name eth0.300 type vlan id 300
docker exec rvm-tester ip link add link eth0 name eth0.400 type vlan id 400
docker exec rvm-tester ip link set eth0 up
docker exec rvm-tester ip addr add 172.10.0.254/24 dev eth0.100
docker exec rvm-tester ip addr add 172.10.1.254/24 dev eth0
docker exec rvm-tester ip addr add 172.10.2.254/24 dev eth0.300
docker exec rvm-tester ip addr add 172.10.2.253/24 dev eth0.400
docker exec rvm-tester ethtool -K eth0 tx off
```

Get the NSC pods from first k8s namespace:

```bash
NSCS=($(kubectl get pods -l app=alpine-1 -n ns-kernel2vlan-multins-1 --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}'))
```

Get the IP addresses for NSCs from first k8s namespace:

```bash
declare -A IP_ADDR
for nsc in "${NSCS[@]}"
do
  IP_ADDR[$nsc]=$(kubectl exec ${nsc} -n ns-kernel2vlan-multins-1 -c alpine -- ip -4 addr show nsm-1 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
done
```

Check first vlan from tester container:

```bash
status=0
for nsc in "${NSCS[@]}"
do
  for vlan_if_name in eth0.100 eth0.300 eth0.400
  do
    docker exec rvm-tester ping -w 1 -c 1 ${IP_ADDR[$nsc]} -I ${vlan_if_name}
    if test $? -eq 0
      then
        status=2
    fi
  done
  docker exec rvm-tester ping -c 1 ${IP_ADDR[$nsc]} -I eth0
  if test $? -ne 0
    then
      status=1
  fi
done
if test ${status} -eq 1
  then
    false
fi
```

Get the NSC pods from second k8s namespace:

```bash
NSCS_BLUE=($(kubectl get pods -l app=alpine-2 -n ns-kernel2vlan-multins-2 --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}'))
NSCS_GREEN=($(kubectl get pods -l app=alpine-3 -n ns-kernel2vlan-multins-2 --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}'))
```

Get the IP addresses for NSCs from second k8s namespace:

```bash
declare -A IP_ADDR_BLUE
for nsc in "${NSCS_BLUE[@]}"
do
  IP_ADDR_BLUE[$nsc]=$(kubectl exec ${nsc} -n ns-kernel2vlan-multins-2 -c alpine -- ip -4 addr show nsm-1 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
done
declare -A IP_ADDR_GREEN
for nsc in "${NSCS_GREEN[@]}"
do
  IP_ADDR_GREEN[$nsc]=$(kubectl exec ${nsc} -n ns-kernel2vlan-multins-2 -c alpine -- ip -4 addr show nsm-1 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
done
```

Check vlan (300 and 400) from tester container:

```bash
status=0
for nsc in "${NSCS_BLUE[@]}"
do
  for vlan_if_name in eth0.100 eth0 eth0.400
  do
    docker exec rvm-tester ping -w 1 -c 1 ${IP_ADDR_BLUE[$nsc]} -I ${vlan_if_name}
    if test $? -eq 0
      then
        status=2
    fi
  done
  docker exec rvm-tester ping -c 1 ${IP_ADDR_BLUE[$nsc]} -I eth0.300
  if test $? -ne 0
    then
      status=1
  fi
done
for nsc in "${NSCS_GREEN[@]}"
do
  for vlan_if_name in eth0.100 eth0 eth0.300
  do
    docker exec rvm-tester ping -w 1 -c 1 ${IP_ADDR_GREEN[$nsc]} -I ${vlan_if_name}
    if test $? -eq 0
      then
        status=2
    fi
  done
  docker exec rvm-tester ping -c 1 ${IP_ADDR_GREEN[$nsc]} -I eth0.400
  if test $? -ne 0
    then
      status=1
  fi
done
if test ${status} -eq 1
  then
    false
fi
```

Get the NSC pods from nsm-system k8s namespace:

```bash
NSCS=($(kubectl get pods -l app=alpine-4 -n nsm-system --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}'))
```

Get the IP addresses for NSCs from first k8s namespace:

```bash
declare -A IP_ADDR
for nsc in "${NSCS[@]}"
do
  IP_ADDR[$nsc]=$(kubectl exec ${nsc} -n nsm-system -c alpine -- ip -4 addr show nsm-1 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
done
```

Check first vlan from tester container:

```bash
status=0
for nsc in "${NSCS[@]}"
do
  for vlan_if_name in eth0 eth0.300 eth0.400
  do
    docker exec rvm-tester ping -w 1 -c 1 ${IP_ADDR[$nsc]} -I ${vlan_if_name}
    if test $? -eq 0
      then
        status=2
    fi
  done
  docker exec rvm-tester ping -c 1 ${IP_ADDR[$nsc]} -I eth0.100
  if test $? -ne 0
    then
      status=1
  fi
done
if test ${status} -eq 1
  then
    false
fi
```

## Cleanup

Delete the tester container and image:

```bash
docker stop rvm-tester && \
docker image rm rvm-tester:latest
true
```

Delete the last client:

```bash
kubectl delete --namespace=nsm-system -f client.yaml
```

Delete the test namespace:

```bash
kubectl delete ns ns-kernel2vlan-multins-1
```

```bash
kubectl delete ns ns-kernel2vlan-multins-2
```

Delete the directories:

```bash
rm -rf ns-1 ns-2
```
