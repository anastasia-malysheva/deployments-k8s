# Floating interdomain kernel2vxlan2kernel example



## Requires
3 clusters
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

