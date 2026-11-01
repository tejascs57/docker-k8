# Kubernetes Commands (Docker Desktop and PowerShell)

Run commands individually and continue only when the previous step succeeds.
Start Docker Desktop and enable Kubernetes before deploying.
These commands explicitly use the `default` namespace so the Deployment and
Service stay together.

## 1. Select the project and check the cluster

```powershell
cd "C:\Users\stej\OneDrive - Emerson\Desktop\Docker"
kubectl config get-contexts
kubectl config use-context docker-desktop
kubectl get nodes
```

The node should show `Ready`. Switching context selects the cluster targeted by
subsequent commands.

## 2. Build the application image

The current [Deployment](../k8s/deployment.yaml) uses `image: tejas-image`,
which means `tejas-image:latest`.

```powershell
docker build -t tejas-image:latest .
docker image inspect tejas-image:latest --format '{{.Id}}'
```

The manifest explicitly sets `imagePullPolicy: IfNotPresent`. Kubernetes can
use the image locally only if it is available in the node's image store.
Some Docker Desktop configurations require loading the image into the cluster
or using a registry instead.

## 3. Deploy the application and Service

```powershell
kubectl apply -n default -f k8s\deployment.yaml
kubectl apply -n default -f k8s\service.yaml
kubectl rollout status deployment/tejas-deployment -n default --timeout=120s
kubectl get deployments -n default
kubectl get pods -n default -l app=tejas-app -o wide
kubectl get service tejas-service -n default
```

The Deployment manifest requests 3 replicas.

## 4. Open the application

```powershell
curl.exe --fail --show-error --max-time 15 http://localhost:30080/
```

Or open <http://localhost:30080/> in your browser.

| Port | Purpose |
|---|---|
| `30080` (`nodePort`) | Node-facing port; accessible through localhost in the current Docker Desktop setup |
| `80` (`port`) | Service port inside the cluster |
| `5000` (`targetPort`) | Application port inside the pods |

Traffic flow: `localhost:30080 -> Service:80 -> Pod:5000`.

If NodePort access is unavailable, run this in a separate PowerShell terminal:

```powershell
kubectl port-forward -n default service/tejas-service 8080:80
```

Keep that terminal open and visit <http://localhost:8080/>.
Press `Ctrl+C` to stop port forwarding.

## 5. Scale up or down

Scale up to 5 pods:

```powershell
kubectl scale deployment tejas-deployment -n default --replicas=5
kubectl rollout status deployment/tejas-deployment -n default --timeout=120s
kubectl get pods -n default -l app=tejas-app
```

Scale down to 1 pod:

```powershell
kubectl scale deployment tejas-deployment -n default --replicas=1
```

Reapplying the Deployment manifest resets the replica count to its
`spec.replicas` value (currently 3). Update that value if you want scaling to
persist when you reapply the file.

## 6. Restart pods

```powershell
kubectl rollout restart deployment/tejas-deployment -n default
kubectl rollout status deployment/tejas-deployment -n default --timeout=120s
kubectl get pods -n default -l app=tejas-app
```

The Deployment replaces its pods while preserving the configured replica count.
Old pods briefly showing `Terminating` during a restart is normal.
Restarting does not fix missing images or scheduling errors.

## 7. View logs and diagnose pod errors

```powershell
kubectl logs -n default -l app=tejas-app --all-containers=true --prefix=true --tail=100
kubectl describe pods -n default -l app=tejas-app
kubectl get events -n default --sort-by=.metadata.creationTimestamp
kubectl get nodes -o wide
```

Read the `Events` section of the pod descriptions:

| Status | What to check |
|---|---|
| `Pending` | Scheduling events, node readiness, available CPU/memory, and node constraints |
| `ImagePullBackOff` / `ErrImagePull` | Exact image name/tag, node image availability, registry access, and credentials |
| `CrashLoopBackOff` | Application logs and the container's previous termination details |
| `Terminating` | Briefly normal during replacement; investigate pod/node details if it persists |

For logs from a crashed container's previous run, replace `POD_NAME` with an
actual pod name from `kubectl get pods`:

```powershell
kubectl logs -n default POD_NAME --previous
```

For image errors, ensure the build tag matches the manifest exactly. After
making the image available to the node, use the restart commands in section 6.
For application updates, prefer a new image tag and update the manifest to
match; `IfNotPresent` can reuse a cached image when a tag is reused.

## 8. Diagnose an unreachable Service

```powershell
kubectl get services --all-namespaces -o wide
kubectl get pods -n default -l app=tejas-app -o wide
kubectl describe service tejas-service -n default
kubectl get endpointslices -n default -l kubernetes.io/service-name=tejas-service
```

The Service and pods must be in the same namespace, and the Service selector
must match the pods' labels. EndpointSlices should list pod IP addresses and
port `5000`.

If applying the Service reports that NodePort `30080` is already allocated,
the all-namespaces Service listing identifies its owner.
Do not delete another Service without confirming it is safe to remove.

For the specific mismatch previously encountered in this project, where an
unused `tejas-ns/tejas-service` owned port `30080` but the pods were in `default`,
the approved fix was:

```powershell
kubectl delete service tejas-service -n tejas-ns
kubectl apply -n default -f k8s\service.yaml
```

This fix has already been applied; do not repeat it unless the same mismatch
recurs and that Service is still unused.

## 9. Remove the deployment

Only run these commands when you want to stop the application and remove its
Service:

```powershell
kubectl delete -n default -f k8s\service.yaml
kubectl delete -n default -f k8s\deployment.yaml
```

These commands delete the project resources, not the Kubernetes cluster or
Docker image.
