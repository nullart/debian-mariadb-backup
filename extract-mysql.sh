#!/bin/bash

source "$(dirname "$0")/config.sh"
source "$(dirname "$0")/lib.sh"

log_file="extract-progress.log"
number_of_args="${#}"

sanity_check () {
    check_backup_user

    # Check whether the qpress binary is installed
    if ! command -v qpress >/dev/null 2>&1; then
        error "Could not find the \"qpress\" command.  Please install it and try again."
    fi

    # Check whether any arguments were passed
    if [ "${number_of_args}" -lt 1 ]; then
        error "Script requires at least one \".xbstream\" file as an argument."
    fi

    # Check whether the encryption key file is available
    #if [ ! -r "${encryption_key_file}" ]; then
    #    error "Cannot read encryption key at ${encryption_key_file}"
    #fi
}

do_extraction () {
    for file in "${@}"; do
        base_filename="$(basename "${file%.xbstream}")"
        restore_dir="./restore/${base_filename}"

        printf "\n\nExtracting file %s\n\n" "${file}"

        # Extract the directory structure from the backup file
        mkdir --verbose -p "${restore_dir}" 2>&1 ||\
            error "mkdir ${restore_dir} failed"
        mbstream -x -C "${restore_dir}" < "${file}" 2>&1 ||\
            error "mbstream failed"
            #"--decrypt=AES256"
            #"--encrypt-key-file=${encryption_key_file}"
        innobackupex_args=(
            "--parallel=${processors}"
            "--decompress"
        )

        #innobackupex "${innobackupex_args[@]}" "${restore_dir}"
        mariabackup "${innobackupex_args[@]}" --target-dir="${restore_dir}" 2>&1 ||\
            error "mariabackup failed"
        #find "${restore_dir}" -name "*.xbcrypt" -exec rm {} \;
        find "${restore_dir}" -name "*.qp" -exec rm {} \; 2>&1 ||\
            error "find *.qp in ${restore_dir} failed"

        printf "\n\nFinished work on %s\n\n" "${file}"

    done > "${log_file}" 2>&1
}

sanity_check && do_extraction "$@" > "${log_file}"

printf "Extraction complete! Backup directories have been extracted to the \"restore\" directory.\n"

exit 0
