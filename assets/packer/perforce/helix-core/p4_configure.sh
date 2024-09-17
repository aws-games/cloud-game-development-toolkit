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
    echo "$1" | grep -qE 'fs-[0-9a-f]{17}\.fsx\.[a-z0-9-]+\.amazonaws\.com:/' #to be verified if catches all fsxes
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

# Setup Helix Authentication Extension
setup_helix_auth() {
  local p4port=$1
  local super=$2
  local super_password=$3
  local service_url=$4
  local default_protocol=$5
  local name_identifier=$6
  local user_identifier=$7

  log_message "Starting Helix Authentication Extension setup."

  curl -L https://github.com/perforce/helix-authentication-extension/releases/download/2024.1/2024.1-signed.tar.gz | tar zx -C /tmp
  chmod +x "/tmp/helix-authentication-extension/bin/configure-login-hook.sh"
  sudo /tmp/helix-authentication-extension/bin/configure-login-hook.sh -n \
    --p4port "$p4port" \
    --super "$super" \
    --superpassword "$super_password" \
    --service-url "$service_url" \
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

# Starting the script
log_message "Starting the p4 configure script."

# Function to print help
print_help() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  --p4d_type <type>        Specify the type of Helix Core server (p4d_master, p4d_replica, p4d_edge)"
    echo "  --username <secret_id>   AWS Secrets Manager secret ID for the Helix Core admin username"
    echo "  --password <secret_id>   AWS Secrets Manager secret ID for the Helix Core admin password"
    echo "  --auth <url>             Helix Authentication Service URL"
    echo "  --fqdn <hostname>        Fully Qualified Domain Name for the Helix Core server"
    echo "  --hx_logs <path>         Path for Helix Core logs"
    echo "  --hx_metadata <path>     Path for Helix Core metadata"
    echo "  --hx_depots <path>       Path for Helix Core depots"
    echo "  --help                   Display this help and exit"
}

# Parse command-line options
OPTS=$(getopt -o '' --long p4d_type:,username:,password:,auth:,fqdn:,hx_logs:,hx_metadata:,hx_depots:,help -n 'parse-options' -- "$@")

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
            HELIX_AUTH_SERVICE_URL="$2"
            shift 2
            ;;
        --fqdn)
            FQDN="$2"
            shift 2
            ;;
        --hx_logs)
            EBS_LOGS="$2"
            log_message "EBS_LOGS: $EBS_LOGS"
            shift 2
            ;;
        --hx_metadata)
            EBS_METADATA="$2"
            log_message "EBS_METADATA: $EBS_METADATA"
            shift 2
            ;;
        --hx_depots)
            EBS_DEPOTS="$2"
            log_message "EBS_DEPOTS: $EBS_DEPOTS"
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
            mount -t nfs -o nconnect=16,rsize=1048576,wsize=1048576,timeo=600 "$mount_point" "$dest_dir"
            mount_options="nfs nconnect=16,rsize=1048576,wsize=1048576,timeo=600"
            fs_type="nfs"
        else
            # Mount as EBS the called function also creates XFS on EBS
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

    mount_fs_or_ebs $EBS_LOGS /mnt/temp_hxlogs
    mount_fs_or_ebs $EBS_METADATA /mnt/temp_hxmetadata
    mount_fs_or_ebs $EBS_DEPOTS /mnt/temp_hxdepots

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
    mount_fs_or_ebs $EBS_LOGS /hxlogs
    mount_fs_or_ebs $EBS_METADATA /hxmetadata
    mount_fs_or_ebs $EBS_DEPOTS /hxdepots

    log_message "Operation completed successfully."
}


# Maximum number of attempts (added due to terraform not mounting EBS fast enough at instance boot)
MAX_ATTEMPTS=3

# Counter for attempts
attempt=1

# Flag to track if the condition is met
condition_met=false

