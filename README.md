
### Ethereum Node Setup and Configuration

#### Objective 1: Set up an Ethereum Proof of Stake (PoS) Client
The provided bash scripts deploy Nethermind (Execution Layer) and Prysm (Consensus Layer) on Minikube using Kubernetes. Below are the corrected and formatted scripts:

##### Execution Layer Deployment (Nethermind)
```bash
#!/bin/bash
# Script to deploy Nethermind (Execution Layer) on Minikube

# Ensure Minikube is running (uncomment to start fresh)
# minikube stop
# minikube start --driver=docker --memory=6g --cpus=4

# Create directory for Kubernetes YAMLs
mkdir -p k8s-execution-client
cd k8s-execution-client

# Generate a random JWT secret (32 bytes, hex encoded)
JWT_SECRET=$(openssl rand -hex 32)
echo "Generated JWT Secret: $JWT_SECRET"

# Create Secret for JWT
cat <<EOF > secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: jwt-secret
type: Opaque
data:
  jwtsecret: $(echo -n "$JWT_SECRET" | base64)
EOF

# Create Persistent Volume Claim (PVC) for Nethermind
cat <<EOF > nethermind-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nethermind-data
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 50Gi
EOF

# Create Deployment for Nethermind
cat <<EOF > nethermind-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nethermind
  labels:
    app: nethermind
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nethermind
  template:
    metadata:
      labels:
        app: nethermind
    spec:
      containers:
      - name: nethermind
        image: nethermind/nethermind:latest
        args:
        - --config=mainnet
        - --datadir=/var/lib/nethermind
        - --Network.DiscoveryPort=30303
        - --Network.P2PPort=30303
        - --Network.MaxActivePeers=50
        - --JsonRpc.Port=8545
        - --JsonRpc.EngineHost=0.0.0.0
        - --JsonRpc.EnginePort=8551
        - --JsonRpc.JwtSecretFile=/secrets/jwtsecret
        - --Pruning.Mode=Hybrid
        - --Metrics.Enabled=true
        - --Metrics.ExposePort=6060
        ports:
        - containerPort: 8545
        - containerPort: 8551
        - containerPort: 30303
        - containerPort: 6060
        volumeMounts:
        - name: nethermind-data
          mountPath: /var/lib/nethermind
        - name: jwt-secret
          mountPath: /secrets
        env:
        - name: NETHERMIND_JSONRPC_HOST
          value: "0.0.0.0"
        - name: NETHERMIND_JSONRPC_PORT
          value: "8545"
      volumes:
      - name: nethermind-data
        persistentVolumeClaim:
          claimName: nethermind-data
      - name: jwt-secret
        secret:
          secretName: jwt-secret
EOF

# Create Service for Nethermind
cat <<EOF > nethermind-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: nethermind
spec:
  selector:
    app: nethermind
  ports:
  - name: rpc
    port: 8545
    targetPort: 8545
    nodePort: 30545
  - name: engine
    port: 8551
    targetPort: 8551
    nodePort: 30551
  - name: metrics
    port: 6060
    targetPort: 6060
    nodePort: 30660
  - name: p2p-tcp
    port: 30303
    targetPort: 30303
    protocol: TCP
    nodePort: 31303
  - name: p2p-udp
    port: 30303
    targetPort: 30303
    protocol: UDP
    nodePort: 31303
  type: NodePort
EOF

# Apply configurations to Minikube
kubectl apply -f secret.yaml
kubectl apply -f nethermind-pvc.yaml
kubectl apply -f nethermind-deployment.yaml
kubectl apply -f nethermind-service.yaml

# Display status
kubectl get all
echo "Nethermind Service URL:"
minikube service nethermind --url

echo "Execution Layer deployment complete!"
```

