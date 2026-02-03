#!/bin/bash

: << 'COMMENT'
##########################################################################################################################
      installing softwares : 
          open jdk 21
          jenkins
          maven
          docker engine
          kubectl
          aws cli
          eksctl
          zip and unzip
        
        USAGE: ./aws-project.sh <cluster> <region> <nodegroup> <nodes> <min> <max> <instance-type>
##########################################################################################################################
COMMENT

set -euo pipefail

# validation
if (( $# != 7 )); then

  echo "ERROR: Provide the correct usage." >&2

  echo "USAGE: $0 <cluster> <region> <nodegroup> <nodes> <min> <max> <instance-type>"

  exit 1

fi

if [[ "$(lsb_release -is 2>/dev/null)" != "Ubuntu" ]]; then

    echo "ERROR: This script supports Ubuntu only." >&2

    exit 1

fi

zip_unzip_install() {

    if ! command -v zip > /dev/null >&2 || ! command -v unzip > /dev/null >&2; then 

        echo "zip and unzip are not installed. installing..." 

        sudo apt install zip unzip -y

    fi
}

openjdk_install() {
    if ! command -v java > /dev/null >&2; then

       echo "java is not installed, installing..."

       sudo apt install openjdk-21-jdk -y

    fi
}

jenkins_install() {
    if ! systemctl status jenkins >/dev/null 2>&1; then
        echo "Installing Jenkins..."

        # Install prerequisites
        sudo apt update
     
        # Add the 2026 Jenkins key
        curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key | sudo tee \
        /usr/share/keyrings/jenkins-keyring.asc > /dev/null

        # Add Jenkins repository with signed-by pointing to .gpg key
        echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
        https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
        /etc/apt/sources.list.d/jenkins.list > /dev/null

        # Clean apt lists and update
        sudo apt update

        # Install Jenkins
        sudo apt install jenkins -y

        echo "Jenkins installation completed successfully."
    else
        echo "Jenkins is already installed."
    fi
}



maven_install() {
    
    if ! command -v mvn > /dev/null >&2; then
       
        echo "maven is not installed, installing..."

        sudo apt update

        sudo apt install maven -y
       
    fi
}

docker_engine_install() {

        if ! command -v docker > /dev/null >&2; then

          echo "docker is not installed, installing..."

          sudo apt update

          sudo apt install -y ca-certificates curl gnupg 

          sudo install -m 0755 -d /etc/apt/keyrings
          curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
          sudo chmod a+r /etc/apt/keyrings/docker.gpg

          echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
          $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
          sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

          sudo apt update

          sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

        fi

}

kubectl_install() {

     if ! command -v kubectl > /dev/null >&2; then
         
         echo "kubectl is not installed, installing..."

         sudo apt update && sudo apt install -y apt-transport-https ca-certificates curl gnupg

         curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

         echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

         sudo apt update

         sudo apt install -y kubectl

         kubectl version --client

     fi

}

awscli_install() {

    if ! command -v aws > /dev/null >&2; then

       echo "aws is not installed. installing..." 

       # install the aws cli
       curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
       unzip awscliv2.zip
       sudo ./aws/install

        # verify installation
        aws --version
   
        # cleanup
        rm -rf ./aws/ awscliv2.zip
    fi
}

is_aws_configured() {

    if ! aws sts get-caller-identity > /dev/null >&2; then

        echo "ERROR: AWS is not configured, configure it." >&2

        exit 1

    fi

}
is_jenkins_aws_configured() {
    
    if ! sudo -u jenkins aws sts get-caller-identity > /dev/null 2>&1; then

        echo "WARNING: Jenkins AWS credentials not configured yet."

        echo "You must configure them before running Jenkins pipelines."

        sleep 10
    fi
}

eksctl_install() {

    if ! command -v eksctl > /dev/null >&2; then
    
       echo "eksctl is not installed. installing..." 

       curl --silent --location "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp

       sudo mv /tmp/eksctl /usr/local/bin

    fi

}

create_cluster() {

    local cluster_name=$1
    local region=$2
    local nodegroup_name=$3
    local nodes=$4
    local min_nodes=$5
    local max_nodes=$6
    local node_type=$7

    eksctl create cluster --name "$cluster_name" --region "$region" --nodegroup-name "$nodegroup_name" \
    --nodes "$nodes"  --nodes-min "$min_nodes" --nodes-max "$max_nodes" --node-type "$node_type" --managed

    echo "INFO: Connecting kubectl to the cluster."

    # It runs "aws eks update-kubeconfig" as the Jenkins user, so the kubeconfig is created in Jenkins’s home directory
    # and kubectl works inside Jenkins pipelines.
    sudo -u jenkins aws eks --region "$region" update-kubeconfig --name "$cluster_name"

    # for the current user
    aws eks --region "$region" update-kubeconfig --name "$cluster_name"

}

enable_services() {

    sudo systemctl enable --now docker

    sudo systemctl enable --now jenkins
    
    # It adds your current user to the docker group, so you can run Docker commands without sudo
    # i.e. we can use commands like "docker ps", without it we have to use sudo E.x. "sudo docker ps"
    sudo usermod -aG docker "$USER"

    echo "INFO: $USER has been added to the docker group."
    echo "INFO: To apply the new permissions, either log out and log back in, or run: newgrp docker"
    sleep 10

    # add jenkins user to the docker group too, so that we can write docker commands in the jenkins pipeline
    sudo usermod -aG docker jenkins
    
    sudo systemctl restart jenkins

    echo "INFO: jenkins added to the Docker group."

}


main() {

    sudo apt update && sudo apt upgrade -y

    zip_unzip_install

    openjdk_install

    jenkins_install

    maven_install

    docker_engine_install

    kubectl_install

    awscli_install

    is_aws_configured

    is_jenkins_aws_configured

    eksctl_install
    
    create_cluster "$@"

    kubectl create namespace demo || echo "Namespace demo already exists"

    enable_services

    echo "Setup complete. Jenkins can now deploy to EKS."

}

main "$@"





