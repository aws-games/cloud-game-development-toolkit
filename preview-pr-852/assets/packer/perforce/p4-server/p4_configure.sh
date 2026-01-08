#!/bin/bash

# Log file location
LOG_FILE="/var/log/p4_configure.log"

# Ensure the script runs only once
FLAG_FILE="/var/run/p4_configure_ran.flag"

if [ -f "$FLAG_FILE" ]; then
    echo "Script has already run. Exiting."
    exit 0
fi

# Function to log messages
log_message() {
    echo "$(date) - $1" >> $LOG_FILE
}

# Function to check if path is an FSx mount point
is_fsx_mount() {
    echo "$1" | grep -qE '(fs|svm)-[0-9a-f]{17}\.fsx\.[a-z0-9-]+\.amazonaws\.com:/' #to be verified if catches all fsxes
    return $?
}

is_iscsi_device() {
    echo "$1" | grep -qE '^/dev/mapper/'
    return $?
}

# Function to resolve AWS secrets
resolve_aws_secret() {
  local result=$(aws secretsmanager get-secret-value --secret-id "$1" --query "SecretString" --output text)
  echo $result
}

# wait for p4d_1 service
wait_for_service() {
  local service_name=$1
  local max_attempts=10
  local attempt=1

  while [ $attempt -le $max_attempts ]; do
    log_message "Waiting for $service_name to start... Attempt $attempt of $max_attempts."
    systemctl is-active --quiet $service_name && break
    sleep 1
    ((attempt++))
  done

  if [ $attempt -gt $max_attempts ]; then
    log_message "Service $service_name did not start within the expected time."
    return 1
  fi

  log_message "Service $service_name started successfully."
  return 0
}

# Setup P4Auth Extension
setup_helix_auth() {
  local p4port=$1
  local super=$2
  local super_password=$3
  local auth_service_url=$4
  local default_protocol=$5
  local name_identifier=$6
  local user_identifier=$7

  log_message "Starting P4Auth Extension setup."

  curl -L https://github.com/perforce/helix-authentication-extension/releases/download/2024.1/2024.1-signed.tar.gz | tar zx -C /tmp
  chmod +x "/tmp/helix-authentication-extension/bin/configure-login-hook.sh"
  sudo /tmp/helix-authentication-extension/bin/configure-login-hook.sh -n \
    --p4port "$p4port" \
    --super "$super" \
    --superpassword "$super_password" \
    --service-url "$auth_service_url" \
    --default-protocol "$default_protocol" \
    --name-identifier "$name_identifier" \
    --user-identifier "$user_identifier" \
    --non-sso-users "$super" \
    --enable-logging --debug --yes \
    >> $LOG_FILE 2>> $LOG_FILE
}

# Function to create and mount XFS on EBS
prepare_ebs_volume() {
    local ebs_volume=$1
    local mount_point=$2

    # Check if the EBS volume has a file system
    local fs_type=$(lsblk -no FSTYPE "$ebs_volume")

    if [ -z "$fs_type" ]; then
        log_message "Creating XFS file system on $ebs_volume."
        mkfs.xfs "$ebs_volume"
    fi

    log_message "Mounting $ebs_volume on $mount_point."
    mount "$ebs_volume" "$mount_point"
}

check_command() {
    if [ $? -ne 0 ]; then
        log_message "$1 failed. Exiting."
        exit 1
    fi
}

