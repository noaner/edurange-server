crontab -l | { cat; echo "@reboot /home/ec2-user/edurange/start.sh > /home/ec2-user/edurange/cron.log 2>&1"; } | crontab -
echo "Installed crontab entry."
