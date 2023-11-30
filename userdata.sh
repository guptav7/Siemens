#! /bin/bash
sudo apt-get update
sudo apt-get install -y apache2
sudo systemctl start apache2
sudo systemctl enable apache2
echo "The page was created by the user data" | sudo tee /var/www/html/index.html
cd /home/ubuntu
sudo apt-get update
sudo apt-get install python3-pip -y
sudo pip3 install ansible
sleep 30
sudo ansible-playbook apache.yml
