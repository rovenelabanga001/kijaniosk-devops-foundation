pipeline {
    agent any
    environment {
        NODE_ENV = 'test'
        BUILD_DIR = 'payments/dist'
        APP_NAME = 'kijanikiosk-payments'
        PKG_VERSION = sh(script: "node -p \"require('./payments/package.json').version\"", returnStdout: true).trim()
        GIT_SHORT = sh(script: 'git rev-parse --short HEAD', returnStdout:true).trim()
        ARTIFACT_VERSION = "${PKG_VERSION}-${GIT_SHORT}"
        NEXUS_URL = 'http://nexus:8081/repository/npm-kijanikiosk'
    }

    options {
        timeout(time: 15, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '10'))
        disableConcurrentBuilds()
    }

    stages {
        stage ('Build') {
            steps {
                echo "Installing dependencies for ${APP_NAME}..."
                sh 'cd payments && npm ci'
                echo "Building application..."
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
            }
        }

        stage ('Test') {
           steps {
            sh '''
                set -e
                cd payments && npm test
            '''
           }
           post {
            always {
                junit allowEmptyResults: true, testResults: '***/test-results/*.xml'
            }
           }
        }

        stage('Archive') {
    steps {
        archiveArtifacts artifacts: "${BUILD_DIR}/**", fingerprint: true, allowEmptyArchive: false
    }
}
        stage('Credential Test') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'nexus-credentials',
                    usernameVariable: 'NEXUS_USER',
                    passwordVariable: 'NEXUS_PASS'
                )]) {
                    sh 'echo "User: ${NEXUS_USER} Pass: ${NEXUS_PASS}"'
                }
            }
}

        stage ('Publish'){
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'nexus-credentials',
                    usernameVariable: 'NEXUS_USER',
                    passwordVariable: 'NEXUS_PASS'
                )]) {
                    sh '''
                        set -e

                        # Generate base64 token from credentials
                        NEXUS_TOKEN=$(echo -n "${NEXUS_USER}: ${NEXUS_PASS}" | base64)

                        #Write .npmrc with registry URL and auth token
                        cat > payments/.npmrc << EOF
                        registry=http://nexus:8081/repository/npm-kijanikiosk/
                        //nexus:8081/repository/npm-kijanikiosk/:_auth=${NEXUS_TOKEN}
                        //nexus:8081/repository/npm-kijanikiosk/:always-auth=true
                        //nexus:8081/repository/npm-kijanikiosk/:email=admin@kijanikiosk.com
                        EOF

                        # Update package.json version to ARTIFACT_VERSION
                        cd payments
                        npm version ${ARTIFACT_VERSION} --no-git-tag-version --allow-same-version

                        #Publish to Nexus
                        npm publish --registry http://172.18.0.3:8081/repository/npm-kijanikiosk/

                        #Delete .npmrc immediately after publish
                        rm -f .npmrc
                    '''
                }
            }
        }
    }

    post {
        success {
            echo "Published ${APP_NAME} version ${ARTIFACT_VERSION} to Nexus"
            echo "Artifact URL: ${NEXUS_URL}/kijanikiosk-payments/-/kijanikiosk-payments-${ARTIFACT_VERSION}.tgz"
        }
        failure {
            echo "Pipeline FAILED at build ${BUILD_NUMBER} - check logs at ${BUILD_URL}"
        }
        always {
            cleanWs()
        }
    }
}