#!/bin/bash

# Script to deploy Nethermind and Prysm on Minikube using Kubernetes YAMLs

# Ensure Minikube is running
minikube stop
minikube start --driver=docker --memory=6g --cpus=4

# Create a directory for the YAML files
mkdir -p k8s-execution-client
cd k8s-execution-client

# Generate a random JWT secret (32 bytes, hex encoded)
JWT_SECRET=$(openssl rand -hex 32)
echo "Generated JWT Secret: $JWT_SECRET"

# 1. Create Secret for JWT
cat <<EOF > secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: jwt-secret
type: Opaque
data:
  jwtsecret: $(echo -n "$JWT_SECRET" | base64)
EOF

# 2. Create PVC for Nethermind
touch nethermind-pvc.yaml
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

# 3. Create Deployment for Nethermind (Execution Layer)
touch nethermind-deployment.yaml
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
        image: rpk96/my-custom-nethermind:latest
        args:
        - --config
        - mainnet
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
        - name: DOTNET_BUNDLE_EXTRACT_BASE_DIR
          value: /var/lib/nethermind
      volumes:
      - name: nethermind-data
        persistentVolumeClaim:
          claimName: nethermind-data
      - name: jwt-secret
        secret:
          secretName: jwt-secret
EOF

# 4. Create Service for Nethermind
touch nethermind-service.yaml
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
    port: 30304
    targetPort: 30304
    protocol: UDP
    nodePort: 31304
  type: NodePort
EOF

# Apply all the YAMLs to Minikube
kubectl apply -f secret.yaml
kubectl apply -f nethermind-pvc.yaml
kubectl apply -f nethermind-deployment.yaml
kubectl apply -f nethermind-service.yaml

# Display the status
kubectl get all

# # Print Minikube service URLs
# echo "Nethermind Service URL:"
# minikube service nethermind --url

echo "Deployment complete! Check the status with 'kubectl get all' and logs with 'kubectl logs <pod-name>'."