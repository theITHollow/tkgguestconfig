FROM photon:3.0

USER root

RUN tdnf update -y && tdnf install -y jq openssh-clients expect && \
    curl -LO "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl" && \
    chmod +x ./kubectl && \
    mv ./kubectl /usr/local/bin/kubectl

COPY . .

RUN mv ./kubectl-vsphere /usr/local/bin/kubectl-vsphere

ENTRYPOINT [ "./newlogin.sh" ]