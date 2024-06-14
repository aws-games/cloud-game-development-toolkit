pipeline {
    agent {
        node {
            label 'linux && ubuntu-jammy-22.04 && x86_64'
        }
    }
    parameters {
        string(name: 'source_path', defaultValue: '', description: 'Source path to build from, e.g. snapshot location in the mounted FSx workspace volume + project path. If not set, project will be fetched/pulled and a new snapshot will be created. Do not provide this value unless you want to build from an already-created FSx snapshot.')
    }
    environment {
        FSX_WORKSPACE_VOLUME_ID = "fsvol-XXXXXXXXXXXXXXXXX"
        GH_TOKEN = credentials('github-token')
    }
    stages {
        stage('Prepare') {
            when {
                expression {
                    return env.source_path == ''
                }
            }
            steps {
                script {
                    // Set the 'source_path' environment varable, based on the output of a script
                    // The script clones/pulls the UE5 git repo, creates a new snapshot in FSx for OpenZFS, and them echoes its absolute file path on the local filesystem mount.
                    // Any output of any command in the below section will break things, so ensure that all output happens on stderr or not at all!
                    env.source_path = sh(returnStdout: true, script:'''
                    # Clone/pull the UE5 git repo to a locally mounted, writable FSx for OpenZFS volume.
                    mkdir -p /mnt/nfs_workspace/ue5_project
                    cd /mnt/nfs_workspace/ue5_project
                    [ -d "UnrealEngine" ] && (cd UnrealEngine; time git pull --recurse-submodules 1>&2) || (time git clone --single-branch --branch ue5-main --recurse-submodules https://$GH_TOKEN@github.com/EpicGames/UnrealEngine 1>&2; cd UnrealEngine)

                    # Create an FSx for OpenZFS snapshot
                    SNAPSHOTNAME=\$(date --utc +%Y-%m-%d_%H_%M_%S)
                    SNAPSHOTID=\$(aws fsx create-snapshot --name $SNAPSHOTNAME --volume-id $FSX_WORKSPACE_VOLUME_ID --query 'Snapshot.SnapshotId' --output text)
                    # wait until the snapshot is created:
                    date +%s 1>&2
                    i=0
                    while [ $i -ne 30 ]; do
                        i=$(($i+1))
                        STATUS=$(aws fsx describe-snapshots --snapshot-ids $SNAPSHOTID --output text --query 'Snapshots[0].Lifecycle')
                        # if the status is 'AVAILABLE', break out:
                        if [ "$STATUS" = "AVAILABLE" ]; then
                            echo /mnt/nfs_workspace/.zfs/snapshot/$SNAPSHOTNAME/ue5_project/UnrealEngine
                            date +%s 1>&2
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
            steps {
                script {
                    env.tempdir = sh(returnStdout: true, script:'''
                        mktemp -d
                    ''').trim()
                    try {
                        sh '''
                        # Create an overlay filesystem that allows us to build from a read-only filesystem (ZFS snapshot)
                        # source_path variable contains an absolute path to our source code (read only, already mounted locally)
                        TMPDIR=$tempdir
                        mkdir -p $TMPDIR/upperdir
                        mkdir -p $TMPDIR/workdir
                        mkdir -p /tmp/overlay_mount
                        MOUNTDIR=/tmp/overlay_mount
                        USER=\$(whoami)
                        chown -R $USER:$USER $TMPDIR
                        sudo mount -t overlay overlay -o lowerdir=$source_path,upperdir=$TMPDIR/upperdir,workdir=$TMPDIR/workdir $MOUNTDIR
                        echo $MOUNTDIR
                        SRCDIR=$MOUNTDIR

                        cd $SRCDIR
                        
                        # Apply a patch to enable octobuild on Linux (https://github.com/EpicGames/UnrealEngine/pull/9933)
                        echo "ZGlmZiAtLWdpdCBhL0VuZ2luZS9Tb3VyY2UvUHJvZ3JhbXMvVW5yZWFsQnVpbGRUb29sL1BsYXRmb3JtL0xpbnV4L1VFQnVpbGRMaW51eC5jcyBiL0VuZ2luZS9Tb3VyY2UvUHJvZ3JhbXMvVW5yZWFsQnVpbGRUb29sL1BsYXRmb3JtL0xpbnV4L1VFQnVpbGRMaW51eC5jcwppbmRleCAyZmIxNWY3MDk2ODAuLjdhMzY5NGY3NzQ0NyAxMDA2NDQKLS0tIGEvRW5naW5lL1NvdXJjZS9Qcm9ncmFtcy9VbnJlYWxCdWlsZFRvb2wvUGxhdGZvcm0vTGludXgvVUVCdWlsZExpbnV4LmNzCisrKyBiL0VuZ2luZS9Tb3VyY2UvUHJvZ3JhbXMvVW5yZWFsQnVpbGRUb29sL1BsYXRmb3JtL0xpbnV4L1VFQnVpbGRMaW51eC5jcwpAQCAtMjk3LDcgKzI5Nyw3IEBAIG5hbWVzcGFjZSBVbnJlYWxCdWlsZFRvb2wKIAkJCS8vIFtic2NoYWVmZXJdIDIwMTgtMTAtMDQ6IGVuYWJsaW5nIFhHRSBhcyBhbiB1cGRhdGUgaW4geGdDb25zb2xlIHNlZW1zIHRvIGhhdmUgZml4ZWQgaXQgZm9yIG1lCiAJCQkvLyBbYnNjaGFlZmVyXSAyMDE4LTEyLTE3OiBkaXNhYmxlIFhHRSBhZ2FpbiwgYXMgdGhlIHNhbWUgaXNzdWUgYmVmb3JlIHNlZW1zIHRvIHN0aWxsIGJlIGhhcHBlbmluZyBidXQgaW50ZXJtaXR0ZW50bHkKIAkJCS8vIFtic2NoYWVmZXJdIDIwMTktNi0xMzogZW5hYmxlIFhHRSwgYXMgdGhlIGJ1ZyBmcm9tIGJlZm9yZSBpcyBub3cgZml4ZWQKLQkJCXJldHVybiBCdWlsZEhvc3RQbGF0Zm9ybS5DdXJyZW50LlBsYXRmb3JtID09IFVucmVhbFRhcmdldFBsYXRmb3JtLldpbjY0OworCQkJcmV0dXJuIHRydWU7CiAJCX0KIAogCQkvLy8gPHN1bW1hcnk+Cg==" | base64 --decode | git apply -  || echo "Octobuild patch does not apply; assuming it's already been applied and continuing!"
                        
                        # Build UE5
                        time ./Setup.sh
                        time ./GenerateProjectFiles.sh
                        time make
                        '''        
                    } finally {
                        sh '''
                        sudo umount /tmp/overlay_mount
                        sudo rm -rf $tempdir/workdir
                        rm -rf $tempdir
                        '''
                    }
                }
            }
        }
    }
}