##### Consensus Layer Deployment (Prysm)
```bash
#!/bin/bash
# Script to deploy Prysm (Consensus Layer) on Minikube

# Create directory for Kubernetes YAMLs
mkdir -p k8s-consensus-client
cd k8s-consensus-client

# Create Persistent Volume Claim (PVC) for Prysm
cat <<EOF > prysm-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: prysm-data
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 80Gi
EOF

# Create Deployment for Prysm
cat <<EOF > prysm-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prysm
  labels:
    app: prysm
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prysm
  template:
    metadata:
      labels:
        app: prysm
    spec:
      containers:
      - name: prysm
        image: gcr.io/prysmaticlabs/prysm/beacon-chain:latest
        args:
        - --mainnet
        - --datadir=/var/lib/prysm/beacon
        - --grpc-gateway-port=5052
        - --rpc-host=0.0.0.0
        - --p2p-tcp-port=13000
        - --p2p-udp-port=12000
        - --p2p-max-peers=80
        - --monitoring-port=8008
        - --checkpoint-sync-url=https://beaconstate.info
        - --execution-endpoint=http://nethermind.default.svc.cluster.local:8551
        - --jwt-secret=/secrets/jwtsecret
        - --accept-terms-of-use=true
        ports:
        - containerPort: 5052
        - containerPort: 13000
        - containerPort: 12000
        - containerPort: 8008
        volumeMounts:
        - name: prysm-data
          mountPath: /var/lib/prysm/beacon
        - name: jwt-secret
          mountPath: /secrets
      volumes:
      - name: prysm-data
        persistentVolumeClaim:
          claimName: prysm-data
      - name: jwt-secret
        secret:
          secretName: jwt-secret
EOF

# Create Service for Prysm
cat <<EOF > prysm-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: prysm
spec:
  selector:
    app: prysm
  ports:
  - name: grpc
    port: 5052
    targetPort: 5052
    nodePort: 30052
  - name: metrics
    port: 8008
    targetPort: 8008
    nodePort: 30008
  - name: p2p-tcp
    port: 13000
    targetPort: 13000
    protocol: TCP
    nodePort: 31300
  - name: p2p-udp
    port: 12000
    targetPort: 12000
    protocol: UDP
    nodePort: 31200
  type: NodePort
EOF

# Apply configurations to Minikube
kubectl apply -f prysm-pvc.yaml
kubectl apply -f prysm-deployment.yaml
kubectl apply -f prysm-service.yaml

# Display status
kubectl get all
echo "Prysm Service URL:"
minikube service prysm --url

echo "Consensus Layer deployment complete!"
```

#### Objective 2: Provide a Postman Collection
Below are the top 10 functional RPC endpoints for the deployed Ethereum PoS client (Nethermind). These can be imported into a Postman Collection.

##### 1. Get Client Version
```bash
kubectl exec -it $(kubectl get pod -l app=nethermind -o jsonpath="{.items[0].metadata.name}") -- \
curl -X POST http://127.0.0.1:8545 -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"web3_clientVersion","params":[],"id":1}'
```
**Response:**
```json
{"jsonrpc":"2.0","result":"Nethermind/v1.31.6+4e68f8ee/linux-arm64/dotnet9.0.3","id":1}
```

##### 2. Get Network Version
```bash
kubectl exec -it $(kubectl get pod -l app=nethermind -o jsonpath="{.items[0].metadata.name}") -- \
curl -X POST http://127.0.0.1:8545 -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"net_version","params":[],"id":1}'
```
**Response:**
```json
{"jsonrpc":"2.0","result":"1","id":1}
```

##### 3. Get Chain ID
```bash
kubectl exec -it $(kubectl get pod -l app=nethermind -o jsonpath="{.items[0].metadata.name}") -- \
curl -X POST http://127.0.0.1:8545 -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}'
```
**Response:**
```json
{"jsonrpc":"2.0","result":"0x1","id":1}
```

##### 4. Get Peer Count
```bash
kubectl exec -it $(kubectl get pod -l app=nethermind -o jsonpath="{.items[0].metadata.name}") -- \
curl -X POST http://127.0.0.1:8545 -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}'
```
**Response:**
```json
{"jsonrpc":"2.0","result":"0x23","id":1}
```

##### 5. Get Block Number
```bash
kubectl exec -it $(kubectl get pod -l app=nethermind -o jsonpath="{.items[0].metadata.name}") -- \
curl -X POST http://127.0.0.1:8545 -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
```
**Response:**
```json
{"jsonrpc":"2.0","result":"0x0","id":1}
```

