### CI/CD Pipeline for Retail Company on AWS EC2 with Jenkins, Docker, Ansible, Kubernetes, Prometheus, and Grafana

This guide provides a comprehensive setup for creating a CI/CD pipeline using various tools such as Jenkins, Docker, Ansible, Kubernetes, Prometheus, and Grafana, all deployed on an AWS EC2 Ubuntu 24.04 instance.

---

### Prerequisites:
- **AWS EC2 Ubuntu 24.04 instance**
- Access to **GitHub** and **DockerHub**
- Required tools: **Java**, **Maven**, **Git**, **Jenkins**, **Docker**, **Ansible**, **Kubernetes**, **Prometheus**, and **Grafana** pre-installed.

---

### **1. Setup the AWS EC2 Instance**

#### 1.1 Launch an EC2 Instance:
- Log in to your AWS account.
- Navigate to the EC2 dashboard and launch a new instance.
- Choose **Ubuntu Server 24.04 LTS** as the AMI.
- Select an instance type (e.g., `t2.micro` for testing).
- Configure security groups to allow the following ports:
    - SSH (port 22)
    - HTTP (port 80)
    - HTTPS (port 443)
    - Jenkins (port 8080)
    - Docker (port 2376)
    - Grafana (port 3000)
- Add an SSH key pair for connecting to your instance.

#### 1.2 Connect to the Instance:
- Open **Terminal (Linux/Mac)** or **Putty (Windows)**.
- Navigate to the directory where your `.pem` file is saved.
- Connect using the following command (replace `<key-file>` and `<public-ip>`):
    ```bash
    chmod 400 <key-file>.pem
    ssh -i <key-file>.pem ubuntu@<public-ip>
    ```

#### 1.3 Update and Upgrade Packages:
```bash
sudo apt-get update && sudo apt-get upgrade -y
```

---

### **2. Install Required Tools**

#### 2.1 Install Java:
Jenkins requires Java to run.
```bash
sudo apt install openjdk-11-jdk -y
java -version
```

#### 2.2 Install Git:
```bash
sudo apt-get install git -y
git --version
```

#### 2.3 Install Maven:
Maven is used to build Java projects.
```bash
sudo apt install maven -y
mvn -version
```

#### 2.4 Install Docker:
Docker will containerize the application.
```bash
sudo apt-get install docker.io -y
sudo systemctl start docker
sudo systemctl enable docker
docker --version
```
Add your user to the Docker group:
```bash
sudo usermod -aG docker $USER
```
Log out and re-login for the group changes to take effect.

#### 2.5 Install Jenkins:
Jenkins automates builds and deployments.
```bash
wget -q -O - https://pkg.jenkins.io/debian/jenkins.io.key | sudo apt-key add -
sudo sh -c 'echo deb http://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'
sudo apt-get update
sudo apt-get install jenkins -y
sudo systemctl start jenkins
sudo systemctl enable jenkins
```

**Permissions and Jenkins Docker Setup**:
```bash
if command_exists docker && command_exists jenkins; then
    sudo usermod -aG $DOCKER_USER $JENKINS_USER
    sudo chmod 666 /var/run/docker.sock
    echo "jenkins ALL=(ALL) NOPASSWD: ALL" | sudo tee -a /etc/sudoers.d/jenkins
fi
```

- Visit Jenkins on `http://<EC2_PUBLIC_IP>:8080`
- Get the initial password to unlock Jenkins:
```bash
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

#### 2.6 Install Ansible:
Ansible will automate the deployment process.
```bash
sudo apt-get install ansible -y

# Create Ansible hosts file
mkdir ~/ansible
sudo tee ~/ansible/hosts > /dev/null <<EOL
[local]
localhost ansible_connection=local
EOL

# Create Ansible configuration file
sudo tee ~/ansible/ansible.cfg > /dev/null <<EOL
[defaults]
inventory = ./inventory

[privilege_escalation]
become = true
become_method = sudo
EOL
ansible --version
```

**Add Remote Hosts to Inventory**:
Edit the `~/ansible/hosts` file to include your remote servers:
```bash
[webservers]
remote-server-ip ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/your-key.pem
```

#### 2.7 Install Kubernetes Tools:
Install *kubectl* and *minikube*:
```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
chmod +x minikube-linux-amd64
sudo mv minikube-linux-amd64 /usr/local/bin/minikube

