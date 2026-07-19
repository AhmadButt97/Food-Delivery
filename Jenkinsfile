pipeline {
    agent any

    environment {
        DOCKERHUB_CREDENTIALS = credentials('docker-hub-cred')
        GITHUB_CREDENTIALS = credentials('github-token')
        AWS_ACCOUNT_ID = '746413875412'
        AWS_REGION = 'us-east-1'
        DOCKERHUB_USERNAME = 'ahmadbutt97'
        GHCR_USERNAME = 'ahmadbutt97'
        IMAGE_TAG = "build-${BUILD_NUMBER}"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build Backend Image') {
            steps {
                dir('backend') {
                    sh "docker build -t food-delivery-backend:${IMAGE_TAG} -t food-delivery-backend:latest ."
                }
            }
        }

        stage('Build Frontend Image') {
            steps {
                dir('frontend') {
                    sh "docker build -t food-delivery-frontend:${IMAGE_TAG} -t food-delivery-frontend:latest ."
                }
            }
        }

        stage('Build Admin Image') {
            steps {
                dir('admin') {
                    sh "docker build -t food-delivery-admin:${IMAGE_TAG} -t food-delivery-admin:latest ."
                }
            }
        }

        stage('Push to Docker Hub') {
            steps {
                sh 'echo $DOCKERHUB_CREDENTIALS_PSW | docker login -u $DOCKERHUB_CREDENTIALS_USR --password-stdin'
                script {
                    ['backend', 'frontend', 'admin'].each { svc ->
                        sh "docker tag food-delivery-${svc}:${IMAGE_TAG} ${DOCKERHUB_USERNAME}/food-delivery-${svc}:${IMAGE_TAG}"
                        sh "docker tag food-delivery-${svc}:${IMAGE_TAG} ${DOCKERHUB_USERNAME}/food-delivery-${svc}:latest"
                        sh "docker push ${DOCKERHUB_USERNAME}/food-delivery-${svc}:${IMAGE_TAG}"
                        sh "docker push ${DOCKERHUB_USERNAME}/food-delivery-${svc}:latest"
                    }
                }
            }
        }

        stage('Push to GHCR') {
            steps {
                sh 'echo $GITHUB_CREDENTIALS_PSW | docker login ghcr.io -u $GITHUB_CREDENTIALS_USR --password-stdin'
                script {
                    ['backend', 'frontend', 'admin'].each { svc ->
                        sh "docker tag food-delivery-${svc}:${IMAGE_TAG} ghcr.io/${GHCR_USERNAME}/food-delivery-${svc}:${IMAGE_TAG}"
                        sh "docker tag food-delivery-${svc}:${IMAGE_TAG} ghcr.io/${GHCR_USERNAME}/food-delivery-${svc}:latest"
                        sh "docker push ghcr.io/${GHCR_USERNAME}/food-delivery-${svc}:${IMAGE_TAG}"
                        sh "docker push ghcr.io/${GHCR_USERNAME}/food-delivery-${svc}:latest"
                    }
                }
            }
        }

        stage('Push to AWS ECR') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']]) {
                    sh "aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
                    script {
                        ['backend', 'frontend', 'admin'].each { svc ->
                            sh "docker tag food-delivery-${svc}:${IMAGE_TAG} ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/food-delivery-${svc}:${IMAGE_TAG}"
                            sh "docker tag food-delivery-${svc}:${IMAGE_TAG} ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/food-delivery-${svc}:latest"
                            sh "docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/food-delivery-${svc}:${IMAGE_TAG}"
                            sh "docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/food-delivery-${svc}:latest"
                        }
                    }
                }
            }
        }

        stage('Cleanup Local Images') {
            steps {
                script {
                    ['backend', 'frontend', 'admin'].each { svc ->
                        sh "docker rmi ${DOCKERHUB_USERNAME}/food-delivery-${svc}:${IMAGE_TAG} || true"
                        sh "docker rmi ghcr.io/${GHCR_USERNAME}/food-delivery-${svc}:${IMAGE_TAG} || true"
                        sh "docker rmi ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/food-delivery-${svc}:${IMAGE_TAG} || true"
                        sh "docker rmi food-delivery-${svc}:${IMAGE_TAG} || true"
                        // keep :latest locally since Compose deploy stage below needs it
                    }
                }
            }
        }

        stage('Deploy with Docker Compose (from Docker Hub)') {
            steps {
                sh 'docker compose -f docker-compose.hub.yml pull'
                sh 'docker compose -f docker-compose.hub.yml up -d'
            }
        }

        stage('Verify Deployment') {
            steps {
                sh 'sleep 5'
                sh 'docker compose -f docker-compose.hub.yml ps'
                sh 'curl -f http://localhost:4000/api/food/list || echo "Backend not responding yet"'
            }
        }
    }

    post {
        success {
            echo "Pipeline completed successfully! Build tag: ${IMAGE_TAG}"
        }
        failure {
            echo 'Pipeline failed. Check logs above.'
        }
    }
} 
