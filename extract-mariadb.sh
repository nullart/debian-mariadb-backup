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
        mbstream_output="$(mktemp)"
        run mkdir --verbose -p "${restore_dir}" ||\
            error "mkdir ${restore_dir} failed"
        run mbstream -v -x -C "${restore_dir}" < "${file}" | tee "$mbstream_output" >> ${log_file} ||\
            error "mbstream failed"
            #"--decrypt=AES256"
            #"--encrypt-key-file=${encryption_key_file}"

        # workaround: mbstream doesn't always exit non-zero on errors
        if grep -iE 'error|fail' "$mbstream_output"; then
            error "mbstream failed"
        fi

        # work around a bug: mbstream creates an extra copy of xtrabackup_info
        # in the original backup dir
        #   https://jira.mariadb.org/browse/MDEV-18438

        extra_info_file="$(grep /xtrabackup_info "$mbstream_output" | grep -v decompressing | sed -r 's/\[[^]]+\] ....-..-.. ..:..:.. //')"
        if [ -n "$extra_info_file" ]; then
            run rm -f "$extra_info_file" || error "failed to remove extra xtrabackup_info file"
        fi

        rm -f "$mbstream_output"

        mariabackup_args=(
            "--parallel=${processors}"
            "--decompress"
        )

        run mariabackup "${mariabackup_args[@]}" --target-dir="${restore_dir}" >> ${log_file} ||\
            error "mariabackup failed"
        run find "${restore_dir}" -name "*.qp" -exec rm {} \; ||\
            error "find *.qp in ${restore_dir} failed"

        printf "\n\nFinished work on %s\n\n" "${file}"

    done
}

sanity_check && do_extraction "$@"

printf "Extraction complete! Backup directories have been extracted to the \"restore\" directory.\n"

exit 0
