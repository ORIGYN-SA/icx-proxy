#!/bin/bash
# Install docker
sudo apt-get update -y
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository -y \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"
sudo apt-get update -y
sudo apt-get install -y docker-ce
sudo usermod -aG docker ubuntu

sudo mkdir -p /mnt/locust

sudo cat << EOF > /tmp/locustfile.py
${tests_file}
EOF

sudo mv /tmp/locustfile.py /mnt/locust/locustfile.py

sudo docker run -d --restart always -p 5557:5557 -v /mnt/locust:/mnt/locust locustio/locust -f /mnt/locust/locustfile.py --worker --master-host="${master_host}" --host=${target_host}