##### 6. Get Latest Block Details
```bash
kubectl exec -it $(kubectl get pod -l app=nethermind -o jsonpath="{.items[0].metadata.name}") -- \
curl -X POST http://127.0.0.1:8545 -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["latest", false],"id":1}'
```
**Response:**
```json
{
  "jsonrpc": "2.0",
  "result": {
    "author": "0x0000000000000000000000000000000000000000",
    "difficulty": "0x400000000",
    "extraData": "0x11bbe8db4e347b4e8c937c1c8370e4b5ed33adb3db69cbdb7a38e1e50b1b82fa",
    "gasLimit": "0x1388",
    "gasUsed": "0x0",
    "hash": "0xd4e56740f876aef8c010b86a40d5f56745a118d0906a34e69aec8c0db1cb8fa3",
    "logsBloom": "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
    "miner": "0x0000000000000000000000000000000000000000",
    "mixHash": "0x0000000000000000000000000000000000000000000000000000000000000000",
    "nonce": "0x0000000000000042",
    "number": "0x0",
    "parentHash": "0x0000000000000000000000000000000000000000000000000000000000000000",
    "receiptsRoot": "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
    "sha3Uncles": "0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347",
    "size": "0x21c",
    "stateRoot": "0xd7f8974fb5ac78d9ac099b9ad5018bedc2ce0a72dad1827a1709da30580f0544",
    "totalDifficulty": "0x400000000",
    "timestamp": "0x0",
    "transactions": [],
    "transactionsRoot": "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
    "uncles": []
  },
  "id": 1
}
```

##### 7. Get Gas Price
```bash
kubectl exec -it $(kubectl get pod -l app=nethermind -o jsonpath="{.items[0].metadata.name}") -- \
curl -X POST http://127.0.0.1:8545 -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_gasPrice","params":[],"id":1}'
```
**Response:**
```json
{"jsonrpc":"2.0","result":"0x1","id":1}
```

##### 8. Get Account Balance (Replace `0xYourAddressHere` with an actual address)
```bash
kubectl exec -it $(kubectl get pod -l app=nethermind -o jsonpath="{.items[0].metadata.name}") -- \
curl -X POST http://127.0.0.1:8545 -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_getBalance","params":["0xYourAddressHere", "latest"],"id":1}'
```
**Response:**
```json
{"jsonrpc":"2.0","error":{"code":-32602,"message":"Invalid params"},"id":1}
```

##### 9. Call Contract (Replace `0xContractAddressHere` and `0xFunctionDataHere` with actual values)
```bash
kubectl exec -it $(kubectl get pod -l app=nethermind -o jsonpath="{.items[0].metadata.name}") -- \
curl -X POST http://127.0.0.1:8545 -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_call","params":[{"to": "0xContractAddressHere", "data": "0xFunctionDataHere"}, "latest"],"id":1}'
```
**Response:**
```json
{"jsonrpc":"2.0","error":{"code":-32602,"message":"Invalid params"},"id":1}
```

##### 10. Get Transaction By Hash (Replace `0xTransactionHashHere` with an actual transaction hash)
```bash
kubectl exec -it $(kubectl get pod -l app=nethermind -o jsonpath="{.items[0].metadata.name}") -- \
curl -X POST http://127.0.0.1:8545 -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_getTransactionByHash","params":["0xTransactionHashHere"],"id":1}'
```
**Response:**
```json
{"jsonrpc":"2.0","error":{"code":-32602,"message":"Invalid params"},"id":1}
```

#### Objective 3: Document the Setup Process
##### Setup Process Documentation
1. **Prerequisites**
   - **Hardware Requirements**: 
     - CPU: 4 cores
     - RAM: 6GB
     - Storage: 130GB (50GB for Nethermind, 80GB for Prysm)
   - **Software**: 
     - Minikube (v1.26+)
     - kubectl
     - Docker
     - OpenSSL (for JWT generation)

2. **Steps**
   - **Start Minikube**: `minikube start --driver=docker --memory=6g --cpus=4`
   - **Deploy Execution Layer (Nethermind)**:
     - Run the first script to create a JWT secret, PVC, Deployment, and Service.
     - Nethermind syncs with the Ethereum mainnet and exposes RPC on port 8545 and Engine API on 8551.
   - **Deploy Consensus Layer (Prysm)**:
     - Run the second script to create a PVC, Deployment, and Service.
     - Prysm connects to Nethermind via the Engine API (port 8551) and syncs using a checkpoint URL.
   - **Verify Deployment**: Use `kubectl get all` and check logs with `kubectl logs <pod-name>`.

