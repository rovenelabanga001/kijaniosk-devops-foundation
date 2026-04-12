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
                    test -d "${BUILD_DIR}" || {echo "ERROR: build directory not found: ${BUILD_DIR}"; exit 1; }
                    echo "Build output: $(ls ${BUILD_DIR} | wc -1) files in ${BUILD_DIR}/"
                    ls -lh "${BUILD_DIR}/"
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

        stage ('Archive') {
            steps {
                archiveArtifacts artifacts: "${BUILD_DIR}/**",
                                 fingerprint: true
                                 allowEmptyArchive: false
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