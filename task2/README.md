# Task 2: The Unschedulable Pod (Hidden Constraint via PV nodeAffinity)

This task reproduces a real-world Kubernetes scheduling mystery:
- A Pod is stuck in Pending with a FailedScheduling event mentioning pod affinity/anti-affinity and taints.
- The Pod spec has no affinity or tolerations.
- The hidden constraint is inherited from a PersistentVolume (PV) that the Pod's PVC binds to. The PV has nodeAffinity that doesn't match any node, making the Pod effectively unschedulable.

## What you will do
- Deploy manifests that create a PV with restrictive nodeAffinity to a nonexistent label, a PVC bound to it, and a Pod that uses the PVC.
- Observe the Pod remain Pending with FailedScheduling.
- Debug using kubectl to trace the chain Pod → PVC → PV → nodeAffinity.
- Fix by either adjusting node labels, changing PV nodeAffinity, or using a different PV/SC.

## Prerequisites
- kubectl context pointing to a cluster with at least one worker node.
- Cluster supports manual PVs (no external provisioner required). This lab uses a no-provisioner StorageClass for clarity.

## Deploy the scenario
```bash
kubectl apply -f task2/manifests/
```

This applies:
- namespace.yaml
- storageclass.yaml
- persistent-volume.yaml
- persistent-volume-claim.yaml
- pod.yaml

Wait a few seconds, then check the Pod status:
```bash
kubectl -n task2 get pod
kubectl -n task2 describe pod pvc-consumer
```

You should see an event like:
- FailedScheduling: 0/… nodes are available: … didn't match pod affinity/anti-affinity, … had taints the pod didn't tolerate.

The Pod has no affinity/tolerations, so what's up?

## Debugging steps
1) Inspect the PVC used by the Pod
```bash
kubectl -n task2 get pvc data-claim -o yaml
```
- Note status.volumeName – that tells you which PV was bound.

2) Inspect the PV
```bash
kubectl get pv <pv-name> -o yaml
```
- Look for spec.nodeAffinity.required.nodeSelectorTerms.
- In this lab, the PV requires the node label:
  - failure-domain.beta.kubernetes.io/zone: lab-zone-a (label purposely absent)

3) Inspect node labels and taints
```bash
kubectl get nodes
kubectl describe node <node-name>
```
- Verify that none of the nodes have the required label.
- Taints in the event are a red herring here; the real blocker is PV nodeAffinity.

## The fix (choose one)
- Option A: Label one worker node to satisfy the PV nodeAffinity
```bash
kubectl label node <your-worker-node> failure-domain.beta.kubernetes.io/zone=lab-zone-a
```
Then re-check the Pod:
```bash
kubectl -n task2 get pod -w
```
It should schedule once a matching node exists.

- Option B: Edit the PV to remove/adjust nodeAffinity
```bash
kubectl edit pv <pv-name>
```
Remove or change the spec.nodeAffinity block to match your cluster.

- Option C: Use a different PV or a dynamic StorageClass that provisions volumes compatible with your nodes.

## Cleanup
```bash
kubectl delete -f task2/manifests/
```

## Files
- manifests/namespace.yaml: Isolates resources in task2 namespace
- manifests/storageclass.yaml: no-provisioner SC for static PV clarity
- manifests/persistent-volume.yaml: Static PV with nodeAffinity to a nonexistent label
- manifests/persistent-volume-claim.yaml: PVC bound to the PV
- manifests/pod.yaml: Pod mounting the PVC, becomes Pending

Happy debugging!
