#!/bin/bash

source "$(dirname "$0")/config.sh"
source "$(dirname "$0")/lib.sh"

todays_dir="${parent_dir}/$(date +%F)"
log_file="${todays_dir}/backup-progress.log"
now="$(date +%m-%d-%Y_%H-%M-%S)"

sanity_check () {
    check_backup_user

    # Check whether the encryption key file is available
    #if [ ! -r "${encryption_key_file}" ]; then
    #    error "Cannot read encryption key at ${encryption_key_file}"
    #fi
}

set_options () {
    # List the innobackupex arguments
    #declare -ga innobackupex_args=(
        #"--encrypt=AES256"
        #"--encrypt-key-file=${encryption_key_file}"
        #"--encrypt-threads=${processors}"
        #"--slave-info"
        #"--incremental"

    innobackupex_args=(
        "--defaults-file=${defaults_file}"
        "--extra-lsndir=${todays_dir}"
        "--backup"
        "--compress"
        "--stream=xbstream"
        "--parallel=${processors}"
        "--compress-threads=${processors}"
    )

    backup_type="full"

    # Add option to read LSN (log sequence number) if a full backup has been
    # taken today.
    if grep -q -s "to_lsn" "${todays_dir}/xtrabackup_checkpoints"; then
        backup_type="incremental"
        lsn=$(awk '/to_lsn/ {print $3;}' "${todays_dir}/xtrabackup_checkpoints")
        innobackupex_args+=( "--incremental-lsn=${lsn}" )
    fi
}

rotate_old () {
    # Remove the oldest backup in rotation
    day_dir_to_remove="${parent_dir}/$(date --date="${days_of_backups} days ago" +%F)"

    if [ -d "${day_dir_to_remove}" ]; then
        rm -rf "${day_dir_to_remove}" ||\
            error "Can't remove ${day_dir}"
    fi
}

prepare_backup_dir() {
    # Make sure today's backup directory is available and take the actual backup
    mkdir -p "${todays_dir}" 2>&1 || error "mkdir ${todays_dir} failed"
}

take_backup () {
    find "${todays_dir}" -type f -name "*.incomplete" -delete 2>&1 ||\
        error "find *.incomplete failed"
    #innobackupex "${innobackupex_args[@]}" "${todays_dir}" > "${todays_dir}/${backup_type}-${now}.xbstream.incomplete" 2> "${log_file}"
    mariabackup "${innobackupex_args[@]}" > "${todays_dir}/${backup_type}-${now}.xbstream.incomplete" \
        2> "${log_file}" || error "mariabackup failed"

    mv "${todays_dir}/${backup_type}-${now}.xbstream.incomplete" "${todays_dir}/${backup_type}-${now}.xbstream" 2>&1 ||\
        error "mv failed"
}

sanity_check && set_options && rotate_old && prepare_backup_dir && take_backup > "${log_file}"


# Check success and print message

#if [ "$?" = "0" ]; then
    printf "Backup successful!\n"
    printf "Backup created at %s/%s-%s.xbstream\n" "${todays_dir}" "${backup_type}" "${now}"
#else
#    error "Backup failure! Check ${log_file} for more information"
#fi

exit 0
