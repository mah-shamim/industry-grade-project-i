industry-grade-project-i
=========================
To build a CI/CD pipeline for a retail company on an *AWS EC2 Ubuntu 24.04 instance*, you'll follow a step-by-step guide. Below is the full solution for each step, integrating Jenkins, Docker, Ansible, Kubernetes, Prometheus, and Grafana.

---

### *1. Set Up the EC2 Environment*
Launch an *Ubuntu 24.04 EC2 instance* from AWS Management Console:
- Ensure the following:
    - Choose *Ubuntu 24.04 LTS* AMI.
    - Select a proper instance type, e.g., *t2.medium* (for better performance).
    - Allow SSH, HTTP, and HTTPS traffic under *security groups*.

*Access the EC2 Instance:*
- SSH into the instance using the PEM key.
```bash
  ssh -i "your-key.pem" ubuntu@ec2-public-ip
```

---

### *2. Install Required Tools*
Start by updating the system and installing the prerequisites:

#### *Update System Packages:*
```bash
sudo apt-get update
sudo apt-get upgrade -y
```

#### *Install Java:*
```bash
sudo apt-get install default-jdk -y
java -version
```

#### *Install Maven:*
```bash
sudo apt-get install maven -y
mvn -version
```

#### *Install Git:*
```bash
sudo apt-get install git -y
git --version
```

#### *Install Docker:*
```bash
sudo apt-get install docker.io -y
sudo systemctl start docker
sudo systemctl enable docker
docker --version
```
Add your user to the docker group:
```bash
sudo usermod -aG docker $USER
```
Then logout and re-login for group changes to take effect.

#### *Install Jenkins:*
```bash
wget -q -O - https://pkg.jenkins.io/debian/jenkins.io.key | sudo apt-key add -
sudo sh -c 'echo deb http://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'
sudo apt-get update
sudo apt-get install jenkins -y
sudo systemctl start jenkins
sudo systemctl enable jenkins
```
- Visit Jenkins on http://<EC2_PUBLIC_IP>:8080
- Get the initial password to unlock Jenkins:
```bash
  sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

#### *Install Ansible:*
```bash
sudo apt-get install ansible -y

    # Create Ansible hosts file
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

#### *Install Kubernetes Tools:*
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


#### *Install Prometheus & Grafana:*
1. *Prometheus*:
   ```bash
   wget https://github.com/prometheus/prometheus/releases/download/v2.40.3/prometheus-2.40.3.linux-amd64.tar.gz
   tar -xvzf prometheus-2.40.3.linux-amd64.tar.gz
   cd prometheus-2.40.3.linux-amd64/
   ./prometheus --config.file=prometheus.yml
   ```


2. *Grafana*:
   ```bash
   sudo apt-get install -y software-properties-common
   sudo add-apt-repository "deb https://packages.grafana.com/oss/deb stable main"
   sudo apt-get update
   sudo apt-get install grafana -y
   sudo systemctl start grafana-server
   sudo systemctl enable grafana-server
   ```

- Access Grafana at http://<EC2_PUBLIC_IP>:3000 (default login: *admin/admin*).

---

### *3. Jenkins Pipeline Configuration*

