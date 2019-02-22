trap 'check_exit_status' EXIT

# Use this to echo to standard error
error () {
    printf "[ERROR] %s: %s\n" "$(basename "${BASH_SOURCE}")" "${1}" >&2
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
    echo ">>> " "$@"

    "$@"

    status=$?
    if [ "$status" != "0" ]; then
        echo ">>> exit code $status"
    fi

    exit $status
}