# Function to prepare iSCSI Installation
prepare_iscsi() {
    local IGROUP_NAME="perforce"
    local FLAG_FILE="/var/run/iscsi_prepared.flag"
    if [ -f "$FLAG_FILE" ]; then
        echo "iSCSI preparation has already been done. Skipping."
        return 0
    fi
    # Install necessary packages
    log_message "Installing necessary packages."
    sudo yum install -y device-mapper-multipath iscsi-initiator-utils sshpass
    check_command "Package installation"

    # Test connection to ONTAP
    log_message "Testing connection to ONTAP."

    sshpass -p $FSXN_PASSWORD ssh -o StrictHostKeyChecking=no $ONTAP_USER@$FSXN_IP "version"
    check_command "Testing connection to ONTAP"

    # Update iSCSI configuration
    log_message "Updating iSCSI configuration."
    sudo sed -i 's/node.session.timeo.replacement_timeout = .*/node.session.timeo.replacement_timeout = 5/' /etc/iscsi/iscsid.conf
    check_command "Updating iSCSI configuration"

    # Start iSCSI service
    log_message "Starting iSCSI service."
    sudo service iscsid start
    check_command "Starting iSCSI service"

    # Enable and start multipath
    log_message "Enabling and starting multipath."
    sudo mpathconf --enable --with_multipathd y
    check_command "Enabling and starting multipath"

    # Get the IQN from the initiatorname.iscsi file
    INITIATOR_IQN=$(grep -oP 'iqn.\S+' /etc/iscsi/initiatorname.iscsi)
    log_message "Retrieved initiator IQN: $INITIATOR_IQN"

    log_message "Mapping the IQN to existing igroup"
    sshpass -p $FSXN_PASSWORD ssh $ONTAP_USER@$FSXN_IP "igroup add -igroup $IGROUP_NAME -vserver $FSXN_SVM -initiator $INITIATOR_IQN"
    check_command "Mapping LUN to iGroup"

    # Retrieve the iSCSI IP address from ONTAP
    log_message "Retrieving iSCSI IP address from ONTAP."
    ISCSI_IP=$(sshpass -p $FSXN_PASSWORD ssh $ONTAP_USER@$FSXN_IP "network interface show -vserver $FSXN_SVM -fields address" | grep iscsi_1 | awk '{print $3}')
    check_command "Retrieving iSCSI IP address from ONTAP"
    log_message "Retrieved iSCSI IP address: $ISCSI_IP"

    # Discover the iSCSI target and get the target IQN
    log_message "Discovering iSCSI target."
    TARGET_IQN=$(sudo iscsiadm --mode discovery --op update --type sendtargets --portal $ISCSI_IP | grep $ISCSI_IP | awk '{print $2}')
    check_command "Discovering iSCSI target"
    log_message "Discovered target IQN: $TARGET_IQN"

    # Log in to the iSCSI target
    log_message "Logging in to the iSCSI target."
    sudo iscsiadm --mode node -T $TARGET_IQN --login
    check_command "Logging in to the iSCSI target"

    log_message "Creating flag file at $FLAG_FILE"
    sudo touch "$FLAG_FILE"

}

prepare_iscsi_volume() {
    local VOLUME_NAME=$1
    local mount_point=$2
    timeout=90
    interval=5
    elapsed=0


    # Set VOLUME based on volume path
    if [[ "$VOLUME_NAME" == *"log"* ]]; then
        VOLUME="logs"
    elif [[ "$VOLUME_NAME" == *"metadata"* ]]; then
        VOLUME="metadata"
    else
        VOLUME="depot"
    fi

    # Check if iSCSI preparation is needed
    prepare_iscsi

    log_message "configuring ISCSI for $VOLUME"

    local fs_type=$(lsblk -no FSTYPE "$VOLUME_NAME")
    if [ -z "$fs_type" ]; then
        # Retrieve the serial-hex value from the LUN
        log_message "Retrieving serial-hex value from the LUN."
        SERIAL_HEX=$(sshpass -p $FSXN_PASSWORD ssh $ONTAP_USER@$FSXN_IP "lun show -vserver $FSXN_SVM -path /vol/$VOLUME/$VOLUME -fields serial-hex" | grep /vol/$VOLUME/$VOLUME | awk '{print $3}')
        check_command "Retrieving serial-hex value from the LUN"
        log_message "Retrieved serial-hex value: $SERIAL_HEX"

        # Check if serial-hex is empty
        if [ -z "$SERIAL_HEX" ]; then
            log_message "Serial-hex value is empty. Exiting."
            exit 1
        fi

        # Rescan iSCSI sessions to detect new LUNs
        log_message "Rescanning iSCSI sessions."
        sudo iscsiadm -m session --rescan
        check_command "Rescanning iSCSI sessions"

        # Configure multipath
        log_message "Configuring multipath."
        CONF=/etc/multipath.conf
        grep -q '^multipaths {' $CONF
        UNCOMMENTED=$?
        if [ $UNCOMMENTED -eq 0 ]
        then
                sed -i '/^multipaths {/a\\tmultipath {\n\t\twwid 3600a0980'"${SERIAL_HEX}"'\n\t\talias '"${VOLUME}"'\n\t}\n' $CONF
        else
                printf "multipaths {\n\tmultipath {\n\t\twwid 3600a0980$SERIAL_HEX\n\t\talias $VOLUME\n\t}\n}" >> $CONF
        fi
        check_command "Configuring multipath"

        # Restart multipathd service
        log_message "Restarting multipathd service."
        sudo systemctl restart multipathd.service
        check_command "Restarting multipathd service"

        log_message "Checking if the new partition exists."
        while [ $elapsed -lt $timeout ]; do
        if [ -e $VOLUME ]; then
        log_message "The device $VOLUME exists."
        break
        fi
        sleep $interval
        elapsed=$((elapsed + interval))
        done
        if [ ! -e $VOLUME]; then
        log_message "The device $VOLUME does not exist. Exiting."
        exit 1
        fi
            log_message "Creating the file system on the new partition."
            sudo mkfs.ext4 $VOLUME_NAME
            check_command "Creating the file system on the new partition"
    fi

    # Mount the iSCSI disk
    log_message "Mounting the iSCSI disk."
    sudo mount $VOLUME_NAME $mount_point
    check_command "Mounting the iSCSI disk"

    log_message "iSCSI setup script completed for ${VOLUME_NAME}"

}

