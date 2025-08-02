def build(build_for_unreal) {
    env.build_for_unreal=build_for_unreal.toBoolean() ? "1" : "0"
    sh '''
    echo "Zeroing sccache stats..."
    sccache --zero-stats
    echo cwd: $(pwd)
    time cmake -DBUILD_FOR_UNREAL=$build_for_unreal -DRUN_CLANG_FORMAT=0 -S /mnt/fsx_workspace/$source_path
    time make
    echo "sccache stats for this run (NOTE: may not be correct if there's parallel builds on this node!):"
    sccache --show-stats
    '''
}

pipeline {
    agent none
    parameters {
        string(name: 'source_path', defaultValue: '', description: 'Source path to build from, e.g. snapshot location in the mounted FSx workspace volume + project path. If not set, project will be fetched/pulled and a new snapshot will be created. Do not provide this value unless you want to build from an already-created FSx snapshot.')
        booleanParam(name: 'enable_sccache', defaultValue: true, description: 'Whether to enable sccache or not')
    }
    environment {
        CMAKE_C_COMPILER_LAUNCHER = "${env.enable_sccache.toBoolean() ? "/usr/bin/sccache" : ""}"
        CMAKE_CXX_COMPILER_LAUNCHER = "${env.enable_sccache.toBoolean() ? "/usr/bin/sccache" : ""}"
        CMAKE_CC_COMPILER_LAUNCHER = "${env.enable_sccache.toBoolean() ? "/usr/bin/sccache" : ""}"
        GAMELIFT_ZIP_URL = "https://gamelift-release.s3.us-west-2.amazonaws.com/GameLift-SDK-Release-06_15_2023.zip"
        GAMELIFT_SDK_RELEASE = "GameLift-SDK-Release-06_15_2023" // Name of the GameLift SDK folder found within the zip file
        GAMELIFT_CPP_SDK_VERSION = "GameLift-Cpp-ServerSDK-5.0.4" // Name of the GameLift C++ Server SDK found within the GameLift SDK folder in the zip file
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
                    // The script pulls the source code, creates a new snapshot in FSx for OpenZFS, and them echoes its RELATIVE file path on the 'workspace' FSxZ volume
                    // Any output of any command in the below section will break things, so ensure that all output happens on stderr or not at all!
                    env.source_path = sh(returnStdout: true, script:'''
                    # Download the SDK to a locally mounted, writable FSx for OpenZFS volume.
                    mkdir -p /mnt/fsx_workspace/gamelift_sdk
                    cd /mnt/fsx_workspace/gamelift_sdk

                    [ -d "$GAMELIFT_SDK_RELEASE" ] && (echo "nothing to do" 1>&2) || (curl -s "$GAMELIFT_ZIP_URL" | bsdtar -xf- 1>&2)

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
                            echo .zfs/snapshot/$SNAPSHOTNAME/gamelift_sdk/$GAMELIFT_SDK_RELEASE/$GAMELIFT_CPP_SDK_VERSION
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

                // for unreal:

                stage('Ubuntu Linux x86_64 - for unreal') {
                    agent { label 'linux && ubuntu-jammy-22.04 && x86_64' }
                    options {
                        timeout(time: 60, unit: 'MINUTES')
                    }
                    steps {
                        cleanWs()
                        script {
                            build(true)
                        }
                    }
                }

                stage('Ubuntu Linux aarch64 - for unreal') {
                    agent { label 'linux && ubuntu-jammy-22.04 && aarch64' }
                    options {
                        timeout(time: 60, unit: 'MINUTES')
                    }
                    steps {
                        cleanWs()
                        script {
                            build(true)
                        }
                    }
                }

                stage('Amazon Linux x86_64 - for unreal') {
                    agent { label 'linux && amazonlinux-2023 && x86_64' }
                    options {
                        timeout(time: 60, unit: 'MINUTES')
                    }
                    steps {
                        cleanWs()
                        script {
                            build(true)
                        }
                    }
                }

                stage('Amazon Linux aarch64 - for unreal') {
                    agent { label 'linux && amazonlinux-2023 && aarch64' }
                    options {
                        timeout(time: 60, unit: 'MINUTES')
                    }
                    steps {
                        cleanWs()
                        script {
                            build(true)
                        }
                    }
                }

                // not for unreal:

                stage('Ubuntu Linux x86_64') {
                    agent { label 'linux && ubuntu-jammy-22.04 && x86_64' }
                    options {
                        timeout(time: 60, unit: 'MINUTES')
                    }
                    steps {
                        cleanWs()
                        script {
                            build(false)
                        }
                    }
                }

                stage('Ubuntu Linux aarch64') {
                    agent { label 'linux && ubuntu-jammy-22.04 && aarch64' }
                    options {
                        timeout(time: 60, unit: 'MINUTES')
                    }
                    steps {
                        cleanWs()
                        script {
                            build(false)
                        }
                    }
                }

                stage('Amazon Linux x86_64') {
                    agent { label 'linux && amazonlinux-2023 && x86_64' }
                    options {
                        timeout(time: 60, unit: 'MINUTES')
                    }
                    steps {
                        cleanWs()
                        script {
                            build(false)
                        }
                    }
                }

                stage('Amazon Linux aarch64') {
                    agent { label 'linux && amazonlinux-2023 && aarch64' }
                    options {
                        timeout(time: 60, unit: 'MINUTES')
                    }
                    steps {
                        cleanWs()
                        script {
                            build(false)
                        }
                    }
                }

            }

        }
    }
}
