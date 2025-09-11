# Task 6: Kubernetes Liveness Probe Debugging

This task is designed to help you practice debugging a common Kubernetes issue: misconfigured health checks. You'll learn how to identify and fix a failing liveness probe.

## Scenario

You have a simple nginx web application deployment that's continuously restarting due to a failing liveness probe. The probe is checking an endpoint that doesn't exist, causing the container to restart repeatedly.

## The Setup

The deployment consists of:
- A namespace called `debug-practice`
- A deployment running an nginx container with a misconfigured liveness probe
- A ClusterIP service to expose the deployment

## Known Symptoms
- The pod keeps restarting
- You'll see a high restart count
- Events will show liveness probe failures

## Your Task

1. **Investigate and Fix the Liveness Probe**
   - Use `kubectl get pods -n debug-practice` to observe the pod's restart behavior
   - Use `kubectl describe pod` to analyze the probe failures
   - Identify that the probe is checking `/nonexistent`
   - Modify the probe to check the correct endpoint `/`

## Success Criteria

Your solution is complete when:
- The pod is in Running state
- The liveness probe is passing
- Pod restart count stops increasing

## Debugging Commands Reference

```bash
# Get pod status and watch for restarts
kubectl get pods -n debug-practice -w

# Describe pod to see events and probe failures
kubectl describe pod <pod-name> -n debug-practice

# Edit deployment to fix the probe
kubectl edit deployment debug-app -n debug-practice
```

## Tips
- Focus on the events section in `kubectl describe pod`
- Look for the liveness probe failure messages
- Remember that nginx serves content at the root path `/`

## Solution

<details>
<summary>Click to see the solution</summary>

1. Fix the liveness probe by changing the path from `/nonexistent` to `/`:
```yaml
livenessProbe:
  httpGet:
    path: /
    port: 80
```

You can apply this fix using `kubectl edit deployment debug-app -n debug-practice` and updating the probe path.

After the fix, the pod should stop restarting and remain in a healthy state.

</details>
