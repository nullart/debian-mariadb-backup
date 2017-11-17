#!/bin/bash

export LC_ALL=C

############ EDIT ACCORDING TO YOUR NEEDS #############
backup_owner="backup"
backup_group="mysql"
parent_dir="/backups/mysql"
defaults_file="/etc/mysql/backup.cnf"
ftpsite=""
ftpdir=""
ftpuser=""
ftppassword=""
#######################################################
todays_dir="${parent_dir}/$(date +%a)"
yesterday=$(date --date="1 days ago" +%a)
archive_date=$(date --date="1 days ago" +%Y-%m-%d)
log_file="${parent_dir}/remote-save-progress.log"
now="$(date +%Y-%m-%d)"
archive_name="mariabackup-prod-${archive_date}"

# Use this to echo to standard error
error () {
    printf "%s: %s\n" "$(basename "${BASH_SOURCE}")" "${1}" >&2
    exit 1
}

trap 'check_exit_status' EXIT

check_exit_status() {
  if [ "$?" != "0" ];then
      error "An unexpected error occurred.  Try checking the \"${log_file}\" file for more information."
  fi
}

sanity_check () {
    # Check user running the script
    if [ "$USER" != "$backup_owner" ]; then
        error "Script can only be run as the \"$backup_owner\" user"
    fi

    # Check whether  yesterday directory is here
    if [ ! -d "${parent_dir}/${yesterday}" ]; then
        error "Yesterday backup directory '${yesterday}' is not found"
    fi

    # Check ftp information are set
    if [ -z "$ftpsite" ]; then
        error "ftpsite is not set"
    fi

    if [ -z "${ftpdir}" ]; then
        error "ftpdir is not set"
    fi

    if [ -z "${ftpuser}" ]; then
        error "ftpuser is not set"
    fi

    if [ -z "${ftppassword}" ]; then
        error "ftppassword is not set"
    fi
}

archive_backup_dir() {
    # Create backup archive
    tar acfz ${archive_name}.tar.gz -C ${parent_dir} --group="${backup_group}" \
      --transform s/${yesterday}/${archive_name}/ ${parent_dir}/${yesterday} 2>&1 ||\
        error "tar command failed"
}

remote_save () {
    # Check our newly created archive is here
    test -f ${archive_name}.tar.gz || error "Can't find archive in /tmp directory"
    # Push archive to remote ftp site. NOTE THE TRAILING SLASH AFTER $ftpdir. It must be present
    # in order to succeed upload.
    curl -T ${archive_name}.tar.gz ${ftpsite}/${ftpdir}/ --user ${ftpuser}:${ftppassword} ||\
        error "FTP upload failed"
}

{ sanity_check && archive_backup_dir && remote_save; } > "${log_file}"


# Check success and print message
printf "Backup %s successfully pushed to remote ftp at %s!\n" "${archive_name}.tar.gz" "${now}"

exit 0
