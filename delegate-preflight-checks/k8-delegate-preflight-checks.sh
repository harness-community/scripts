#!/bin/bash

# FUNCTIONS

# Check for docker installation, otherwise prompt user to install
check_and_install_docker() {
    # Check if docker is already installed
    echo "Checking Docker."
    if command -v docker &> /dev/null; then
        echo "Docker is installed."
    else
        # Prompt the user for installation
        read -p "Docker is not installed. Do you want to install Docker? (Y/n): " choice

        # Make choice case-insensitive
        choice=${choice,,}

        if [ "$choice" == "y" ] || [ -z "$choice" ]; then
            curl -fsSL https://get.docker.com -o get-docker.sh
            sh get-docker.sh 
	    sudo groupadd docker
	    sudo usermod -aG docker $USER
            echo "Docker installed successfully."
        else
            echo "ERROR: Docker installation was skipped. Docker is required to proceed."
	    exit 1
        fi
    fi
}

check_and_install_cluster() {
    # Check if cluster available
    echo "Checking for cluster."
    if kubectl cluster-info &> /dev/null; then
        echo "Cluster connection successful."
    else
        # Prompt to install local cluster
        read -p "Cluster not found. Would you like to set up a local cluster with K3D? (Y/n): " choice

        # Make choice case-insensitive
        choice=${choice,,}

        if [ "$choice" == "y" ] || [ -z "$choice" ]; then
            check_and_install_docker
	    newgrp docker << EOF
            sudo systemctl enable --now docker 
	    curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
	    k3d cluster create mycluster
	    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
	    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
	    kubectl get nodes
            echo "K3D installed successfully."
EOF
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

# Check if cluster exists, otherwise prompt to install
check_and_install_cluster

# Check available resources against delegate requirements
check_resources

