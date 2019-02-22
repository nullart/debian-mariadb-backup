#!/bin/bash

log_file="prepare-progress.log"
source "$(dirname "$0")/config.sh"
source "$(dirname "$0")/lib.sh"

shopt -s nullglob
incremental_dirs=( ./incremental-*/ )
full_dirs=( ./full-*/ )
shopt -u nullglob

full_backup_dir="${full_dirs[0]}"

sanity_check () {
    check_backup_user

    # Check whether a single full backup directory are available
    if (( ${#full_dirs[@]} != 1 )); then
        error "Exactly one full backup directory is required."
    fi
}

do_backup () {
    # Apply the logs to each of the backups
    echo "Initial prep of full backup ${full_backup_dir}"
    run mariabackup --prepare --target-dir="${full_backup_dir}" --prepare >&$log ||\
        error "Initial prep of full backup ${full_backup_dir} failed"

    for increment in "${incremental_dirs[@]}"; do
        echo "Applying incremental backup ${increment} to ${full_backup_dir}"
        run mariabackup --prepare --incremental-dir="${increment}" --target-dir="${full_backup_dir}" --prepare >&$log ||\
            error "Applying incremental backup ${increment} to ${full_backup_dir} failed"
    done

    echo "Applying final logs to full backup ${full_backup_dir}"
    run mariabackup --prepare --target-dir="${full_backup_dir}" >&$log ||\
        error "Applying final logs to full backup ${full_backup_dir} failed"
}

sanity_check && do_backup 2>&$log

cat << EOF
Backup looks to be fully prepared.  Please check the "prepare-progress.log" file
to verify before continuing.

If everything looks correct, you can apply the restored files.

First, stop MySQL and move or remove the contents of the MySQL data directory:

        sudo systemctl stop mysql
        sudo mv /var/lib/mysql/ /tmp/

Then, recreate the data directory and  copy the backup files:

        sudo mkdir /var/lib/mysql
        sudo mariabackup --copy-back ${PWD}/$(basename "${full_backup_dir}")

Afterward the files are copied, adjust the permissions and restart the service:

        sudo chown -R mysql:mysql /var/lib/mysql
        sudo find /var/lib/mysql -type d -exec chmod 750 {} \\;
        sudo systemctl start mysql
EOF
