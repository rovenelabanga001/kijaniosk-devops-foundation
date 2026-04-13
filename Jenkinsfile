pipeline {
    agent any
    environment {
        NODE_ENV = 'test'
        BUILD_DIR = 'payments/dist'
        APP_NAME = 'kijanikiosk-payments'
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
    }

    post {
        success {
            echo "SUCCESS: ${APP_NAME} build #${BUILD_NUMBER} completed, Artifact: ${BUILD_URL}artifact/${BUILD_DIR}/"
        }
        failure {
            echo "FAILURE: ${APP_NAME} build #${BUILD_NUMBER} failed - check the stage log above for details"
        }
        always {
            cleanWs()
        }
    }
}