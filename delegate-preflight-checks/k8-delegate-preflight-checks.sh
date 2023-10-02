#!/bin/bash

# FUNCTIONS

# Linux: Check for docker installation, otherwise prompt user to install
check_and_install_docker_linux() {
    # Check if docker is already installed
    echo "Checking Docker."
    if docker ps > /dev/null 2>&1; then
        echo "Docker is installed."
    else
        # Prompt the user for installation
        read -p "Docker is not installed. Do you want to install Docker? (Y/n): " choice

        # Make choice case-insensitive

        if [ "$choice" == "Y" ]; then
            sh <(curl -fsSL https://get.docker.com)
	    sudo groupadd docker
	    sudo usermod -aG docker $USER
            echo "Docker installed successfully."
        else
            echo "ERROR: Docker installation was skipped. Docker is required to proceed."
	    exit 1
        fi
    fi
}

# Mac: Check for docker installation, otherwise prompt user to install 
check_and_install_docker_mac() {
    # Check if docker is already installed
    echo "Checking Docker."
    if docker ps > /dev/null 2>&1; then
        echo "Docker is installed."
    else
        # Prompt the user for installation
        read -p "Unable to connect to Docker. Do you want to install and configure Docker? (Y/n): " choice

        if [ "$choice" == "Y" ]; then
            architecture=$(uname -m)
            if [[ "$architecture" == "x86_64" ]]; then
                curl -fsSL https://desktop.docker.com/mac/main/amd64/Docker.dmg
            elif [[ "$architecture" == "arm"* || "$architecture" == "aarch64" ]]; then
                curl -fsSL https://desktop.docker.com/mac/main/arm64/Docker.dmg -o Docker.dmg
            else
                echo "ERROR: Could not determine system architecture"
                exit 1
            fi
            sudo hdiutil attach Docker.dmg
            sudo /Volumes/Docker/Docker.app/Contents/MacOS/install --accept-license
            sudo hdiutil detach /Volumes/Docker
            rm Docker.dmg
            echo "DOCKER SUCCESSFULLY INSTALLED."
            open /Applications/Docker.app
            connect_retry_count=0
            max_connect_retries=10
            while true; do
                echo "Opening Docker, waiting for Docker engine to start."
                echo "Accept the terms if prompted."
                echo "You can skip creating a new account if prompted."
                echo "Enter password when prompted to accept default permissions."
                docker ps > /dev/null 2>&1
                if [ $? -eq 0 ]; then
                    echo "Successfully connected to docker."
                    sleep 15
                    break
                else
                    ((connect_retry_count++))
                    if [[ $connect_retry_count -ge $max_connect_retries ]]; then
                        echo "ERROR: Failed to connect to Docker after $max_connect_retries attempts. Exiting."
                        exit 1
                    else
                        echo "Unable to connect to Docker. Retrying... ($connect_retry_count/$max_connect_retries)"
                        sleep 10
                    fi
                fi
            done
        else
            echo "ERROR: Docker installation was skipped. Docker is required to proceed."
            exit 1
        fi
    fi
}


# Linux: Check and install kubectl
check_and_install_kubectl_linux() {
    if which kubectl > /dev/null 2>&1; then
        echo "kubectl command exists"
    else
        if [[ "$(uname -m)" == "x86_64" ]]; then
            curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        elif [[ "$(uname -m)" == "arm"* || "$architecture" == "aarch64" ]]; then
            curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/arm64/kubectl"
        fi
        sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    fi
}

# Mac: Check and install kubectl
check_and_install_kubectl_mac() {
    if which kubectl > /dev/null 2>&1; then
        echo "kubectl command exists"
    else
        if [[ "$(uname -m)" == "x86_64" ]]; then
            curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/amd64/kubectl"
        elif [[ "$(uname -m)" == "arm"* || "$architecture" == "aarch64" ]]; then
            curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/arm64/kubectl"
        fi
        chmod +x ./kubectl
        sudo mv ./kubectl /usr/local/bin/kubectl
        sudo chown root: /usr/local/bin/kubectl
    fi
}

# Install K3D
download_and_install_k3d() {
            curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
            k3d cluster create mycluster
            if [[ "$(uname -s)" == "Linux" ]]; then
                check_and_install_kubectl_mac
            elif [[ "$(uname -s)" == "Darwin" ]]; then
                check_and_install_kubectl_mac
            fi
            kubectl get nodes
            echo "K3D installed successfully."
}

check_and_install_cluster() {
    # Check if cluster available
    echo "Checking for cluster."
    if kubectl cluster-info &> /dev/null; then
        echo "Cluster connection successful."
    else
        # Prompt to install local cluster
        read -p "Cluster not found. Would you like to set up a local cluster with K3D? (Y/n): " choice

        if [ "$choice" == "Y" ]; then
            if [[ "$(uname -s)" == "Linux" ]]; then
                check_and_install_docker_linux
                newgrp docker << EOF
                sudo systemctl enable --now docker
                download_and_install_k3d
EOF
            elif [[ "$(uname -s)" == "Darwin" ]]; then
                check_and_install_docker_mac
                download_and_install_k3d
            else
                echo "ERROR: Unsupported operating system."
                exit 1
            fi
        else
            echo "ERROR: A Kubernetes cluster is required to proceed."
            exit 1
        fi
    fi
}

# Check if a given command exists
check_command_exists() {
    local command="$1"
    
    if ! command -v "$command" &> /dev/null; then
        echo "$command could not be found. Please install $command."
        exit 1
    fi
}

# Check Kubernetes cluster connectivity
check_k8s_connectivity() {
    if ! kubectl cluster-info &> /dev/null; then
        echo "Cannot connect to a Kubernetes cluster. One is needed."
        exit 1
    fi
}

# Get available memory from the Kubernetes cluster in MiB
get_available_memory_mib() {
    kubectl describe node | awk '/Allocatable:/,/---/ { if(/memory/) print $2; }' | sed 's/Ki//' | awk '{s+=$1} END {printf "%.0f", s/1024}'  # Convert Ki to MiB
}

# Get available CPU cores from the Kubernetes cluster (millicores)
get_available_cpu_scaled() {
    kubectl describe node | awk '/Allocatable:/,/---/ { if(/cpu/) print $2; }'| awk '{
        if (index($1,"m")) { 
            print $1+0;  # If in millicores, strip the 'm' character
        } else {
            print $1*1000;  # If in whole number, convert to millicores
        }
    }' | awk '{s+=$1} END {print s}'
}

# Check if the available resources meet delegate requirements
check_resources() {
    local memory_required_mib=$((2*1024))  # 2 GB in MiB
    local cpu_required_scaled=500  # 0.5 CPU scaled by 1000

    local memory_available_mib=$(get_available_memory_mib)
    local cpu_available_scaled=$(get_available_cpu_scaled)
    
    echo "Required memory is $memory_required_mib MiB"
    echo "Available memory is $memory_available_mib MiB"
    echo "Required cpu is $cpu_required_scaled m"
    echo "Available cpu is $cpu_available_scaled m"

    if [ "$memory_available_mib" -ge "$memory_required_mib" ] && [ "$cpu_available_scaled" -ge "$cpu_required_scaled" ]; then
        echo "Cluster has enough resources available for delegate."
    else
        echo "ERROR: Not enough resources available for delegate. Required: At least 2 GB memory and 0.5 CPU. Check your cluster resources."
        exit 1
    fi
}

# --------------------------------------------------

# MAIN PROGRAM

echo "Some commands may require sudo. Enter your password if prompted."

# Check if cluster exists, otherwise prompt to install
check_and_install_cluster

# Check available resources against delegate requirements
check_resources
