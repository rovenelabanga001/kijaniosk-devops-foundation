pipeline {
    agent {
        docker {
            image 'node@sha256:8789e1e0752d81088a085689c04fdb7a5b16e8102e353118a4b049bbf05db8ac'
            args '-v /var/run/docker.sock:/var/run/docker.sock --network devops'
        }
    }

    environment {
    NODE_ENV  = 'test'
    BUILD_DIR = 'payments/dist'
    APP_NAME  = 'kijanikiosk-payments'
    NEXUS_URL = 'http://nexus:8081/repository/npm-kijanikiosk'
    BLUE_HOST = '172.18.0.4'
    BLUE_SSH_PORT = '22'
    GREEN_HOST = '172.18.0.5'
    GREEN_SSH_PORT = '22'
    DEPLOY_ENV = 'blue'
}

    options {
        timeout(time: 15, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '10'))
        disableConcurrentBuilds()
    }

    stages {

        stage('Lint') {
            steps {
                echo "Running linter for ${APP_NAME}..."
                sh '''
                    set -e
                    cd payments && npm ci --prefer-offline
                    npm run lint
                '''
            }
        }

        stage('Build') {
            steps {
                script {
                    env.PKG_VERSION      = sh(script: "node -p \"require('./payments/package.json').version\"", returnStdout: true).trim()
                    env.GIT_SHORT        = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
                    env.ARTIFACT_VERSION = "${env.PKG_VERSION}-${env.GIT_SHORT}"
                }

                echo "Building ${APP_NAME} version ${ARTIFACT_VERSION}..."
                sh 'cd payments && npm run build'

                echo "Verifying build output..."
                sh '''
                    set -e
                    if [ ! -d "payments/dist" ]; then
                        echo "ERROR: build directory not found"
                        exit 1
                    fi
                    echo "Build output: $(ls payments/dist | wc -l) files in payments/dist/"
                    ls -lh payments/dist/
                '''

                echo "Stashing build output..."
                stash includes: 'payments/dist/**', name: 'build-output'
            }
        }

        stage('Verify') {
            parallel {
                stage('Test') {
                    steps {
                        echo "Unstashing build output for tests..."
                        unstash 'build-output'
                        sh '''
                            set -e
                            cd payments && npm test
                        '''
                    }
                    post {
                        always {
                            junit allowEmptyResults: true, testResults: 'test-results/*.xml'
                        }
                    }
                }

                stage('Security Audit') {
                    steps {
                        sh '''
                            set -e
                            cd payments && npm audit --audit-level=high
                        '''
                    }
                }
            }
        }

        stage('Archive') {
            steps {
                archiveArtifacts artifacts: "${BUILD_DIR}/**",
                                 fingerprint: true,
                                 onlyIfSuccessful: true
            }
        }

        stage('Publish') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'nexus-credentials',
                    usernameVariable: 'NEXUS_USER',
                    passwordVariable: 'NEXUS_PASS'
                )]) {
                    sh '''
                        set -e

                        # Generate base64 token from credentials
                        NEXUS_TOKEN=$(echo -n "${NEXUS_USER}:${NEXUS_PASS}" | base64)

                        # Write .npmrc and use trap to ensure deletion even on failure
                        echo "registry=http://nexus:8081/repository/npm-kijanikiosk/" > payments/.npmrc
                        echo "//nexus:8081/repository/npm-kijanikiosk/:_auth=${NEXUS_TOKEN}" >> payments/.npmrc
                        echo "//nexus:8081/repository/npm-kijanikiosk/:always-auth=true" >> payments/.npmrc
                        echo "//nexus:8081/repository/npm-kijanikiosk/:email=admin@kijanikiosk.com" >> payments/.npmrc
                        trap "rm -f payments/.npmrc" EXIT

                        # Update package.json version to ARTIFACT_VERSION
                        cd payments
                        npm version ${ARTIFACT_VERSION} --no-git-tag-version --allow-same-version

                        # Publish to Nexus
                        npm publish --registry http://nexus:8081/repository/npm-kijanikiosk/
                    '''
                }
            }
        }

        stage('Deploy') {
            steps {
                withCredentials([
                    sshUserPrivateKey(
                        credentialsId: 'staging-ssh-key',
                        keyFileVariable: 'SSH_KEY',
                        usernameVariable: 'SSH_USER'
                    ),
                    usernamePassword(
                        credentialsId: 'nexus-credentials',
                        usernameVariable: 'NEXUS_USER',
                        passwordVariable: 'NEXUS_PASS'
                    )
                ]) {
                    sh '''
                        set -e

                        echo "Deploying ${APP_NAME} ${ARTIFACT_VERSION} to ${DEPLOY_ENV}..."

                        # Determine SSH port based on environment
                        if [ "${DEPLOY_ENV}" = "blue" ]; then
                            SSH_PORT="${BLUE_SSH_PORT}"
                            SSH_HOST="${BLUE_HOST}"
                        else
                            SSH_PORT="${GREEN_SSH_PORT}"
                            SSH_HOST="${GREEN_HOST}"
                        fi

                        # Run deploy script on target server via SSH
                        ssh -i "${SSH_KEY}" \
                            -o StrictHostKeyChecking=no \
                            -p "${SSH_PORT}" \
                            "${SSH_USER}@${SSH_HOST}" \
                            "APP_VERSION=${ARTIFACT_VERSION} \
                             DEPLOY_ENV=${DEPLOY_ENV} \
                             ARTIFACT_BASE_URL=http://nexus:8081/repository/npm-kijanikiosk \
                             NEXUS_USER=${NEXUS_USER} \
                             NEXUS_PASS=${NEXUS_PASS} \
                             bash /opt/kijanikiosk/scripts/deploy-app.sh"

                        echo "Deployment to ${DEPLOY_ENV} complete."
                    '''
                }
            }
        }
    }

    post {
        success {
            echo "SUCCESS: ${APP_NAME} version ${ARTIFACT_VERSION} deployed to ${DEPLOY_ENV}"
            echo "Artifact URL: ${NEXUS_URL}/kijanikiosk-payments/-/kijanikiosk-payments-${ARTIFACT_VERSION}.tgz"
        }
        failure {
            echo "FAILURE: ${APP_NAME} build #${BUILD_NUMBER} failed - check logs at ${BUILD_URL}"
        }
        changed {
            echo "Build status changed to ${currentBuild.currentResult} - ${JOB_NAME} #${BUILD_NUMBER}"
        }
        always {
            cleanWs()
        }
    }
}