while [ $attempt -le $MAX_ATTEMPTS ] && [ "$condition_met" = false ]; do
    # Check if EBS volumes or FSx mount points are provided for all required paths
    if ( [ -e "$EBS_LOGS" ] || is_fsx_mount "$EBS_LOGS" ) && \
       ( [ -e "$EBS_METADATA" ] || is_fsx_mount "$EBS_METADATA" ) && \
       ( [ -e "$EBS_DEPOTS" ] || is_fsx_mount "$EBS_DEPOTS" ); then
        condition_met=true
        perform_operations
    else
        log_message "Attempt $attempt: One or more required paths are not valid EBS volumes or FSx mount points."
        sleep 5  # Wait for 1 second before the next attempt
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
EC2_DNS_PRIVATE=$(curl -s http://169.254.169.254/latest/meta-data/hostname --header "X-aws-ec2-metadata-token: $TOKEN") # same need to check for V2 vs V1
SDP_Setup_Script_Config=/hxdepots/sdp/Server/Unix/setup/mkdirs.cfg # Config to the new script needed for mkdirs.sh
AWS_REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region --header "X-aws-ec2-metadata-token: $TOKEN") # Get AWS region for SiteTags

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
sed -i "s/^P4MASTERHOST=.*/P4MASTERHOST=$EC2_DNS_PRIVATE/" "$SDP_Setup_Script_Config"

log_message "Updated P4MASTERHOST to $EC2_DNS_PRIVATE in $SDP_Setup_Script_Config."


log_message "Mounting done ok - continue to the install"

# Execute mkdirs.sh from the package
if [ -f "$SDP_Setup_Script" ] && [ -n $P4D_TYPE ]; then
  chmod +x "$SDP_Setup_Script"
  "$SDP_Setup_Script" 1 -t $P4D_TYPE
else
  log_message "Setup script (mkdirs.sh) not found or P4D Type: $P4D_TYPE not provided."
fi

# update cert config with ec2 DNS name
FILE_PATH="/p4/ssl/config.txt"

# Retrieve the EC2 instance DNS name
if [ -z $FQDN ]; then
  log_message "FQDN was not provided. Retrieving from EC2 metadata."
  EC2_DNS_NAME=$(curl -s http://169.254.169.254/latest/meta-data/public-hostname --header "X-aws-ec2-metadata-token: $TOKEN")
else
  log_message "FQDN was provided: $FQDN"
  EC2_DNS_NAME=$FQDN
fi

# Check if the DNS name was successfully retrieved
if [ -z "$EC2_DNS_NAME" ]; then
  echo "Failed to retrieve EC2 instance DNS name."
  exit 1
fi

# Replace REPL_DNSNAME with the EC2 instance DNS name for ssl certificate generation
sed -i "s/REPL_DNSNAME/$EC2_DNS_NAME/" "$FILE_PATH"

echo "File updated successfully."

I=1
# generate certificate

/p4/common/bin/p4master_run ${I} /p4/${I}/bin/p4d_${I} -Gc

# Configure systemd service to start p4d


cd /etc/systemd/system
sed -e "s:__INSTANCE__:$I:g" -e "s:__OSUSER__:perforce:g" $SDP/Server/Unix/p4/common/etc/systemd/system/p4d_N.service.t > p4d_${I}.service
chmod 644 p4d_${I}.service
systemctl daemon-reload


# update label for selinux
semanage fcontext -a -t bin_t /p4/1/bin/p4d_1_init
restorecon -vF /p4/1/bin/p4d_1_init

# start service
systemctl start p4d_1

# Wait for the p4d service to start before continuing
wait_for_service "p4d_1"

P4PORT=ssl:1666
P4USER=$P4D_ADMIN_USERNAME

#probably need to copy p4 binary to the /usr/bin or add to the path variable to avoid running with a full path adding:
#permissions for lal users:


chmod +x /hxdepots/sdp/helix_binaries/p4
ln -s $SDP_Client_Binary /usr/bin/p4

# now can test:
p4 -p ssl:$HOSTNAME:1666 trust -y


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

# Check if the HELIX_AUTH_SERVICE_URL is empty. if not, configure Helix Authentication Extension
if [-z $HELIX_AUTH_SERVICE_URL ]; then
  log_message "Helix Authentication Service URL was not provided. Skipping configuration."
else
  log_message "Configuring Helix Authentication Extension against $HELIX_AUTH_SERVICE_URL"
  setup_helix_auth "$P4PORT" "$P4D_ADMIN_USERNAME" "$P4D_ADMIN_PASS" "$HELIX_AUTH_SERVICE_URL" "oidc" "email" "email"
fi

# Create the flag file to prevent re-run
touch "$FLAG_FILE"

# Ending the script
log_message "EC2 mount script finished."