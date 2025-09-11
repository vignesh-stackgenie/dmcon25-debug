# Task 5: MongoDB Connection Failure (Wrong Connection String)

This task simulates an application that fails to start because it cannot connect to MongoDB due to incorrect connection configuration.

## Scenario
- A web application tries to connect to MongoDB using environment variables.
- The MongoDB connection string is misconfigured (wrong host/port/database name).
- The app crashes on startup with connection timeout or authentication errors.
- MongoDB service is running fine, but the app can't reach it.

## Deploy the scenario
```bash
kubectl apply -f task5/manifests/
```

This applies:
- namespace.yaml
- mongodb-deployment.yaml (MongoDB on port 27017)
- mongodb-service.yaml (ClusterIP service)
- app-deployment.yaml (web app with wrong MongoDB config)
- app-service.yaml

Check status:
```bash
kubectl -n task5 get pods,svc
kubectl -n task5 describe pod -l app=webapp
```

Expected: Web app pods crash with MongoDB connection errors.

## Debugging steps
1) Check application logs for connection errors
```bash
kubectl -n task5 logs -l app=webapp --tail=50
```
2) Verify MongoDB is running and accessible
```bash
kubectl -n task5 get pods -l app=mongodb
kubectl -n task5 exec -l app=mongodb -- mongosh --eval "db.runCommand('ping')"
```
3) Check environment variables in the web app
```bash
kubectl -n task5 get deploy webapp -o yaml | grep -A10 -B5 env
```

## The fix
Update the MongoDB connection string in the web app deployment:

```bash
kubectl -n task5 patch deploy webapp --type='json' -p='[
  {"op":"replace","path":"/spec/template/spec/containers/0/env/0/value","value":"mongodb://mongodb-service:27017/mydb"}
]'
```

Or edit the deployment directly:
```bash
kubectl -n task5 edit deploy webapp
# Fix the MONGODB_URI environment variable
```

Verify the fix:
```bash
kubectl -n task5 rollout restart deploy/webapp
kubectl -n task5 rollout status deploy/webapp
kubectl -n task5 logs -l app=webapp --tail=20
```

## Alternative solutions
- Use ConfigMap/Secret for connection strings
- Add proper health checks and retry logic
- Use MongoDB connection pooling

## Cleanup
```bash
kubectl delete -f task5/manifests/
```