minikube start
```

#### 2.8 Install Prometheus & Grafana:
##### 2.8.1 Install Prometheus:
```bash
wget https://github.com/prometheus/prometheus/releases/download/v2.40.3/prometheus-2.40.3.linux-amd64.tar.gz
tar -xvzf prometheus-2.40.3.linux-amd64.tar.gz
cd prometheus-2.40.3.linux-amd64/
./prometheus --config.file=prometheus.yml
```

##### 2.8.2 Install Grafana:
```bash
sudo apt-get install -y software-properties-common
sudo add-apt-repository "deb https://packages.grafana.com/oss/deb stable main"
sudo apt-get update
sudo apt-get install grafana -y
sudo systemctl start grafana-server
sudo systemctl enable grafana-server
```

- Access Grafana at `http://<EC2_PUBLIC_IP>:3000` (default login: *admin/admin*).

---

### **3. Build a CI/CD Pipeline**

#### 3.1 Clone the GitHub Repository:
Clone the project repository to your EC2 instance:
```bash
git clone https://github.com/mah-shamim/industry-grade-project-i.git
cd industry-grade-project-i
```

#### 3.2 Create Jenkins Pipeline:
1. **Login to Jenkins** (`http://<EC2_PUBLIC_IP>:8080`).
2. Install required plugins:
    - Docker Plugin
    - Ansible Plugin
    - Kubernetes Plugin
3. **Integrate GitHub with Jenkins**:
    - Add GitHub credentials:
        - Go to Jenkins Dashboard > Manage Jenkins > Manage Credentials.
        - Add a new set of credentials with:
            - Secret Text: Your GitHub Personal Access Key.
            - ID: Recognizable ID like `github`.
4. **Set up a new Jenkins pipeline**:
    - Create Docker Hub Credentials:
        - Go to Jenkins Dashboard > Manage Jenkins > Manage Credentials.
        - Add a new set of credentials with:
            - Username: Your Docker Hub username.
            - Password: Your Docker Hub password or access token.
            - ID: Recognizable ID like `dockerhub`.
5. **Install Docker Plugin in Jenkins**:
    - Go to Manage Jenkins > Manage Plugins > Available.
    - Search for "Docker" and install the "Docker" and "Docker Pipeline" plugins.
    - Restart Jenkins if prompted.

#### 3.3 Create a Freestyle Job for Each Task:
- **Compile Job**: Uses Maven to compile the code.
- **Test Job**: Runs tests.
- **Package Job**: Packages the code into a .war file.

#### 3.4 Dockerfile Example:
Example *Dockerfile* to deploy the .war to a Tomcat server:
```dockerfile
FROM iamdevopstrainer/tomcat:base
COPY target/ABCtechnologies-1.0.war /usr/local/tomcat/webapps/
CMD ["catalina.sh", "run"]
```

#### 3.5 Build and Push Docker Image:
```bash
docker build -t mahshamim/abstechnologies:latest .
docker login
docker push mahshamim/abstechnologies:latest
```

Configure Jenkins to build and push Docker images after packaging.

#### 3.6 Write Jenkinsfile:
Here’s a basic *Jenkinsfile* for CI/CD:
```groovy
pipeline {
    agent any
    environment {
        DOCKER_CREDENTIALS_ID = 'dockerhub' // Jenkins ID for DockerHub credentials
        DOCKER_IMAGE = 'mahshamim/abstechnologies'
        DOCKER_REGISTRY = 'https://index.docker.io/v1/' // For DockerHub
        CONTAINER_NAME = "abctechnologies"
        DOCKER_TAG = "${BUILD_ID}"  // Use the BUILD_ID as the tag
    }
    stages {
        stage('Code Checkout') {
            steps {
                git branch: 'master', url: 'https://github.com/mah-shamim/industry-grade-project-i.git'
            }
        }

        stage('Build') {
            steps {
                sh 'mvn clean compile'
            }
        }

        stage('Test') {
            steps {
                sh 'mvn test'
            }
        }

        stage('Package') {
            steps {
                sh 'mvn package'
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    docker.build("${DOCKER_IMAGE}:${DOCKER_TAG}")
                }
            }
        }

        stage('Push to DockerHub') {
            steps {
                script {
                    docker.withRegistry("${DOCKER_REGISTRY}", "${DOCKER_CREDENTIALS_ID}") {
                        docker.image("${DOCKER_IMAGE}:${DOCKER_TAG}").push()
                    }
                }
            }
        }
    }
    post {
        always {
            cleanWs()
        }
    }
}
```