3. **Configuration Details**
   - **Nethermind**:
     - Image: `nethermind/nethermind:latest`
     - Config: Mainnet with hybrid pruning
     - Ports: 8545 (RPC), 8551 (Engine), 6060 (Metrics), 30303 (P2P)
     - Storage: 50GB PVC
   - **Prysm**:
     - Image: `gcr.io/prysmaticlabs/prysm/beacon-chain:latest`
     - Config: Mainnet with checkpoint sync
     - Ports: 5052 (gRPC), 8008 (Metrics), 13000 (P2P TCP), 12000 (P2P UDP)
     - Storage: 80GB PVC
   - **JWT Secret**: Shared between Nethermind and Prysm for secure communication.

4. **Automation**: The scripts use heredocs (`cat <<EOF`) to generate YAMLs dynamically, reducing manual configuration.

#### Objective 4: Design a Monitoring and Alert System
##### Monitoring and Alerting Design
1. **Tools**:
   - **Prometheus**: Scrapes metrics from Nethermind (port 6060) and Prysm (port 8008).
   - **Grafana**: Visualizes metrics and dashboards.
   - **Alertmanager**: Sends alerts via email, Slack, or PagerDuty.

2. **Metrics to Monitor**:
   - **Nethermind**:
     - Sync status (`eth_syncing`)
     - Peer count (`Network.MaxActivePeers`)
     - RPC latency and error rate
   - **Prysm**:
     - Beacon chain head slot
     - Peer count
     - Participation rate

3. **Alert Rules**:
   - **Node Down**: If metrics are unavailable for >5 minutes.
   - **Sync Lag**: If `eth_syncing` indicates a lag >100 blocks.
   - **Low Peers**: If peer count drops below 10.

4. **Implementation Steps**:
   - Deploy Prometheus and Grafana in Minikube using Helm:
     ```bash
     helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
     helm install prometheus prometheus-community/prometheus
     helm install grafana grafana/grafana
     ```
   - Configure Prometheus to scrape Nethermind and Prysm:
     ```yaml
     scrape_configs:
       - job_name: 'nethermind'
         static_configs:
           - targets: ['nethermind:6060']
       - job_name: 'prysm'
         static_configs:
           - targets: ['prysm:8008']
     ```
   - Set up Alertmanager with rules and notification channels.

5. **Production Considerations**:
   - Use persistent storage for Prometheus data.
   - Implement high availability with multiple replicas.
   - Secure endpoints with TLS.

#### Objective 5: Build a Simple RPC Node Monitoring Tool
Here’s a lightweight Python script to monitor the RPC node’s health:

```python
#!/usr/bin/env python3
import requests
import time
import logging
import json

# Configuration
RPC_URL = "http://192.168.49.2:30545"  # Replace with your Nethermind RPC URL
LOG_FILE = "rpc_monitor.log"
INTERVAL = 60  # Check every 60 seconds

# Set up logging
logging.basicConfig(filename=LOG_FILE, level=logging.INFO, 
                    format="%(asctime)s - %(levelname)s - %(message)s")

def check_rpc_health():
    payload = {
        "jsonrpc": "2.0",
        "method": "eth_blockNumber",
        "params": [],
        "id": 1
    }
    headers = {"Content-Type": "application/json"}
    
    try:
        response = requests.post(RPC_URL, json=payload, headers=headers, timeout=5)
        response.raise_for_status()
        data = response.json()
        
        if "result" in data:
            block_number = int(data["result"], 16)
            logging.info(f"RPC Healthy - Latest Block Number: {block_number}")
            return True
        else:
            logging.error(f"RPC Error - Response: {data}")
            return False
    except Exception as e:
        logging.error(f"RPC Unreachable - Error: {str(e)}")
        return False

def monitor():
    while True:
        is_healthy = check_rpc_health()
        if not is_healthy:
            print("Alert: RPC Node is unhealthy!")
        time.sleep(INTERVAL)

if __name__ == "__main__":
    logging.info("Starting RPC Node Monitoring Tool")
    monitor()
```