#### *Step 1: Create Jenkins Pipeline*
1. Login to *Jenkins* (http://<EC2_PUBLIC_IP>:8080).
2. Install the required plugins:
    - *Docker Plugin*
    - *Ansible Plugin*
    - *Kubernetes Plugin*

3. Create a *Freestyle Job* for each task:
    - *Compile Job*: Uses Maven to compile the code.
    - *Test Job*: Runs tests.
    - *Package Job*: Packages the code into a .war file.

#### *Step 2: Setup Docker Integration*

*Dockerfile* example to deploy the .war to a Tomcat server:
```dockerfile
FROM iamdevopstrainer/tomcat:base
COPY target/ABCtechnologies-1.0.war /usr/local/tomcat/webapps/
CMD ["catalina.sh", "run"]
```

Build the Docker image and push it to DockerHub:
```bash
docker build -t mahshamim/abstechnologies:latest .
docker login
docker push mahshamim/abstechnologies:latest
```

Configure Jenkins to build and push Docker images after packaging.

#### *Step 3: Write Jenkinsfile*
A basic *Jenkinsfile* for CI/CD:
```groovy
pipeline {
    agent any
    environment {
        DOCKER_CREDENTIALS_ID = 'dockerhub' // Jenkins ID for DockerHub credentials
        DOCKER_IMAGE = 'mahshamim/abstechnologies'
        DOCKER_REGISTRY = 'https://index.docker.io/v1/' // For DockerHub, this is the registry URL
        CONTAINER_NAME = "abctechnologies"
        DOCKER_TAG = "${BUILD_ID}"  // Use the BUILD_ID as the tag for versioning
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
                sh 'ls -l target/'  // List contents of the target directory
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    // Build the Docker image and tag it with the $BUILD_ID
                    dockerImage = docker.build("${DOCKER_IMAGE}:${DOCKER_TAG}")
                }
            }
        }

        stage('Login to DockerHub') {
            steps {
                script {
                    // Login to DockerHub using Jenkins credentials
                    docker.withRegistry(DOCKER_REGISTRY, DOCKER_CREDENTIALS_ID) {
                        echo 'Logged into DockerHub'
                    }
                }
            }
        }

        stage('Push Docker Image') {
            steps {
                script {
                    docker.withRegistry(DOCKER_REGISTRY, DOCKER_CREDENTIALS_ID) {
                        // Push the Docker image to the registry
                        dockerImage.push("${DOCKER_TAG}")
                    }
                }
            }
        }
        stage('Run Docker Container') {
            steps {
                script {
                    // Stop any running container with the same name
                    sh '''
                    if [ $(docker ps -q -f name=${CONTAINER_NAME}) ]; then
                        docker stop ${CONTAINER_NAME}
                        docker rm ${CONTAINER_NAME}
                    fi
                    '''

                    // Run a new container from the pushed image
                    sh "docker run -d --name ${CONTAINER_NAME} -p 9191:8080 ${DOCKER_IMAGE}:${DOCKER_TAG}"
                }
            }
        }
    }

    post {
        success {
            echo 'Docker image built and pushed successfully!'
        }
        failure {
            echo 'The build or push failed.'
        }
    }
}
```

---

### *4. Ansible Playbook and Kubernetes Deployment*

#### *Step 4: Write Ansible Playbook*
Example *playbook.yml* to build Docker image and push:
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
Integrate Ansible with Jenkins by running this playbook.

#### *Step 5: Deploy to Kubernetes*
Create a *Kubernetes deployment* file (deployment.yml):
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: abstechnologies
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

Apply the deployment:
```bash
kubectl apply -f deployment.yml
```

### 1. *Enable Kubernetes Dashboard*
If you haven't already enabled the Kubernetes dashboard, you need to do so by running the following commands on your EC2 instance:

```bash
minikube addons enable dashboard
```

### 2. *Access the Dashboard*
Start the Kubernetes dashboard using:

```bash
minikube dashboard --url
```

This command will start the dashboard and give you a URL to access it. However, the URL will only be accessible from the local environment (EC2 instance) by default.

### 3. *Port Forwarding to Access Dashboard Remotely*
Since you're using AWS EC2, to access the Kubernetes dashboard from your local machine (laptop or desktop), you need to set up port forwarding. You can use SSH tunneling for that.

From your local machine, run the following command (replace ec2-user with your actual EC2 username and your-ec2-public-ip with your EC2 instance’s public IP address):

```bash
ssh -i /path/to/your-key.pem -L 8001:127.0.0.1:8001 ec2-user@your-ec2-public-ip
```

This will forward traffic from your local port 8001 to the same port on the EC2 instance.

### 4. *Start the Proxy*
On your EC2 instance, start the kubectl proxy to forward API requests from the browser to the Kubernetes cluster:

```bash
kubectl proxy --port=8001
```

### 5. *Access the Dashboard from Your Browser*
Now, on your local machine, open the following URL in your web browser:


http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/http:kubernetes-dashboard:/proxy/


This should bring up the Kubernetes dashboard.

### 6. *Authentication*
The Kubernetes dashboard may ask for an authentication token. To get the token, you can use this command on the EC2 instance:

```bash
kubectl -n kubernetes-dashboard create token admin-user
```

Copy the token and use it for logging into the dashboard.



---

### *5. Monitoring with Prometheus and Grafana*

#### *Step 6: Install Prometheus Node Exporter*
Install *node_exporter* on EC2 to monitor system metrics:
```bash
wget https://github.com/prometheus/node_exporter/releases/download/v1.3.1/node_exporter-1.3.1.linux-amd64.tar.gz
tar -xvzf node_exporter-1.3.1.linux-amd64.tar.gz
cd node_exporter-1.3.1.linux-amd64/
./node_exporter
```

#### *Step 7: Configure Prometheus*
Edit *prometheus.yml* to add the EC2 instance as a target:
```yaml
scrape_configs:
- job_name: 'node_exporter'
  static_configs:
    - targets: ['localhost:9100']
```
Start Prometheus to monitor EC2 instance metrics.

#### *Step 8: Create Grafana Dashboard*
- In Grafana, add *Prometheus* as a data source.
- Create a dashboard using metrics like CPU usage, memory, and network.

---

### *6. Submission*
- Ensure all the code is in a GitHub repository.
- Document all steps with screenshots and submit the GitHub link.

---

This detailed solution will help you build a robust CI/CD pipeline, ensuring scalability and high performance for your retail company project.