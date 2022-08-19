# NSM + Consul + vl3 interdomain example over kind clusters

This example shows how Consul can be used over NSM with vl3. 


## Requires

- [Load balancer](../loadbalancer)
- [Interdomain DNS](../dns)
- [Interdomain spire](../spire)
- [Interdomain nsm](../nsm)


## Run

References:
https://learn.hashicorp.com/tutorials/consul/deployment-guide?in=consul/production-deploy
https://learn.hashicorp.com/tutorials/consul/tls-encryption-secure
https://learn.hashicorp.com/tutorials/consul/service-mesh-with-envoy-proxy?in=consul/developer-mesh

Start vl3, install Consul control plane and counting service on the first cluster
```bash
kubectl --kubeconfig=$KUBECONFIG1 create ns ns-nsm-consul-vl3
kubectl --kubeconfig=$KUBECONFIG1 apply -k ./examples/interdomain/nsm_consul_vl3/cluster1
```
Start vl3, install Consul control plane and counting service on the first cluster
```bash
kubectl --kubeconfig=$KUBECONFIG2 create ns nsm-consul-vl3
kubectl --kubeconfig=$KUBECONFIG1 apply -k ./examples/interdomain/nsm_consul_vl3/cluster2
```

Wait for pods to be ready:
```bash
kubectl --kubeconfig=$KUBECONFIG1 wait --for=condition=ready --timeout=5m pod -l app=nse-vl3-vpp -n ns-nsm-consul-vl3
kubectl --kubeconfig=$KUBECONFIG1 wait --for=condition=ready --timeout=5m pod -l app=vl3-ipam -n ns-nsm-consul-vl3
kubectl --kubeconfig=$KUBECONFIG1 wait --for=condition=ready --timeout=1m pod -l name=control-plane -n ns-nsm-consul-vl3
kubectl --kubeconfig=$KUBECONFIG1 wait --for=condition=ready --timeout=1m pod counting -n ns-nsm-consul-vl3
kubectl --kubeconfig=$KUBECONFIG2 wait --for=condition=ready --timeout=5m pod dashboard -n ns-nsm-consul-vl3
```

Run a control plane, install required packages and Consul CP
```bash
export CP=$(kubectl --kubeconfig=$KUBECONFIG1 get pods -l name=control-plane --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}')
kubectl --kubeconfig=$KUBECONFIG1 exec -it ${CP} -c ubuntu -- bash
```

```bash
apt update
apt upgrade -y
```

```bash
apt-get install curl gnupg sudo lsb-release net-tools iproute2 -y
```

```bash
curl --fail --silent --show-error --location https://apt.releases.hashicorp.com/gpg | \
      gpg --dearmor | \
      sudo dd of=/usr/share/keyrings/hashicorp-archive-keyring.gpg
```

```bash
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
 sudo tee -a /etc/apt/sources.list.d/hashicorp.list
```

```bash
sudo apt-get update
sudo apt-get install consul=1.12.0-1
```

(On the control plane pod) Generate the gossip encryption key. Save the output
```bash
ENCRYPTION_KEY=$(consul keygen)
```

(On the control plane pod) Get CP vl3 IP
```bash
CP_IP_VL3_ADDRESS=169.254.0.2
```

(On the control plane pod) Initialize Consul CA
```bash
consul tls ca create /etc/consul.d/
```

(On the control plane pod) Create the server certificates
```bash
consul tls cert create -server -dc dc1 /etc/consul.d/
```

(On the control plane pod) Update control plane configuration. Use here the saved encryption key and CP vl3 IP address
```bash
cat > /etc/consul.d/consul.hcl <<EOF
data_dir = "/opt/consul"
datacenter = "dc1"
encrypt = "${ENCRYPTION_KEY}"
tls {
  defaults {
    ca_file = "/etc/consul.d/consul-agent-ca.pem"
    cert_file = "/etc/consul.d/dc1-server-consul-0.pem"
    key_file = "/etc/consul.d/dc1-server-consul-0-key.pem"
    verify_incoming = true
    verify_outgoing = true
  }
  internal_rpc {
    verify_server_hostname = true
  }
}
auto_encrypt {
  allow_tls = true
}
acl {
  enabled = true
  default_policy = "allow"
  enable_token_persistence = true
}
EOF
```