# Function to copy SiteTags template and update with AWS regions -> This file will be updated by Ansible with replica AWS regions.
prepare_site_tags() {
  log_message "Setting up SiteTags for installation"
  local source="/hxdepots/sdp/Server/Unix/p4/common/config/SiteTags.cfg.sample"
  local target="/hxdepots/p4/common/config/SiteTags.cfg"
  local region="$1"

  # Ensure the source file exists before attempting to copy
  if [ ! -f "$source" ]; then
    log_message "Error: Source file $source does not exist"
    return 1  # Exit the function with an error status
  fi

  # Attempt to copy the file and check if the copy operation was successful
  if ! cp "$source" "$target"; then
    log_message "Error: Failed to copy $source to $target"
    return 1  # Exit the function with an error status
  fi

  # Remove hyphens from the region string for aws_info
  local aws_info="aws${region//-/}"

  # Append the AWS info to the target file with the original region format
  # Using printf to handle the new line correctly across different shells
  printf "\n%s: AWS %s\n" "$aws_info" "$region" >> "$target"

  log_message "Added $aws_info as a site tag"
}

set_unicode() {
    log_message "Setting unicode flag for p4d."
    log_message "sourcing p4_vars"

    # Capture the command output
    output=$(su - perforce -c "source /p4/common/bin/p4_vars && /p4/common/bin/p4d -xi" 2>&1)

    # Check if the output matches exactly what we expect
    if [ "$output" = "Server switched to Unicode mode." ]; then
        log_message "Successfully switched server to Unicode mode"
        return 0
    else
        log_message "Unexpected output while setting Unicode mode: $output"
        return 1
    fi
}

set_selinux() {
    # update label for SELinux -> This is optional as by default in some operating systems like Amazon Linux SELinux is disabled - Permissive
    semanage fcontext -a -t bin_t /p4/1/bin/p4d_1_init
    restorecon -vF /p4/1/bin/p4d_1_init
}

# Starting the script
log_message "Starting the p4 configure script."

# Function to print help
print_help() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  --p4d_type <type>        Specify the type of P4 Server (p4d_master, p4d_replica, p4d_edge)"
    echo "  --username <secret_id>   AWS Secrets Manager secret ID for the P4 Server admin username"
    echo "  --password <secret_id>   AWS Secrets Manager secret ID for the P4 Server admin password"
    echo "  --auth <url>             P4Auth URL"
    echo "  --fqdn <hostname>        Fully Qualified Domain Name for the P4 Server"
    echo "  --hx_logs <path>         Path for P4 Server logs"
    echo "  --hx_metadata <path>     Path for P4 Server metadata"
    echo "  --hx_depots <path>       Path for P4 Server depots"
    echo "  --case_sensitive <0/1>   Set the case sensitivity of the P4 Server"
    echo "  --unicode <true/false>   Set the P4 Server with -xi flag for Unicode"
    echo "  --selinux <true/false>   Update labels for SELinux"
    echo "  --plaintext <true/false> Remove the SSL prefix and do not create self signed certificate"
    echo "  --fsxn_password <secret_id> AWS secret manager FSxN fsxadmin user password"
    echo "  --fsxn_svm_name <secret_id> FSxN storage virtual name"
    echo "  --fsxn_management_ip <ip_address> FSxN managment ip address"
    echo "  --help                   Display this help and exit"
}

