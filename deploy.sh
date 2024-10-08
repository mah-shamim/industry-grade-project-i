#!/bin/bash

DOCKER_IMAGE="mahshamim/abstechnologies"
CONTAINER_NAME="abctechnologies"
DOCKER_TAG=$BUILD_ID
PORT=9191

# Check if the container is running
if [ "$(docker ps -q -f name=$CONTAINER_NAME)" ]; then
    echo "Stopping and removing existing container..."
    docker stop $CONTAINER_NAME
    docker rm $CONTAINER_NAME
fi

# Build the Docker image
echo "Building Docker image with tag $CONTAINER_NAME:$DOCKER_TAG..."
docker build -t $CONTAINER_NAME:$DOCKER_TAG .

# Run the container
echo "Running Docker container on port $PORT..."
docker run -d -p $PORT:80 --name DOCKER_IMAGE $CONTAINER_NAME:$DOCKER_TAG