```bash
cat > /etc/consul.d/server.hcl <<EOF
server = true
bootstrap_expect = 1
bind_addr = "${CP_IP_VL3_ADDRESS}"
connect {
  enabled = true
}

addresses {
  grpc = "127.0.0.1"
}
ports {
  grpc  = 8502
}
EOF
```
(On the control plane pod) Validate the configuration 
```bash
sudo consul validate /etc/consul.d/
```

(On the control plane pod) Start Consul CP
```bash
/usr/bin/consul agent -config-dir=/etc/consul.d/
```

Open new terminal tab and execute new session to the Counting service pod, install required packages and Consul agent
```bash
kubectl --kubeconfig=$KUBECONFIG1 exec -it counting -c ubuntu -- bash
apt update
apt upgrade -y
apt-get install curl gnupg sudo lsb-release iproute2 -y
curl --fail --silent --show-error --location https://apt.releases.hashicorp.com/gpg | \
      gpg --dearmor | \
      sudo dd of=/usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
 sudo tee -a /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update
sudo apt-get install consul=1.12.0-1
```

(On the counting pod) Set the counting  and control plane pods vl3 IP
```bash
CP_IP_VL3_ADDRESS=169.254.0.2
COUNTING_IP_VL3_ADDRESS=169.254.0.3
```

(On the counting pod) Update control plane configuration. Use here the saved encryption key and the Counting service pod vl3 IP address
```bash
cat > /etc/consul.d/consul.hcl <<EOF
data_dir = "/opt/consul"
encrypt = "${ENCRYPTION_KEY}"
tls {
  defaults {
    ca_file = "/etc/consul.d/consul-agent-ca.pem"
    verify_incoming = false
    verify_outgoing = true
  }
  internal_rpc {
    verify_server_hostname = true
  }
}
auto_encrypt {
  tls = true
}
acl {
  enabled = true
  default_policy = "allow"
  enable_token_persistence = true
}
bind_addr = "${COUNTING_IP_VL3_ADDRESS}"
connect {
  enabled = true
}
addresses {
  grpc = "127.0.0.1"
}
ports {
  grpc  = 8502
}
EOF
```

(On the counting pod) Validate the configuration 
```bash
sudo consul validate /etc/consul.d/
```

(On the counting pod) Start Consul agent
```bash
/usr/bin/consul agent -join $CP_IP_VL3_ADDRESS -config-dir=/etc/consul.d/
```

Open new terminal tab and execute new session to the Counting service pod. Create the service definition
```bash
kubectl --kubeconfig=$KUBECONFIG1 exec -it counting -c ubuntu -- bash
mkdir service
cd service
cat > counting.hcl <<EOF
service {
  name = "counting"
  id = "counting-1"
  port = 9001

  connect {
    sidecar_service {}
  }

  check {
    id       = "counting-check"
    http     = "http://localhost:9001/health"
    method   = "GET"
    interval = "1s"
    timeout  = "1s"
  }
}
EOF
```

(On the counting pod) Register the service with Consul
```bash
consul services register counting.hcl
```

(On the counting pod) Install Envoy to use it as sidecar
```bash
curl -L https://func-e.io/install.sh | bash -s -- -b /usr/local/bin
export FUNC_E_PLATFORM=linux/amd64
func-e use 1.22.2
sudo cp ~/.func-e/versions/1.22.2/bin/envoy /usr/bin/
# Check envoy version
```

(On the counting pod) Verify Envoy has been installed 
```bash
envoy --version
```

(On the counting pod) Run envoy sidecar for the registered service
```bash
consul connect envoy -sidecar-for counting-1 -admin-bind localhost:19001 > counting-proxy.log &
```

