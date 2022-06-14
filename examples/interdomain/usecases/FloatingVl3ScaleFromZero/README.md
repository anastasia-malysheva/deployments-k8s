# Floating interdomain with vL3 autoscale example



## Requires
Make sure that you have completed steps from [interdomain](../../)

## Run

**1. Deploy**

1.1. Switch context to the *floating domain*.
```bash
export KUBECONFIG=$KUBECONFIG3
```
1.2. Start **vl3 ipam** and register **vl3 network service** in the *floaing domain* and wait them to be ready.

Note: *By default we're using ipam prefix is `169.254.0.0/16` and client prefix len is `24`. We also have two vl3 nses in this example. So we are expect to have a two vl3 addresses: `169.254.0.0` and `169.254.1.0` that should be accessible by each client.*

```bash
kubectl apply -k ./cluster3
```

1.3 Switch context to the *cluster1*.

```bash
export KUBECONFIG=$KUBECONFIG1
```

1.4 Register autoscale network service, start client and supplier:

```bash
kubectl apply -k ./cluster1
```
1.5 Wait for applications ready:
```bash
kubectl wait -n ns-vl3-interdomain --for=condition=ready --timeout=1m pod -l app=nse-supplier-k8s
kubectl wait -n ns-vl3-interdomain --for=condition=ready --timeout=1m pod -l app=nsc-kernel
kubectl wait -n ns-vl3-interdomain --for=condition=ready --timeout=1m pod -l app=nse-vl3-vpp
```

1.6 Switch context to the *cluster2* and start autoscale, supplier and client.

```bash
export KUBECONFIG=$KUBECONFIG2
kubectl apply -k ./cluster2
```
1.7 Wait for applications ready:
```bash
kubectl wait -n ns-vl3-interdomain --for=condition=ready --timeout=1m pod -l app=nse-supplier-k8s
kubectl wait -n ns-vl3-interdomain --for=condition=ready --timeout=1m pod -l app=nsc-kernel
kubectl wait -n ns-vl3-interdomain --for=condition=ready --timeout=1m pod -l app=nse-vl3-vpp
```

**2. Get assigned IP addresses**

2.1. Get assigned IP address from vl3-nse for the client from the *cluster2*

```bash
nsc2=$(kubectl get pods -l app=nsc-kernel -n ns-vl3-interdomain --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}')
ipAddr2=$(kubectl exec -n ns-vl3-interdomain  $nsc2 -- ifconfig nsm-1)
ipAddr2=$(echo $ipAddr | grep -Eo 'inet addr:[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}'| cut -c 11-)
```

2.2. Switch context to the *cluster1*.

```bash
export KUBECONFIG=$KUBECONFIG1
```

2.3. Get assigned IP address from vl3-nse for the client from the *cluster1*

```bash
nsc1=$(kubectl get pods -l app=nsc-kernel -n ns-vl3-interdomain --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}')
ipAddr1=$(kubectl exec -n ns-vl3-interdomain $nsc1 -- ifconfig nsm-1)
ipAddr1=$(echo $ipAddr | grep -Eo 'inet addr:[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}'| cut -c 11-)
```

**3. Check connectivity**

3.1. Ping remote client:
```bash
kubectl exec $nsc1 -n ns-vl3-interdomain -- ping -c 4 $ipAddr2
```

3.2. Ping vl3 nses:
```bash
kubectl exec $nsc1 -n ns-vl3-interdomain -- ping -c 4 169.254.0.0
kubectl exec $nsc1 -n ns-vl3-interdomain -- ping -c 4 169.254.1.0
```


3.3. Switch to the *cluster2*
```bash
export KUBECONFIG=$KUBECONFIG2
```


3.4. Ping remote client:
```bash
kubectl exec $nsc2 -n ns-vl3-interdomain -- ping -c 4 $ipAddr1
```

3.5. Ping vl3 nses:
```bash
kubectl exec $nsc2 -n ns-vl3-interdomain -- ping -c 4 169.254.0.0
kubectl exec $nsc2 -n ns-vl3-interdomain -- ping -c 4 169.254.1.0
```

## Cleanup

1. Cleanup floating domain:

```bash
export KUBECONFIG=$KUBECONFIG3 kubectl delete -k ./cluster3
```

2. Cleanup cluster2 domain:

```bash
export KUBECONFIG=$KUBECONFIG2 kubectl delete -k ./cluster2
```

3. Cleanup cluster1 domain:

```bash
export KUBECONFIG=$KUBECONFIG1 kubectl delete -k ./cluster1
```