#### 3.7 Configure Deployment Using Ansible:
Create an Ansible playbook for deployment:
```yaml
---
- hosts: localhost
  become: yes
  become_method: sudo
  become_user: root
  vars:
    docker_tag: "v1.0"  # Change this to any tag you want
    container_name: "abctechnologies"
  tasks:
    - name: Check if Docker is already installed
      command: docker --version
      register: docker_installed
      ignore_errors: true

    - name: Install Docker
      apt:
        name: docker.io
        state: present
      when: docker_installed.rc != 0

    - name: Start Docker Service
      service:
        name: docker
        state: started
        enabled: true

    - name: Build WAR file using Maven (if applicable)
      command: mvn clean package
      args:
        chdir: ./
      when: docker_installed.rc == 0  # Run only if Docker is installed

    - name: Build Docker Image
      command: docker build -t mahshamim/abstechnologies .

    - name: Stop existing Docker container if running
      command: docker stop {{ container_name }}
      ignore_errors: true

    - name: Remove existing Docker container if exists
      command: docker rm {{ container_name }}
      ignore_errors: true

    - name: Run Docker Container
      command: docker run -d --name {{ container_name }} -p 9292:8080 mahshamim/abstechnologies

    - name: Log in to Docker Hub
      command: docker login -u "mahshamim" -p "01614747054@R!f"
      no_log: true

    - name: Tag Docker image for Docker Hub
      command: docker tag mahshamim/abstechnologies "mahshamim/abstechnologies:{{ docker_tag }}"

    - name: Push Docker image to Docker Hub
      command: docker push "mahshamim/abstechnologies:{{ docker_tag }}"
```

**Test the Ansible Playbook:** Run the following command to execute the playbook:
```bash
ansible-playbook ~/ansible/palybook.yml
```
OR
```bash
ansible-playbook -i inventory.ini playbook.yml --become
```
#### 3.8 Deploy Artifacts to Kubernetes
3.8.1. **Kubernetes Deployment Manifest**:
Create a file named `deployment.yaml`:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: abstechnologies-deployment
spec:
  replicas: 2
  selector:
    matchLabels:
      app: abstechnologies
  template:
    metadata:
      labels:
        app: abstechnologies
    spec:
      containers:
        - name: abstechnologies
          image: mahshamim/abstechnologies:latest
          ports:
            - containerPort: 8080
```

3.8.2. **Service Manifest**:
Create a file named `service.yaml`:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: abstechnologies-service
spec:
  type: NodePort
  ports:
    - port: 8080
      targetPort: 8080
      nodePort: 30000
  selector:
    app: abstechnologies
```

3.8.3. **Deploy to Kubernetes**:
Run the following commands:
```bash
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
```

### 3.8.4. *Enable Kubernetes Dashboard*
If you haven't already enabled the Kubernetes dashboard, you need to do so by running the following commands on your EC2 instance:

```bash
minikube addons enable dashboard
```

### 3.8.5. *Access the Dashboard*
Start the Kubernetes dashboard using:

```bash
minikube dashboard --url
```

This command will start the dashboard and give you a URL to access it. However, the URL will only be accessible from the local environment (EC2 instance) by default.

### 3.8.6. *Port Forwarding to Access Dashboard Remotely*
Since you're using AWS EC2, to access the Kubernetes dashboard from your local machine (laptop or desktop), you need to set up port forwarding. You can use SSH tunneling for that.

From your local machine, run the following command (replace ec2-user with your actual EC2 username and your-ec2-public-ip with your EC2 instance’s public IP address):

```bash
ssh -i /path/to/your-key.pem -L 8001:127.0.0.1:8001 ec2-user@your-ec2-public-ip
```

This will forward traffic from your local port 8001 to the same port on the EC2 instance.

### 3.8.7. *Start the Proxy*
On your EC2 instance, start the kubectl proxy to forward API requests from the browser to the Kubernetes cluster:

```bash
kubectl proxy --port=8001
```

