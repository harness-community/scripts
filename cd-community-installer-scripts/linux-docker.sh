#!/bin/bash
#
# Created on Jan 20, 2023
#
# @author: Ompragash Viswanathan (ompragash@proton.me) GitHub ID: ompragash
#
# Copyright: (c) 2023 Ompragash Viswanathan, <ompragash@harness.io>
# MIT License (see LICENSE or https://choosealicense.com/licenses/mit/)
#

REQUIRED_RAM=3
REQUITED_CPU=2
AVAILABLE_RAM=$(free -g | grep Mem | awk '{ print $2 }')
AVAILABLE_CPU=$(nproc)

# Check system resources and fail if the minimum RAM/CPU requirement isn't met
check_system_requirements() {
    if [[ $AVAILABLE_RAM -lt $REQUIRED_RAM ]]; then
        echo "Error: Insufficient RAM. Requires $REQUIRED_RAM GB, but only $AVAILABLE_RAM GB available."
        return 1
    elif [[ $AVAILABLE_CPU -lt $REQUIRED_CPU ]]; then
        echo "Error: Insufficient CPU. Requires $REQUIRED_CPU cores, but only $AVAILABLE_CPU cores available."
        return 1
    else
        return 0
    fi
}


# Check `git` command. Returns 0 if installed and 1 if not
check_git() {
    if [ -x "$(command -v git)" ]; then
        return 0
    else
        echo "Error: git is not installed. This script requires git to clone Harness CD Community repo."
        echo "Install git and rerun the script."
        return 1
    fi
}

# Install and Enable Docker on Fedora distribution
install_docker_fedora() {
    dnf -y install dnf-plugins-core
    dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
    dnf -y install docker-ce docker-ce-cli containerd.io docker-compose-plugin
    systemctl enable docker; systemctl start docker
}

# Install and Enable Docker on CentOS, AlmaLinux, and RockyLinux distributions
install_docker_centos() {
    dnf -y install yum-utils
    dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    dnf -y install docker-ce docker-ce-cli containerd.io docker-compose-plugin
    systemctl enable docker; systemctl start docker
}

# Install and Enable Docker on Ubuntu-based distributions
install_docker_ubuntu() {
    apt-get update
    apt-get install ca-certificates curl gnupg lsb-release -y
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo   "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    chmod a+r /etc/apt/keyrings/docker.gpg
    apt-get update
    apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y
    systemctl enable docker; systemctl start docker
}

# Install and Enable Docker on Debian-based distributions
install_docker_debian() {
    apt-get update
    apt-get install ca-certificates curl gnupg lsb-release -y
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
    $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    chmod a+r /etc/apt/keyrings/docker.gpg
    apt-get update
    apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y
    systemctl enable docker; systemctl start docker
}

# Function that'll check the linux distribution and call's required install_docker_* function
# from above. Returns 1 if Docker can't be installed.
install_docker() {
    # Check the Linux distribution
    if [ -f /etc/redhat-release ]; then
        # Red Hat-based distribution
        install_docker_centos
    elif [ -f /etc/fedora-release ]; then
        # Fedora distribution
        install_docker_fedora
    elif [ -f /etc/lsb-release ]; then
        # Ubuntu-based distribution
        install_docker_ubuntu
    elif [ -f /etc/debian_version ]; then
        # Debian-based distribution
        install_docker_debian
    else
        echo "Error: Docker is not installed."
        return 1
    fi
}

# Clone harness-cd-community GitHub repo and run docker-compose to setup Harness CD Community
setup_and_start_harness_cd() {
    git clone https://tiny.one/harness-cd-community
    echo "Pulling below docker images mentioned in the docker-compose.yml file..."
    docker compose -f harness-cd-community/docker-compose/harness/docker-compose.yml config | grep 'image:' | awk '{print $2}'
    docker compose -f harness-cd-community/docker-compose/harness/docker-compose.yml pull -q
    export HARNESS_HOST="$(hostname -i)"
    docker compose -f harness-cd-community/docker-compose/harness/docker-compose.yml up -d
    echo "Congratulations! Deployed docker based Harness CD community edition successfully!"
    echo "Access the instance using link: http://$(hostname -i)/#/signup"
}

# Function to check `docker` command. Returns 0 and calls setup_and_start_harness_cd() if installed 
# else installs Docker by calling install_docker)() and 1 if not
check_docker() {
    if [ -x "$(command -v docker)" ]; then
        setup_and_start_harness_cd
        return 0
    else
        if ! install_docker; then
            exit 1
        fi
        setup_and_start_harness_cd
        return 0
    fi
}

#
# **** ENTRYPOINT ****
#
# Script fails if the:
#    - system doesn't meet minimum RAM/CPU required for Harness CD Community to run
#    - if Git cli is not installed
# Script installs docker if it is not installed already.
#

if ! check_system_requirements; then
    exit 1
elif ! check_git; then
    exit 1
else
    check_docker
fi

