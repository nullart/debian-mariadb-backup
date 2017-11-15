#!/bin/bash

export LC_ALL=C

############ EDIT ACCORDING TO YOUR NEEDS #############
backup_owner="backup"
parent_dir="/backups/mysql"
defaults_file="/etc/mysql/backup.cnf"
ftppassfile="/root/.ftppass"
#######################################################
todays_dir="${parent_dir}/$(date +%a)"
yesterday=$(date --date="1 days ago" +%Y-%m-%d)
log_file="${todays_dir}/remote-save-progress.log"
#encryption_key_file="${parent_dir}/encryption_key"
now="$(date +%Y-%m-%d)"
archive_name="mariabackup-prod-${yesterday}"

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
    if [[ !-d "${parent_dir}/${yesterday}" ]]; then
        error "Yesterday backup directory '${yesterday}' is not found"
    fi

    # Check we have a ftp password file (a la postgresql .pgpass)
    if [[ !-f "$ftppassfile" ]]; then
        error "Can't find ftppassfile!"
    fi
}

archive_backup_dir() {
    # cd /tmp 2>&1 || error "Can't go to ${parent_dir}"
    # Create backup archive
    tar acfz ${archive_name}.tar.gz -C ${parent_dir} --transform s/${yesterday}/${archive_name}/ ${parent_dir}/${yesterday} 2>&1 ||\
        error "tar command failed"
}

remote_save () {
    # Check our newly created archive is here
    test -f ${archive_name}.tar.gz || error "Can't find archive in /tmp directory"
    # Read and get info .ftppass file

    ftpsite=$( cat ${ftppassfile} | cut -f1 -d: )
    ftpdir=$( cat ${ftppassfile} | cut -f2 -d: )
    ftpuser=$( cat ${ftppassfile} | cut -f3 -d: )
    ftppassword=$( cat ${ftppassfile} | cut -f4 -d: )

    # Push archive to remote ftp site
    curl -T ${archive_name}.tar.gz ${ftpsite}/${ftpdir} --user ${ftpuser}:${ftppassword} ||\
        error "FTP upload failed"
}

sanity_check && archive_backup_dir && remote_save > "${log_file}"


# Check success and print message

#if [ "$?" = "0" ]; then
    printf "Backup successful!\n"
    printf "Backup created at %s/%s-%s.xbstream\n" "${todays_dir}" "${backup_type}" "${now}"
#else
#    error "Backup failure! Check ${log_file} for more information"
#fi

exit 0
