# Kubernetes Observability: Installing Prometheus and Grafana Using Helm Charts

To deploy a Prometheus and Grafana monitoring stack on a Kubernetes cluster on an AWS EC2 Ubuntu 24.04 instance using Helm charts, follow these steps:

### Prerequisites

1. **Ubuntu EC2 Setup**: Ensure you have a running EC2 instance with Ubuntu 24.04.
2. **Kubernetes Cluster**: Set up Kubernetes (e.g., `minikube` or a multi-node cluster) on your EC2 instance.
3. **kubectl**: Install and configure `kubectl` on your EC2 instance to manage your Kubernetes cluster.
4. **Helm**: Install Helm on your EC2 instance for deploying applications to Kubernetes.

#### Install Helm

```bash
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

Verify the Helm installation:

```bash
helm version
```

### Step 1: Add Prometheus and Grafana Helm Repositories

Add the official Helm chart repositories for Prometheus and Grafana:

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
```

### Step 2: Install Prometheus

Create a namespace for monitoring:

```bash
kubectl create namespace monitoring
```

Install the Prometheus Helm chart:

```bash
helm install prometheus prometheus-community/prometheus --namespace monitoring
```

To confirm Prometheus installation:

```bash
kubectl get pods -n monitoring
```

### Step 3: Install Grafana

Install the Grafana Helm chart:

```bash
helm install grafana grafana/grafana --namespace monitoring
```

To confirm Grafana installation:

```bash
kubectl get pods -n monitoring
```

### Step 4: Access Prometheus and Grafana

#### Port-forward Prometheus and Grafana Services

To access Prometheus, run:

```bash
kubectl port-forward svc/prometheus-server -n monitoring 9090:80
```

From your local machine, run the following command (replace ec2-user with your actual EC2 username and your-ec2-public-ip with your EC2 instance’s public IP address):

```bash
ssh -i /path/to/your-key.pem -L 9090:127.0.0.1:9090 ec2-user@your-ec2-public-ip
```

Once the Prometheus pods are running, you can access the Prometheus UI:

```bash
kubectl port-forward -n monitoring deploy/prometheus-server 9090:9090
```

Now, access Prometheus at `http://localhost:9090`.

To access Grafana, run:

```bash
kubectl port-forward svc/grafana -n monitoring 3000:80
```

Grafana is now accessible at `http://localhost:3000`.

From your local machine, run the following command (replace ec2-user with your actual EC2 username and your-ec2-public-ip with your EC2 instance’s public IP address):

```bash
ssh -i /path/to/your-key.pem -L 3000:127.0.0.1:3000 ec2-user@your-ec2-public-ip
```

**Access Grafana UI:**
Port-forward the Grafana service:
```bash
kubectl port-forward -n monitoring service/grafana 3000:80
```

Access Grafana UI in your browser: `http://localhost:3000`

#### Get Grafana Admin Password

The default username is `admin`. Retrieve the admin password:

```bash
kubectl get secret --namespace monitoring grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
```

Use the username `admin` and this password to log in.

### Step 5: Set Up Prometheus as a Data Source in Grafana

1. Go to `Settings` > `Data Sources` in Grafana.
2. Select `Prometheus` as the data source and set the URL to `http://prometheus-server.monitoring.svc.cluster.local:80`.
3. Save and test the data source connection.

### Step 6: Import Dashboards in Grafana

Grafana offers predefined dashboards for Prometheus metrics. To import a dashboard:

1. Go to `Create` > `Import` in Grafana.
2. Enter the dashboard ID (e.g., [Prometheus 6417](https://grafana.com/grafana/dashboards/6417)) or upload a JSON file.
3. Choose Prometheus as the data source.

### Optional: Customize the Deployment

You can customize Prometheus and Grafana by using values files with Helm or modifying the resources directly. For example:

```bash
helm upgrade prometheus prometheus-community/prometheus --namespace monitoring --set alertmanager.persistentVolume.enabled=false --set server.persistentVolume.enabled=false
```