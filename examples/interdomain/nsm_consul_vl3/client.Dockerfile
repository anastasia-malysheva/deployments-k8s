FROM ubuntu:latest
RUN apt update
RUN apt upgrade -y
RUN apt-get install curl gnupg sudo lsb-release net-tools iproute2 apt-utils -y
RUN curl --fail --silent --show-error --location https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo dd of=/usr/share/keyrings/hashicorp-archive-keyring.gpg
RUN echo "deb [arch=amd64 signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee -a /etc/apt/sources.list.d/hashicorp.list
RUN sudo apt-get update
RUN sudo apt-get install consul=1.12.0-1
RUN sudo apt-get -y install systemctl
RUN sudo apt-get install openssh-client
RUN curl -L https://func-e.io/install.sh | bash -s -- -b /usr/local/bin
RUN export FUNC_E_PLATFORM=linux/amd64
RUN func-e use 1.22.2
RUN sudo cp ~/.func-e/versions/1.22.2/bin/envoy /usr/bin/
