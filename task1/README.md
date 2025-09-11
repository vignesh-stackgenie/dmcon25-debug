# Task 1: Web Application Connection Issues

## Scenario
You have been given a Kubernetes deployment with a web application that should display a welcome message. However, when trying to access it through a web browser or from within the cluster, the connection fails. This task will test your ability to diagnose and fix Kubernetes service networking issues.

## Problem Description
- The web application should display "Hello from Task 1!"
- Users are unable to connect to the application
- Service networking is not working as expected
- Connection attempts result in timeouts

## Expected Behavior
When working correctly:
- The web application should be accessible through the service
- Accessing the service should display "Hello from Task 1!"
- Client pod should be able to connect to the web service

## Investigation Steps

1. Check the status of all resources:
```bash
kubectl -n task1 get all
```

2. Verify the service endpoints:
```bash
kubectl -n task1 get endpoints web
kubectl -n task1 describe service web
```

3. Check if pods are running and properly labeled:
```bash
kubectl -n task1 get pods --show-labels
```

4. Test connectivity from the client pod:
```bash
# Get client pod name
POD=$(kubectl -n task1 get pod -l app=client -o jsonpath='{.items[0].metadata.name}')
# Try to access the service
kubectl -n task1 exec $POD -- wget -qO- http://web:8080
```

5. Check pod logs for any errors:
```bash
kubectl -n task1 logs -l app=web-app
```

## Common Issues to Check

1. Service Selector Configuration:
   - Check if service selector matches pod labels
   - Verify label consistency across resources

2. Port Configuration:
   - Verify service port mappings
   - Check container port settings
   - Ensure targetPort matches container port

3. Pod Health:
   - Confirm pods are running
   - Check pod logs for errors
   - Verify container is listening on correct port

## Solution

The issue has two parts:

1. Service selector doesn't match pod labels:
   - Service uses selector `app: web`
   - Pods are labeled with `app: web-app`

2. Port configuration mismatch:
   - Container listens on port 80
   - Service targetPort is set to 80
   - Service port is 8080

To fix:
```bash
# Update service selector
kubectl -n task1 patch service web --type='json' -p='[
  {"op":"replace","path":"/spec/selector/app","value":"web-app"}
]'

# Verify fix
kubectl -n task1 get endpoints web
kubectl -n task1 exec deploy/client -- wget -qO- http://web-app:8080
```

## Cleanup
```bash
kubectl delete -f task1/manifests/
```
