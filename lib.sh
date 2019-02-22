trap 'check_exit_status' EXIT

exec {echo_fd}>&1

mkdir -p "$(dirname "${log_file}")"
exec {log}>"${log_file}"

echo_and_log() {
    # make sure the users sees the message and that it goes to the log
    echo "$@" >&$echo_fd
    echo "$@" >&$log
}

error () {
    echo_and_log "[ERROR] $(basename "$0"): $1"
    exit 1
}

trap 'check_exit_status' EXIT

check_exit_status() {
  if [ "$?" != "0" ];then
    error "An unexpected error occurred. Try checking the \"${log_file}\" file for more information."
  fi
}

check_backup_user() {
  # Check user running the script
  if [ "$(id -un)" != "${backup_owner}" ]; then
    error "Script can only be run as the \"${backup_owner}\" user"
  fi
}

run() {
    echo_and_log ">>>" "$@"

    "$@"

    status=$?
    if [ "$status" != "0" ]; then
        echo_and_log ">>> exit code $status"
    fi

    return $status
}
