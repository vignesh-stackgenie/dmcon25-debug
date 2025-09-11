# Task 3: Debug Database Connection

## Scenario
A Python web application needs to connect to a PostgreSQL database. The application is running but failing to connect to the database due to a configuration issue. The web application has been set up with quiet pip installation to avoid cluttering the logs with installation messages.

## Components

1. PostgreSQL Database:
   - Running on port 5432
   - Database name: myapp
   - Username: admin
   - Password: admin123

2. Python Web Application:
   - Simple web server on port 8080
   - Attempts to connect to PostgreSQL
   - Reports connection status via HTTP endpoint
   - Quiet pip installation for cleaner logs

## Current Status

All pods are running, but the web application cannot connect to the database. When accessing the application, you'll see:
```json
{
  "application": "webapp",
  "database_status": "Error: DATABASE_URL environment variable not set"
}
```

## Deploy the Task

```bash
# Create all resources
kubectl apply -f task3/manifests/

# Check pod status
kubectl -n task3 get pods
```

## Debug Steps

1. Check if pods are running:
```bash
kubectl -n task3 get pods
```

2. Verify database pod status:
```bash
kubectl -n task3 logs -l app=postgres
```

3. Check web application logs:
```bash
kubectl -n task3 logs -l app=webapp
```

4. Verify the ConfigMap:
```bash
kubectl -n task3 get configmap app-config -o yaml
```

5. Check environment variables in the web application:
```bash
kubectl -n task3 exec -it $(kubectl -n task3 get pod -l app=webapp -o jsonpath='{.items[0].metadata.name}') -- env | grep DB
```

## Test the Application

```bash
# Port forward the service
kubectl -n task3 port-forward service/webapp 8080:80

# In another terminal
curl localhost:8080
```

## The Issue

The application is failing because:
1. The application looks for environment variable `DATABASE_URL`
2. The deployment sets environment variable `DB_URL`
3. The values need to match for the application to work

## Solution

Fix the environment variable name in the deployment:
```bash
kubectl -n task3 patch deployment webapp --type='json' -p='[
  {"op":"replace",
   "path":"/spec/template/spec/containers/0/env/0/name",
   "value":"DATABASE_URL"}
]'
```

## Verify the Fix

After applying the fix:
```bash
# Wait for new pod to be ready
kubectl -n task3 get pods -w

# Port forward the service
kubectl -n task3 port-forward service/webapp 8080:80

# In another terminal, test the connection
curl localhost:8080
```

Expected output:
```json
{
  "application": "webapp",
  "database_status": "Success: Connected to database"
}
```

## Cleanup

```bash
kubectl delete -f task3/manifests/
```

## Learning Objectives

1. Understanding environment variable configuration in Kubernetes
2. Debugging database connection issues
3. Using ConfigMaps for application configuration
4. Basic Kubernetes service networking
