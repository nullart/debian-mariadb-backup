#!/bin/bash

source "$(dirname "$0")/config.sh"
todays_dir="${parent_dir}/$(date +%F)"
log_file="${todays_dir}/backup-progress.log"
now="$(date +%m-%d-%Y_%H-%M-%S)"

source "$(dirname "$0")/lib.sh"

sanity_check () {
    check_backup_user

    # Check whether the encryption key file is available
    #if [ ! -r "${encryption_key_file}" ]; then
    #    error "Cannot read encryption key at ${encryption_key_file}"
    #fi
}

set_options () {
    # List the mariabackup arguments
    mariabackup_args=(
        "--defaults-file=${defaults_file}"
        "--extra-lsndir=${todays_dir}"
        "--backup"
        "--compress"
        "--stream=xbstream"
        "--parallel=${processors}"
        "--compress-threads=${processors}"
    )
    mariabackup_args+=($extra_backup_args)

    backup_type="full"

    # Add option to read LSN (log sequence number) if a full backup has been
    # taken today.
    if grep -q -s "to_lsn" "${todays_dir}/xtrabackup_checkpoints"; then
        backup_type="incremental"
        lsn=$(awk '/to_lsn/ {print $3;}' "${todays_dir}/xtrabackup_checkpoints")
        mariabackup_args+=( "--incremental-lsn=${lsn}" )
    fi
}

rotate_old () {
    # Remove the oldest backup in rotation
    day_dir_to_remove="${parent_dir}/$(date --date="${days_of_backups} days ago" +%F)"

    if [ -d "${day_dir_to_remove}" ]; then
        echo "Removing old backup directory ${day_dir_to_remove}"
        run rm -rf "${day_dir_to_remove}" ||\
            error "Can't remove ${day_dir}"
    fi
}

prepare_backup_dir() {
    # Make sure today's backup directory is available and take the actual backup
    run mkdir --verbose -p "${todays_dir}" >&$log || error "mkdir ${todays_dir} failed"
}

take_backup () {
    run find "${todays_dir}" -type f -name "*.incomplete" -delete ||\
        error "deleting *.incomplete failed"

    run mariabackup "${mariabackup_args[@]}" > "${todays_dir}/${backup_type}-${now}.xbstream.incomplete" \
        || error "mariabackup failed"

    run mv "${todays_dir}/${backup_type}-${now}.xbstream.incomplete" "${todays_dir}/${backup_type}-${now}.xbstream" \
        || error "mv failed"
}

sanity_check && set_options && rotate_old && prepare_backup_dir && take_backup 2>&$log

printf "Backup successful!\n"
printf "Backup created at %s/%s-%s.xbstream\n" "${todays_dir}" "${backup_type}" "${now}"

exit 0
