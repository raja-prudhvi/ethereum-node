#!/bin/bash

# Create a directory for the YAML files
mkdir -p k8s-consensus-client
cd k8s-consensus-client

# 3. Create PVC for Prysm
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

# 5. Create Deployment for Prysm (Consensus Layer)
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

# 7. Create Service for Prysm
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


kubectl apply -f prysm-pvc.yaml
kubectl apply -f prysm-deployment.yaml
kubectl apply -f prysm-service.yaml


# Display the status
kubectl get all

# # Print Minikube service URLs
# echo "Nethermind Service URL:"
# minikube service nethermind --url
# echo "Prysm Service URL:"
# minikube service prysm --url

echo "Deployment complete! Check the status with 'kubectl get all' and logs with 'kubectl logs'."

