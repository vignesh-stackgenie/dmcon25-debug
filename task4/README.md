# Task 4: Service targetPort Mismatch (Endpoints exist, traffic fails)

This task simulates a Kubernetes Service whose `targetPort` points to the wrong container port. The Deployment is healthy and the Service has endpoints, but traffic through the Service fails because the Pods are not listening on the port the Service routes to.

## Scenario
- The Deployment runs a simple HTTP echo server listening on container port 8080.
- The Service `webapp-service` exposes port 80 but routes to `targetPort: 80` (wrong!). It is exposed as NodePort 30080 for browser testing.
- `kubectl get endpoints` shows Pod IPs present, but requests via the Service fail.

## Deploy the scenario
```bash
kubectl apply -f task4/manifests/
```

This applies:
- namespace.yaml
- deployment.yaml (web app with label `app=webapp`, listens on 8080)
- service.yaml (selector matches `app=webapp`, but targetPort is incorrectly 80)

## Observe the problem (browser-visible)
```bash
kubectl -n task4 get deploy,svc,pods
kubectl -n task4 get endpoints webapp-service -o wide
kubectl -n task4 describe svc webapp-service | sed -n '1,120p'
```
Expected:
- Pods are Running and Ready
- Service exists on port 80
- Endpoints for `webapp-service` show Pod IPs and port 80 (but Pods actually listen on 8080)

Now try from your browser (replace <NODE_IP> with any worker/master IP):
```bash
kubectl get nodes -o wide
# Open: http://<NODE_IP>:30080
```
Expected: The page fails to load or times out (because Service forwards to wrong port).

Optional checks:
- Verify the Pod is serving on 8080 by port-forwarding the Deployment directly (bypasses the Service):
```bash
kubectl -n task4 port-forward deploy/webapp 8080:8080 &
curl -s http://127.0.0.1:8080
```
- Try port-forwarding the Service (should fail/hang because it forwards to wrong target port):
```bash
kubectl -n task4 port-forward svc/webapp-service 9090:80 &
curl -s --max-time 3 http://127.0.0.1:9090 || echo "request failed"
```

## Debugging steps
1) Confirm the container is listening on 8080
```bash
kubectl -n task4 get deploy webapp -o yaml | sed -n '/containers:/,/ports:/p'
```
2) Inspect the Service and its targetPort
```bash
kubectl -n task4 get svc webapp-service -o yaml | sed -n '/ports:/,+6p'
```
3) Inspect the Endpoints resource to see the port it routes to
```bash
kubectl -n task4 get endpoints webapp-service -o yaml
```

## The fix
Update the Service to route to the correct container port 8080:
```bash
kubectl -n task4 patch svc webapp-service --type='json' -p='[
  {"op":"replace","path":"/spec/ports/0/targetPort","value":8080}
]'
```

Verify (and test in the browser again):
```bash
kubectl -n task4 get endpoints webapp-service -o wide
kubectl -n task4 get svc webapp-service -o wide
# Open: http://<NODE_IP>:30080  (should show: "Hello from webapp")
```
You should now see the response in the browser.

## Cleanup
```bash
kubectl delete -f task4/manifests/
```
