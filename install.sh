rake db:migrate
echo "Migrated database."
crontab -l | { cat; echo "@reboot ./edurange/start.sh > ./edurange/cron.log 2>&1"; } | crontab -
echo "Installed crontab entry."