**Features**:
- Checks `eth_blockNumber` every 60 seconds.
- Logs health status to `rpc_monitor.log`.
- Prints an alert to the console if the node is unhealthy.

**To Run**:
1. Install dependencies: `pip install requests`
2. Update `RPC_URL` with your Nethermind RPC URL.
3. Run: `python3 rpc_monitor.py`

**Production Enhancements**:
- Add email/Slack notifications using libraries like `smtplib` or `slack_sdk`.
- Store metrics in a time-series database (e.g., InfluxDB).
- Add more checks (e.g., `eth_syncing`, peer count).

# Production-Grade Ethereum Node Setup

## 1. Security Enhancements

### a. Secure JWT Secret Management
- Store the JWT secret in a Kubernetes Secret Manager (e.g., HashiCorp Vault) instead of hardcoding it in YAML.
- Implement RBAC (Role-Based Access Control) to restrict access to the secret.

### b. Restrict API & RPC Access
- Limit Nethermind JSON-RPC access to specific IP addresses using Kubernetes Network Policies.
- Disable public access to the JSON-RPC & gRPC endpoints.
- Use an authentication mechanism (e.g., JWT, basic auth) for external access to RPC.

### c. Firewall & Networking Hardening
- Configure ingress and egress rules using Kubernetes NetworkPolicies.
- Set up a reverse proxy (Nginx, Traefik, or HAProxy) for controlled access.
- Enable TLS encryption for RPC endpoints using cert-manager.

---

## 2. Performance & Scalability

### a. Resource Optimization
- Allocate dedicated CPU & memory requests/limits for the pods:

```yaml
resources:
  requests:
    cpu: "2"
    memory: "4Gi"
  limits:
    cpu: "4"
    memory: "8Gi"
```

- Use Affinity & Taints/Tolerations to schedule execution & consensus clients on separate nodes.

### b. Load Balancing & Redundancy
- Deploy multiple replicas of the execution and consensus clients for high availability.
- Implement horizontal pod autoscaling (HPA) based on CPU/memory usage:

```bash
kubectl autoscale deployment nethermind --cpu-percent=70 --min=1 --max=3
kubectl autoscale deployment prysm --cpu-percent=70 --min=1 --max=3
```

- Use Kubernetes Service LoadBalancer for better traffic distribution.

### c. Persistent Storage Optimization
- Use a distributed storage solution (Amazon EFS, Longhorn) instead of a local Persistent Volume.
- Enable database pruning on Nethermind to reduce disk usage.

---

## 3. Monitoring & Logging

### a. Metrics Collection
- Deploy Prometheus & Grafana for real-time monitoring of:
  - CPU, memory, and disk usage
  - Peer connection stability
  - Block propagation time
  - Sync status
- Configure Nethermind & Prysm to expose Prometheus metrics.

### b. Centralized Logging
- Set up Fluentd, Loki, or Elastic Stack (ELK) for log aggregation.
- Configure log rotation to avoid excessive disk usage.

### c. Alerts & Incident Response
- Implement Prometheus Alertmanager for threshold-based alerts.
- Set up on-call notifications via Slack, PagerDuty, or OpsGenie.

---

## 4. High Availability & Disaster Recovery

### a. Backup Strategy
- Regularly backup blockchain data & Kubernetes configurations.
- Use Velero for Kubernetes backup & restore.

### b. Disaster Recovery Plan
- Deploy a failover node in a different region.
- Implement stateful recovery scripts to restore node data after failure.

### c. Multi-Region Deployment
- Use geographically distributed Ethereum nodes.
- Implement load balancing between multiple execution & consensus nodes.

---

## 5. Compliance & Best Practices

### a. Regular Security Audits
- Perform vulnerability scanning using tools like Trivy, Kube-Bench.
- Enforce CIS Benchmark security policies.

### b. API Rate Limiting
- Set up API Gateway (Kong, Traefik, Nginx Ingress) to limit request rates.

### c. Immutable Infrastructure
- Use GitOps (ArgoCD, FluxCD) for version-controlled deployments.
