pipeline {
    agent {
        node {
            label 'linux'
        }
    }
    parameters {
        string(name: 'FSX_VOLUME_ID', defaultValue: '', description: 'FSx volume ID of the volume to delete the oldest snapshot from')
    }
    stages {
        stage('Validate Pipeline') {
            steps {
                script {
                    if (env.FSX_VOLUME_ID == null || env.FSX_VOLUME_ID.length() <= 0) {
                        throw new Exception("FSX_VOLUME_ID parameter/environment variable not set.")
                    }
                }
            }
        }
        stage('Delete') {
            steps {
                    script {
                        env.source_path = sh(returnStdout: true, script:'''
                        # Get the latest available snapshot that was created more than 7 days ago
                        SNAPSHOTID=\$(aws fsx describe-snapshots --filters "Name=volume-id,Values=$FSX_VOLUME_ID" --query "sort_by(Snapshots,&CreationTime)[?CreationTime<='$(date +%Y-%m-%dT23:59:59.999999+23:59 -d "7 days ago")' && Lifecycle == 'AVAILABLE']" --output json | jq -r '.[0].SnapshotId')

                        # Delete the snapshot, if found
                        if [ "$SNAPSHOTID" != "null" ]; then
                            aws fsx delete-snapshot --snapshot-id $SNAPSHOTID

                            # Wait until the snapshot is deleted
                            i=0
                            while [ $i -ne 20 ]; do
                                i=$(($i+1))
                                STATUS=$(aws fsx describe-snapshots --snapshot-ids $SNAPSHOTID --output text --query 'Snapshots[0].Lifecycle' || true)
                                # if the status is no longer 'AVAILABLE' or 'DELETING', break out:
                                if [ "$STATUS" = "AVAILABLE" ] || [ "$STATUS" = "DELETING" ]; then
                                    sleep 2
                                else
                                    echo "done deleting snapshot"
                                    break;
                                fi
                            done;
                        else
                            echo "failed to delete snapshot in time"
                        fi
                        ''').trim()
                    }
            }
        }
    }
}