Open new terminal tab and execute new session to the Dashboard service pod, install required packages and Consul agent
```bash
kubectl --kubeconfig=$KUBECONFIG2 exec -it dashboard -c ubuntu -- bash
apt update
apt upgrade -y
```

```bash
apt-get install curl gnupg sudo lsb-release iproute2 -y
```

```bash
curl --fail --silent --show-error --location https://apt.releases.hashicorp.com/gpg | \
      gpg --dearmor | \
      sudo dd of=/usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
 sudo tee -a /etc/apt/sources.list.d/hashicorp.list
```

```bash
sudo apt-get update
sudo apt-get install consul=1.12.0-1
```

(On the dashboard pod) Set the pod vl3 IP
```bash
DASHBOARD_IP_VL3_ADDRESS=169.254.0.4
CP_IP_VL3_ADDRESS=169.254.0.2
```

(On the dashboard pod) Update dashboard configuration. Use here the saved encryption key and the Dashboard service pod vl3 IP address
```bash
cat > /etc/consul.d/consul.hcl <<EOF
encrypt = "${ENCRYPTION_KEY}"
data_dir = "/opt/consul"
tls {
  defaults {
    ca_file = "/etc/consul.d/consul-agent-ca.pem"
    verify_incoming = false
    verify_outgoing = true
  }
  internal_rpc {
    verify_server_hostname = true
  }
}
datacenter = "dc1"
auto_encrypt {
  tls = true
}
acl {
  enabled = true
  default_policy = "allow"
  enable_token_persistence = true
}
bind_addr = "${DASHBOARD_IP_VL3_ADDRESS}"
connect {
  enabled = true
}
addresses {
  grpc = "127.0.0.1"
}
ports {
  grpc  = 8502
}
EOF
```

(On the dashboard pod) Validate the configuration 
```bash
sudo consul validate /etc/consul.d/
```

(On the dashboard pod) Start Consul agent
```bash
/usr/bin/consul agent -join $CP_IP_VL3_ADDRESS -config-dir=/etc/consul.d/
```

Open new terminal tab and execute new session to the Dashboard service pod. Create the service definition
```bash
kubectl --kubeconfig=$KUBECONFIG2 exec -it dashboard -c ubuntu -- bash
mkdir service
cd service
cat > dashboard.hcl <<EOF
service {
  name = "dashboard"
  port = 9002

  connect {
    sidecar_service {
      proxy {
        upstreams = [
          {
            destination_name = "counting"
            local_bind_port  = 5000
          }
        ]
      }
    }
  }

  check {
    id       = "dashboard-check"
    http     = "http://localhost:9002/health"
    method   = "GET"
    interval = "1s"
    timeout  = "1s"
  }
}
EOF
```

(On the dashboard pod) Register the service with Consul
```bash
consul services register dashboard.hcl
```

(On the dashboard pod) Install Envoy to use it as sidecar
```bash
curl -L https://func-e.io/install.sh | bash -s -- -b /usr/local/bin
export FUNC_E_PLATFORM=linux/amd64
func-e use 1.22.2
sudo cp ~/.func-e/versions/1.22.2/bin/envoy /usr/bin/
# Check envoy version
envoy --version
```

(On the dashboard pod) Run envoy sidecar for the registered service
```bash
consul connect envoy -sidecar-for dashboard > dashboard-proxy.log &
```

Port-forward the dashboard pod
```bash
kubectl --kubeconfig=$KUBECONFIG2 port-forward dashboard 9002:9002
```
In your browser open localhost:9002 and verify the application works!
```bash
result=`curl --include --no-buffer --connect-timeout 20 -H "Connection: Upgrade" -H "Upgrade: websocket" -H "Host: 127.0.0.1:9002" -H "Origin: http://127.0.0.1:9002" -H "Sec-WebSocket-Key: SGVsbG8sIHdvcmxkIQ==" -H "Sec-WebSocket-Version: 13" http://127.0.0.1:9002/socket.io/?EIO=3&transport=websocket`
echo ${result} | grep  -o 'Unreachable'
```
