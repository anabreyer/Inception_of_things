FROM debian:12

RUN apt-get update && apt-get install -y \
    curl git ca-certificates gnupg lsb-release \
  && rm -rf /var/lib/apt/lists/*

RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
 && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl \
 && rm kubectl

RUN curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

WORKDIR /workspace
CMD ["tail", "-f", "/dev/null"]