# Parse command-line options
OPTS=$(getopt -o '' --long p4d_type:,username:,password:,auth:,fqdn:,hx_logs:,hx_metadata:,hx_depots:,case_sensitive:,unicode:,selinux:,plaintext:,fsxn_password:,fsxn_svm_name:,fsxn_management_ip:,help -n 'parse-options' -- "$@")

if [ $? != 0 ]; then
    log_message "Failed to parse options"
    exit 1
fi

eval set -- "$OPTS"



while true; do
    case "$1" in
        --p4d_type)
            P4D_TYPE=$([ "$2" = "p4d_commit" ] && echo "p4d_master" || echo "$2")
            case "$P4D_TYPE" in
                p4d_master|p4d_replica|p4d_edge)
                    shift 2
                    ;;
                *)
                    log_message "Invalid value for --p4d_type: $2"
                    print_help
                    exit 1
                    ;;
            esac
            ;;
        --username)
            P4D_ADMIN_USERNAME_SECRET_ID="$2"
            shift 2
            ;;
        --password)
            P4D_ADMIN_PASS_SECRET_ID="$2"
            shift 2
            ;;
        --auth)
            P4_AUTH_URL="$2"
            shift 2
            ;;
        --fqdn)
            FQDN="$2"
            shift 2
            ;;
        --hx_logs)
            LOGS_VOLUME="$2"
            log_message "LOGS: $LOGS_VOLUME"
            shift 2
            ;;
        --hx_metadata)
            METADATA_VOLUME="$2"
            log_message "METADATA: $METADATA_VOLUME"
            shift 2
            ;;
        --hx_depots)
            DEPOTS_VOLUME="$2"
            log_message "DEPOTS: $DEPOTS_VOLUME"
            shift 2
            ;;
        --case_sensitive)
            CASE_SENSITIVE="$2"
            log_message "CASE_SENSITIVE: $CASE_SENSITIVE"
            shift 2
            ;;
        --unicode)
            if [ "${2,,}" = "true" ] || [ "${2,,}" = "false" ]; then
                UNICODE="$2"
                log_message "UNICODE: $UNICODE"
                shift 2
            else
                log_message "Error: --unicode flag must be either 'true' or 'false'"
                exit 1
            fi
            ;;
        --selinux)
            if [ "${2,,}" = "true" ] || [ "${2,,}" = "false" ]; then
                SELINUX="$2"
                log_message "SELINUX: $SELINUX"
                shift 2
            else
                log_message "Error: --selinux flag must be either 'true' or 'false'"
                exit 1
            fi
            ;;
        --plaintext)
            if [ "${2,,}" = "true" ] || [ "${2,,}" = "false" ]; then
                PLAINTEXT="$2"
                log_message "PLAINTEXT: $PLAINTEXT"
                shift 2
            else
                log_message "Error: --plaintext flag must be either 'true' or 'false'"
                exit 1
            fi
            ;;
        --fsxn_password)
            FSXN_PASS="$2"
            shift 2
            ;;
        --fsxn_svm_name)
            FSXN_SVM="$2"
            log_message "FSXN SVM NAME: $FSXN_SVM"
            shift 2
            ;;
        --fsxn_management_ip)
            FSXN_IP="$2"
            log_message "FSXN IP: $FSXN_IP"
            shift 2
            ;;
        --help)
            print_help
            exit 0
            ;;
        --)
            shift
            break
            ;;
        *)
            log_message "Invalid option: $1"
            print_help
            exit 1
            ;;
    esac
done

# Validate P4D_TYPE
if [[ "$P4D_TYPE" != "p4d_master" && "$P4D_TYPE" != "p4d_replica" && "$P4D_TYPE" != "p4d_edge" ]]; then
    log_message "Invalid P4D_TYPE: $P4D_TYPE. Valid options are p4d_master, p4d_replica, or p4d_edge."
    exit 1
fi

# Fetch credentials for admin user from secrets manager
P4D_ADMIN_USERNAME=$(resolve_aws_secret $P4D_ADMIN_USERNAME_SECRET_ID)
P4D_ADMIN_PASS=$(resolve_aws_secret $P4D_ADMIN_PASS_SECRET_ID)
FSXN_PASSWORD=$(resolve_aws_secret $FSXN_PASS)
ONTAP_USER="fsxadmin"

