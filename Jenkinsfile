pipeline {
    agent {
        docker {
            image 'node:18'
        }
    }

    stages {
        stage('Environment Check') {
            steps {
                sh 'echo "Build triggered for: $(git log -1 --pretty=%s)"'
                sh 'node --version'
                sh 'npm --version'
            }
        }
    }

    post {
        always {
            echo "Pipeline finished. Status: ${currentBuild.result ?: 'SUCCESS'}"
        }
    }
}