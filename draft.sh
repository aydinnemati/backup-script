#!/bin/bash

#################
#### Servers ####
#################

servers=("server1" "server2" "server3")


##############
#### Vars ####
##############

SERVER_SPECIFICATION="THIS IS DRAFT SCRIPT FOR BACKING UP YOUR DATA"
AP_TELEGRAM_BOT_URL01="https://api.telegram.org/bot_SOME_ID/sendMessage"
AP_TELEGRAM_BOT_CHAT_ID="SOME CHAT ID"
AP_PROXY_URL="http://X.X.X.X:YYYY" # proxy URL
LOGFILE_PATH="./log"
SSH_USER="XXX"
REMOTE_BACKUP_PATH="/path/to/remote/directory" # backup path on remote server
LOCAL_STORAGE_PATH="/path/to/local/storage" # path to store backups

error_occurred=false
retry_count=0
max_retries=3

################
#### Logger ####
################

log() {
    echo "$(date): $1"
    echo "$(date): $1" >> ${LOGFILE_PATH}
}


########################################
#### Test SSH Connection To Servers ####
########################################

for server in "${servers[@]}"; do
    log "Attempting SSH connection to $server..."
    if ssh -o ConnectTimeout=5 "$SSH_USER@$server" "exit" >/dev/null 2>&1; then
        log "SSH connection to $server successful"
        accessible_server="$server"
        break
    else
        log "SSH connection to $server failed"
    fi
done

if [ -z "$accessible_server" ]; then
    log "No server with SSH access found. Exiting..."
    error_occurred=true
fi


#####################
#### Get Backups ####
#####################

while [ $retry_count -lt $max_retries ]; do

    file_list=$(ssh "$SSH_USER@$accessible_server" "find $REMOTE_BACKUP_PATH -type f -mtime -2")

    iteration_error_occurred=false

    for file in $file_list; do
        log "Copying $file to $LOCAL_STORAGE_PATH"
        rsync -avzP -e "ssh" "$SSH_USER@$accessible_server:$file" "$LOCAL_STORAGE_PATH"
        if [ $? -ne 0 ]; then
            iteration_error_occurred=true
            log "Error encountered while copying $file"
            error_occurred=true
            retry_count=$((retry_count + 1))
        else
            error_occurred=false
            retry_count=$((retry_count + 4))
            log "Files successfully copied! $file"
        fi
    done
    if [ "$iteration_error_occurred" = false ]; then
        break
    fi
done

if [ "$error_occurred" = true ]; then
    log "Backup process encountered an error"
    message="Backup process encountered an error\ncheck logs for more details\n$SERVER_SPECIFICATION\nAccessible server: $accessible_server❌"
else
    log "Rsync completed successfully"
    message="Backup process completed successfully\n$SERVER_SPECIFICATION\nAccessible server: $accessible_server ✅"
fi
log "Script execution completed"


#########################
#### Notify Telegram ####
#########################
retry_count_notif=0

while [ $retry_count_notif -lt $max_retries ]; do

    payload="{\"chat_id\": \"$AP_TELEGRAM_BOT_CHAT_ID\", \"text\": \"$message\", \"disable_notification\": false}"

    curl_command="curl -X POST -H \"Content-Type: application/json\" -d '$payload' --proxy $AP_PROXY_URL $AP_TELEGRAM_BOT_URL01"

    eval $curl_command
    if [ $? -eq 0 ]; then
        retry_count_notif=$((retry_count_notif + 4))
    else
        retry_count_notif=$((retry_count_notif + 1))
    fi
done