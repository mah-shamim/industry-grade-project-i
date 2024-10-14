#!/bin/bash

# Deploy to Ansible
echo "Deploying to Ansible..."
ansible-playbook -i inventory.ini playbook.yml --become || { echo "Failed to apply Ansible deployment! Exiting."; exit 1; }

# Deploy to Kubernetes
echo "Deploying to Kubernetes..."
kubectl apply -f /home/ubuntu/industry-grade-project-i/k8s_deployments/deployment.yml --validate=false || { echo "Failed to apply Kubernetes deployment! Exiting."; exit 1; }
kubectl apply -f /home/ubuntu/industry-grade-project-i/k8s_deployments/service.yaml --validate=false || { echo "Failed to apply Kubernetes service! Exiting."; exit 1; }

# Log some debugging information
echo "Currently running Docker containers:"
docker ps

echo "Current Kubernetes deployments:"
kubectl get deployments

echo "Current Kubernetes services:"
kubectl get services
