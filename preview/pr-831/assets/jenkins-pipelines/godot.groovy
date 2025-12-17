def build_linux() {
    sh '''
    # Create an overlay filesystem that allows us to build from a read-only filesystem (ZFS snapshot)
    # source_path variable contains the RELATIVE path to our source code
    TMPDIR=\$(mktemp -d)
    mkdir -p $TMPDIR/upperdir
    mkdir -p $TMPDIR/workdir
    mkdir -p /tmp/overlay_mount
    MOUNTDIR=/tmp/overlay_mount
    USER=\$(whoami)
    chown -R $USER:$USER $TMPDIR
    sudo mount -t overlay overlay -o lowerdir=/mnt/fsx_workspace/$source_path,upperdir=$TMPDIR/upperdir,workdir=$TMPDIR/workdir $MOUNTDIR
    echo $MOUNTDIR
    SRCDIR=$MOUNTDIR

    cd $SRCDIR

    # build godot!
    time scons LINK="echo" CC="sccache clang" CXX="sccache clang++" platform=linuxbsd target=template_release production=yes use_llvm=yes linker=lld -j 8

    # record metrics
    echo "sccache stats for this run (NOTE: may not be correct if there's parallel builds on this node!):"
    sccache --show-stats
    SCCACHE_JSON_STATS=\$(sccache --show-stats --stats-format json)
    echo $SCCACHE_JSON_STATS | jq -r '.stats | [paths(scalars) as $path | { ($path|join("-")): getpath($path) }] | add | [.] | (.[0] | keys_unsorted) as $keys | ([$keys] + map([.[ $keys[] ]])) [] | @csv' > $WORKSPACE/sccache_stats.csv
    METRIC_DATA=\$(echo $SCCACHE_JSON_STATS | jq -c '.stats | [paths(scalars) as $path | { ($path|join("-")): getpath($path) }] | add | to_entries | map({"MetricName":.key, "Value": .value, "Timestamp": now | todate, "Unit": "Count"})')
    echo $METRIC_DATA | aws cloudwatch put-metric-data --namespace $JOB_NAME --metric-data file:///dev/stdin   1>&2  || :
    '''
}

pipeline {
    agent none

    parameters {
        string(name: 'source_path', defaultValue: '', description: 'Source path to build from, e.g. snapshot location in the mounted FSx workspace volume + project path. If not set, project will be fetched/pulled and a new snapshot will be created. Do not provide this value unless you want to build from an already-created FSx snapshot.')
        booleanParam(name: 'enable_sccache', defaultValue: true, description: 'Whether to enable sccache or not')
    }

    environment {
        PROJECT_GIT_URL = "https://github.com/godotengine/godot.git"
        PROJECT_PROJECT_FOLDER = "godot" // folder name of the checked out Git repository
    }

    stages {
        stage('Validate Pipeline') {
            steps {
                script {
                    if (env.FSX_WORKSPACE_VOLUME_ID == null || env.FSX_WORKSPACE_VOLUME_ID.length() <= 0) {
                        throw new Exception("FSX_WORKSPACE_VOLUME_ID environment variable not set. Please set it globally in Jenkins as a global environment variable, or set it as a pipeline-specific environment variable")
                    }
                }
            }
        }
        stage('Prepare') {
            when {
                expression {
                    return env.source_path == ''
                }
            }
            agent {
                label 'linux && ubuntu-jammy-22.04'
            }
            steps {
                script {
                    // Set the 'source_path' environment varable, based on the output of a script
                    // The script clones/pulls the git repo, creates a new snapshot in FSx for OpenZFS, and them echoes its RELATIVE file path on the 'workspace' FSxZ volume
                    // Any output of any command in the below section will break things, so ensure that all output happens on stderr or not at all!
                    env.source_path = sh(returnStdout: true, script:'''
                    # Clone/pull the git repo to a locally mounted, writable FSx for OpenZFS volume.
                    mkdir -p /mnt/fsx_workspace
                    cd /mnt/fsx_workspace
                    [ -d "$PROJECT_PROJECT_FOLDER" ] && (cd $PROJECT_PROJECT_FOLDER; time git pull --recurse-submodules 1>&2) || (time git clone --recurse-submodules $PROJECT_GIT_URL $PROJECT_PROJECT_FOLDER 1>&2; cd $PROJECT_PROJECT_FOLDER)

                    # Create an FSx for OpenZFS snapshot
                    SNAPSHOTNAME=\$(date --utc +%Y-%m-%d_%H_%M_%S)
                    SNAPSHOTID=\$(aws fsx create-snapshot --name $SNAPSHOTNAME --volume-id $FSX_WORKSPACE_VOLUME_ID --query 'Snapshot.SnapshotId' --output text)
                    # wait until the snapshot is created:
                    i=0
                    while [ $i -ne 30 ]; do
                        i=$(($i+1))
                        STATUS=$(aws fsx describe-snapshots --snapshot-ids $SNAPSHOTID --output text --query 'Snapshots[0].Lifecycle')
                        # if the status is 'AVAILABLE', break out:
                        if [ "$STATUS" = "AVAILABLE" ]; then
                            echo .zfs/snapshot/$SNAPSHOTNAME/$PROJECT_PROJECT_FOLDER
                            break;
                        else
                            sleep 2
                        fi
                    done;
                    ''').trim()
                    println env.source_path
                }
            }
        }

        stage('Build') {
            parallel {
                stage('Linux x86_64') {
                    agent { label 'linux && ubuntu-jammy-22.04 && x86_64' }
                    options {
                        timeout(time: 60, unit: 'MINUTES')
                    }
                    steps {
                        script {
                            try {
                                build_linux()
                            } finally {
                                sh '''
                                sudo umount /tmp/overlay_mount
                                '''
                            }
                        }
                    }
                }
                stage('Linux aarch64') {
                    agent { label 'linux && ubuntu-jammy-22.04 && aarch64' }
                    options {
                        timeout(time: 60, unit: 'MINUTES')
                    }
                    steps {
                        script {
                            try {
                                build_linux()
                            } finally {
                                sh '''
                                sudo umount /tmp/overlay_mount
                                '''
                            }
                        }
                    }
                }
            }
        }

    }
}