### 3.8.9. *Access the Dashboard from Your Browser*
Now, on your local machine, open the following URL in your web browser:


http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/http:kubernetes-dashboard:/proxy/


This should bring up the Kubernetes dashboard.

### 3.8.10. *Authentication*
The Kubernetes dashboard may ask for an authentication token. To get the token, you can use this command on the EC2 instance:

```bash
kubectl -n kubernetes-dashboard create token admin-user
```

Copy the token and use it for logging into the dashboard.



### **4. Set Up Monitoring with Prometheus and Grafana**

#### 4.1 Configure Prometheus
1. **Edit Prometheus Configuration**:
   Open the `prometheus.yml` file and add your service endpoint for monitoring:
   ```yaml
   scrape_configs:
     - job_name: 'kubernetes-services'
       kubernetes_sd_configs:
         - role: endpoints
       relabel_configs:
         - action: labelmap
           regex: __meta_kubernetes_service_label_(.+)
         - source_labels: [__meta_kubernetes_service_name]
           action: replace
           target_label: service
           replacement: $1
   ```

2. **Start Prometheus**:
   Restart Prometheus with the updated configuration. You may want to run it as a Docker container for easier management:
   ```bash
   docker run -d -p 9090:9090 \
       --name prometheus \
       -v $(pwd)/prometheus.yml:/etc/prometheus/prometheus.yml \
       prom/prometheus
   ```
   OR
   ```bash
   /home/ubuntu/prometheus-2.40.3.linux-amd64/prometheus --config.file=prometheus.yml --web.listen-address=":9091"
   ```

#### 4.2 Configure Grafana
1. **Access Grafana**:
   Go to `http://<EC2_PUBLIC_IP>:3000` and log in using the default credentials (`admin/admin`).

2. **Add Prometheus as a Data Source**:
    - Go to Configuration > Data Sources.
    - Click on “Add Data Source”.
    - Select “Prometheus”.
    - Set the URL to `http://<EC2_PUBLIC_IP>:9090`.
    - Click on “Save & Test”.

3. **Create Dashboards**:
    - Create a new dashboard to visualize metrics.
    - Use queries like `rate(http_requests_total[5m])` to view request rates, etc.

4. **Import Docker Dashboard**:
    - Go to Create > Import in Grafana.
    - Use the dashboard ID 893 (a popular cAdvisor and Docker monitoring dashboard) or 1229 (another Docker metrics dashboard) from the Grafana website.
    - Click Load.
    - Select your Prometheus data source and click Import.
    - This will create a dashboard to visualize metrics such as CPU, memory, disk, and network usage for Docker containers.

5. **Import Jenkins Dashboard**:
    - Go to Create > Import in Grafana.
    - Use the dashboard ID 11501 (Jenkins Prometheus Exporter) from the Grafana website.
    - Click Load.
    - Select your Prometheus data source and click Import.
    - This dashboard includes visualizations for Jenkins job metrics, build times, queue lengths, and more.

6. **Here are a few commonly used Grafana Dashboard IDs**:
    - 449: Networking and Load Balancers
    - 893: Docker and cAdvisor monitoring.
    - 1860: Node Exporter Full for Linux servers.
    - 11501: Jenkins monitoring using Prometheus metrics.
    - 2583: MySQL overview with Prometheus as the data source.
    - 11074: Elasticsearch monitoring.
    - 10701: Nginx monitoring.
    - Visit the Grafana Dashboards Repository for find more.

---

### **5. Final Testing and Verification**

1. **Run the CI/CD Pipeline**:
    - Trigger the pipeline in Jenkins and observe the logs for each stage.
    - Ensure Docker images are built and pushed to DockerHub.
    - Verify Kubernetes deployments and services are correctly set up.

2. **Access Application and Monitoring Tools**:
    - Visit your application at the LoadBalancer's external IP.
    - Check Prometheus at `http://<EC2_PUBLIC_IP>:9090`.
    - Review your Grafana dashboards to ensure metrics are being collected and displayed.

---


### Conclusion
Your CI/CD pipeline is now set up! This configuration allows you to automate your deployment process using Jenkins and Docker, monitor your applications with Prometheus, and visualize performance with Grafana.

Make sure to test your setup thoroughly and modify the configurations as needed to suit your application requirements.

---

Feel free to ask if you have any questions or need further assistance!