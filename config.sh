export LC_ALL=C

days_of_backups=3  # Must be less than 7
backup_owner="backup"
#encryption_key_file="/backups/mysql/encryption_key"
parent_dir="/backups/mysql"
defaults_file="/etc/mysql/backup.cnf"
processors="$(nproc --all)"


