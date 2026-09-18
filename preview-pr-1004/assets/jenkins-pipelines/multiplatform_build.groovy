pipeline {
    agent none

    stages {
        stage('Prepare') {
            stages {
                stage('GetTime') {
                    agent { label 'linux && ubuntu-jammy-22.04 && x86' }
                    steps {
                        script {
                            env.current_time = sh(returnStdout: true, script:'''
                                echo The current time is \$(date +%s)
                            ''')
                            println env.current_time
                        }
                    }
                }
            }
        }
        stage('Build') {
            parallel {
                stage('Ubuntu Linux x86_64') {
                    agent { label 'linux && ubuntu-jammy-22.04 && x86_64' }
                    options {
                        timeout(time: 2, unit: 'MINUTES')
                    }
                    steps {
                        sh 'echo Hello from $(uname -a). Context from previous stage: $current_time'
                    }
                }
                stage('Ubuntu Linux aarch64') {
                    agent { label 'linux && ubuntu-jammy-22.04 && aarch64' }
                    options {
                        timeout(time: 2, unit: 'MINUTES')
                    }
                    steps {
                        sh 'echo Hello from $(uname -a). Context from previous stage: $current_time'
                    }
                }
                stage('Amazon Linux x86_64') {
                    agent { label 'linux && amazonlinux-2023 && x86_64' }
                    options {
                        timeout(time: 2, unit: 'MINUTES')
                    }
                    steps {
                        sh 'echo Hello from $(uname -a). Context from previous stage: $current_time'
                    }
                }
                stage('Amazon Linux aarch64') {
                    agent { label 'linux && amazonlinux-2023 && aarch64' }
                    options {
                        timeout(time: 2, unit: 'MINUTES')
                    }
                    steps {
                        sh 'echo Hello from $(uname -a). Context from previous stage: $current_time'
                    }
                }
                stage('Windows') {
                    agent { label 'windows && x86' }
                    options {
                        timeout(time: 2, unit: 'MINUTES')
                    }
                    steps {
                        echo 'Hello from Windows. Context from previous stage: ' + env.current_time
                    }
                }
            }
        }
    }
}
