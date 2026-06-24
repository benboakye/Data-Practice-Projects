sudo sed -i 's/-G 60/-G 20/g' /usr/local/bin/nid-auto-capture-start.sh
sudo systemctl restart nid-auto-capture
sudo systemctl status nid-auto-capture --no-pager