# Function to perform operations
perform_operations() {
    log_message "Performing operations for mounting and syncing directories."

    # Check each mount type and mount accordingly
    mount_fs_or_ebs() {
        local mount_point=$1
        local dest_dir=$2
        local mount_options=""
        local fs_type=""
        if is_fsx_mount "$mount_point"; then
            # Mount as FSx
            log_message "nfs device detected: $mount_point"
            mount -t nfs -o nconnect=16,rsize=1048576,wsize=1048576,timeo=600 "$mount_point" "$dest_dir"
            mount_options="nfs nconnect=16,rsize=1048576,wsize=1048576,timeo=600"
            fs_type="nfs"
        elif is_iscsi_device "$mount_point"; then
            # Handle iSCSI device
            log_message "iSCSI device detected: $mount_point"
            prepare_iscsi_volume "$mount_point" "$dest_dir"
            mount_options="defaults,_netdev"
            fs_type="ext4"
        else
            # Mount as EBS the called function also creates XFS on EBS
            log_message "ebs device detected: $mount_point"
            prepare_ebs_volume "$mount_point" "$dest_dir"
            mount_options="defaults"
            fs_type="xfs"

        fi
            # Adding appending to the fstab so mounts persist across reboots.
        echo "$mount_point $dest_dir $fs_type $mount_options 0 0" >> /etc/fstab
    }

    # Create temporary directories and mount
    mkdir -p /mnt/temp_hxlogs
    mkdir -p /mnt/temp_hxmetadata
    mkdir -p /mnt/temp_hxdepots

    mount_fs_or_ebs $LOGS_VOLUME /mnt/temp_hxlogs
    mount_fs_or_ebs $METADATA_VOLUME /mnt/temp_hxmetadata
    mount_fs_or_ebs $DEPOTS_VOLUME /mnt/temp_hxdepots

    # Create temporary directories and mount
    mkdir -p /hxlogs
    mkdir -p /hxmetadata
    mkdir -p /hxdepots

    # Syncing directories
    rsync -av /hxlogs/ /mnt/temp_hxlogs/
    rsync -av /hxmetadata/ /mnt/temp_hxmetadata/
    rsync -av /hxdepots/ /mnt/temp_hxdepots/

    # Unmount temporary mounts
    umount /mnt/temp_hxlogs
    umount /mnt/temp_hxmetadata
    umount /mnt/temp_hxdepots

    # Clear destination directories
    rm -rf /hxlogs/*
    rm -rf /hxmetadata/*
    rm -rf /hxdepots/*

    # Mount EBS volumes or FSx to final destinations
    mount_fs_or_ebs $LOGS_VOLUME /hxlogs
    mount_fs_or_ebs $METADATA_VOLUME /hxmetadata
    mount_fs_or_ebs $DEPOTS_VOLUME /hxdepots

    log_message "Operation completed successfully."
}


# Maximum number of attempts (added due to terraform not mounting EBS fast enough at instance boot)
MAX_ATTEMPTS=5

# Counter for attempts
attempt=1
delay=1

# Flag to track if the condition is met
condition_met=false

while [ $attempt -le $MAX_ATTEMPTS ] && [ "$condition_met" = false ]; do
    # Check if EBS volumes or FSx mount points are provided for all required paths
    if ( [ -e "$LOGS_VOLUME" ] || is_fsx_mount "$LOGS_VOLUME" || is_iscsi_device "$LOGS_VOLUME") && \
       ( [ -e "$METADATA_VOLUME" ] || is_fsx_mount "$METADATA_VOLUME" || is_iscsi_device "$METADATA_VOLUME" ) && \
       ( [ -e "$DEPOTS_VOLUME" ] || is_fsx_mount "$DEPOTS_VOLUME" || is_iscsi_device "$DEPOTS_VOLUME"); then
        condition_met=true
        perform_operations
    else
        log_message "Attempt $attempt: One or more required paths are not valid EBS volumes or FSx mount points."
        sleep "$delay"  # Wait before the next attempt
        delay=$((delay * 2))
        ((attempt++))
    fi
done

if [ "$condition_met" = false ]; then
    log_message "All attempts failed. No operations performed. Will continue with single disk setup."
fi


log_message "$0" "$@"

log_message "Starting the configuration part after mounting was done later will configure the commit or replica depending on configuration."

SDP_Setup_Script=/hxdepots/sdp/Server/Unix/setup/mkdirs.sh
SDP_New_Server_Script=/p4/sdp/Server/setup/configure_new_server.sh
SDP_Live_Checkpoint=/p4/sdp/Server/Unix/p4/common/bin/live_checkpoint.sh
SDP_Offline_Recreate=/p4/sdp/Server/Unix/p4/common/bin/recreate_offline_db.sh
SDP_Client_Binary=/hxdepots/sdp/helix_binaries/p4
SDP=/hxdepots/sdp
TOKEN=$(curl --request PUT "http://169.254.169.254/latest/api/token" --header "X-aws-ec2-metadata-token-ttl-seconds: 3600") # This is only for the metadata V2 need to check go and try the V1 with no token and see which one works.
SDP_Setup_Script_Config=/hxdepots/sdp/Server/Unix/setup/mkdirs.cfg # Config to the new script needed for mkdirs.sh
AWS_REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region --header "X-aws-ec2-metadata-token: $TOKEN") # Get AWS region for SiteTags

if [ -z "${FQDN}" ]; then
    FQDN=$(curl -s http://169.254.169.254/latest/meta-data/hostname --header "X-aws-ec2-metadata-token: $TOKEN") # same need to check for V2 vs V1

    # Check if FQDN was successfully retrieved
    if [ -z "${FQDN}" ]; then
        log_message "Failed to retrieve EC2 instance DNS name."
        exit 1
    fi
    log_message "--fqdn not provided, using EC2 private DNS name $FQDN"
fi

cd /hxdepots/sdp/Server/Unix/setup # need to cd other



#update the mkdirs.cfg so it has proper hostname a private DNS form EC2 otherwise adding replica is not possible due to wrong P4TARGET settings.

if [ ! -f "$SDP_Setup_Script_Config" ]; then
    log_message "Error: Configuration file not found at $SDP_Setup_Script_Config."
    exit 1
fi

# Update Perforce super user password in configuration
sed -i "s/^P4ADMINPASS=.*/P4ADMINPASS=$P4D_ADMIN_PASS/" "$SDP_Setup_Script_Config"

log_message "Updated P4ADMINPASS in $SDP_Setup_Script_Config."

# Update Perforce super user password in configuration
sed -i "s/^ADMINUSER=.*/ADMINUSER=$P4D_ADMIN_USERNAME/" "$SDP_Setup_Script_Config"

log_message "Updated ADMINUSER in $SDP_Setup_Script_Config."

# Check if p4d_master server and update sitetags

# Update P4MASTERHOST value in the configuration file
sed -i "s/^P4MASTERHOST=.*/P4MASTERHOST=$FQDN/" "$SDP_Setup_Script_Config"

log_message "Updated P4MASTERHOST to $FQDN in $SDP_Setup_Script_Config."

# Update Perforce case_sensitivity in configuration
sed -i "s/^CASE_SENSITIVE=.*/CASE_SENSITIVE=$CASE_SENSITIVE/" "$SDP_Setup_Script_Config"

log_message "Updated CASE_SENSITIVE in $SDP_Setup_Script_Config."

# Update SSL prefix in configuration if plaintext is true
if [ "${PLAINTEXT,,}" = "true" ]; then
  sed -i "s/^SSL_PREFIX=.*/SSL_PREFIX=/" "$SDP_Setup_Script_Config"
  log_message "SSL_PREFIX removed from $SDP_Setup_Script_Config. Server will be configured to use plaintext."
else
  log_message "Skipping SSL_PREFIX removal from $SDP_Setup_Script_Config. Server will be configured to use SSL."
fi

log_message "Mounting done ok - continue to the install"

# Execute mkdirs.sh from the package
if [ -f "$SDP_Setup_Script" ] && [ -n $P4D_TYPE ]; then
  chmod +x "$SDP_Setup_Script"
  "$SDP_Setup_Script" 1 -t $P4D_TYPE
else
  log_message "Setup script (mkdirs.sh) not found or P4D Type: $P4D_TYPE not provided."
fi

I=1

# Create self signed certificate if plaintext is false
if [ "${PLAINTEXT,,}" = "false" ]; then
  log_message "Generating self signed certificate"
  # update cert config with ec2 DNS name
  FILE_PATH="/p4/ssl/config.txt"

  # Replace REPL_DNSNAME with the EC2 instance DNS name for ssl certificate generation
  sed -i "s/REPL_DNSNAME/$FQDN/" "$FILE_PATH"

  echo "File updated successfully."

  # generate certificate
  /p4/common/bin/p4master_run ${I} /p4/${I}/bin/p4d_${I} -Gc
else
  log_message "Skipping self signed certificate generation due to --plaintext true"
fi

# Configure systemd service to start p4d
cd /etc/systemd/system
sed -e "s:__INSTANCE__:$I:g" -e "s:__OSUSER__:perforce:g" $SDP/Server/Unix/p4/common/etc/systemd/system/p4d_N.service.t > p4d_${I}.service
chmod 644 p4d_${I}.service
systemctl daemon-reload

if [ "${SELINUX,,}" = "true" ]; then
    set_selinux
    log_message "SELinux labels updated"
elif [ "${SELINUX,,}" = "false" ]; then
    log_message "Skipping SELinux label update"
fi

# start service
systemctl start p4d_1

# Wait for the p4d service to start before continuing
wait_for_service "p4d_1"

# Set P4PORT depending on plaintext variable
if [ "${PLAINTEXT,,}" = "true" ]; then
  P4PORT=:1666
else
  P4PORT=ssl:1666
fi

P4USER=$P4D_ADMIN_USERNAME

#probably need to copy p4 binary to the /usr/bin or add to the path variable to avoid running with a full path adding:
#permissions for lal users:

chmod +x /hxdepots/sdp/helix_binaries/p4
ln -s $SDP_Client_Binary /usr/bin/p4

# now can test depending on plaintext
p4 -p $P4PORT -u $P4USER info

# Execute new server setup from the extracted package
if [ -f "$SDP_New_Server_Script" ]; then
  chmod +x "$SDP_New_Server_Script"
  "$SDP_New_Server_Script" 1
else
  echo "Setup script (configure_new_server.sh) not found."
fi

# create a live checkpoint and restore offline db
# switching to user perforce


if [ -f "$SDP_Live_Checkpoint" ]; then
  chmod +x "$SDP_Live_Checkpoint"
  sudo -u "$P4USER" "$SDP_Live_Checkpoint" 1
else
  echo "Setup script (SDP_Live_Checkpoint) not found."
fi

if [ -f "$SDP_Offline_Recreate" ]; then
  chmod +x "$SDP_Offline_Recreate"
  sudo -u "$P4USER" "$SDP_Offline_Recreate" 1
else
  echo "Setup script (SDP_Offline_Recreate) not found."
fi

# initialize crontab for user perforce
# fixing broken crontab on SDP, cron runs on minute schedule */60 is incorrect
sed -i 's#\*/60#0#g' /p4/p4.crontab.1
sudo -u "$P4USER" crontab /p4/p4.crontab.1

# verify sdp installation should warn about missing license only:
/hxdepots/p4/common/bin/verify_sdp.sh 1


# Check if the AWS_REGION variable is empty if not prepare for replication.
if [ -z "$AWS_REGION" ] && [ "$P4D_TYPE" = "p4d_master" ]; then
    log_message "Error: Not able to get the AWS Region from instance Metadata"
    exit 1
else
    prepare_site_tags "$AWS_REGION"
    log_message "Created SiteTags file appended AWS Region of this instance"
fi

# Check if the P4_AUTH_URL is empty. if not, configure P4 Auth Extension
if [ -z $P4_AUTH_URL ]; then
  log_message "P4 Auth URL was not provided. Skipping configuration."
else
  log_message "Configuring P4 Auth Extension against $P4_AUTH_URL"
  setup_helix_auth "$P4PORT" "$P4D_ADMIN_USERNAME" "$P4D_ADMIN_PASS" "$P4_AUTH_URL" "oidc" "email" "email"
fi

if [ "${UNICODE,,}" = "true" ]; then
    set_unicode
    log_message "Unicode configuration applied"
elif [ "${UNICODE,,}" = "false" ]; then
    log_message "Skipping Unicode configuration"
fi


# Create the flag file to prevent re-run
touch "$FLAG_FILE"

# Ending the script
log_message "EC2 mount script finished."
