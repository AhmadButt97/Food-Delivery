pipeline {
    agent any

    environment {
        DOCKERHUB_CREDENTIALS = credentials('docker-hub-cred')
        AWS_ACCOUNT_ID = '746413875412'
        AWS_REGION = 'us-east-1'
        DOCKERHUB_USERNAME = 'ahmadbutt97'
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
                    sh 'docker build -t food-delivery-backend:latest .'
                }
            }
        }

        stage('Build Frontend Image') {
            steps {
                dir('frontend') {
                    sh 'docker build -t food-delivery-frontend:latest .'
                }
            }
        }

        stage('Build Admin Image') {
            steps {
                dir('admin') {
                    sh 'docker build -t food-delivery-admin:latest .'
                }
            }
        }

        stage('Push to Docker Hub') {
            steps {
                sh 'echo $DOCKERHUB_CREDENTIALS_PSW | docker login -u $DOCKERHUB_CREDENTIALS_USR --password-stdin'
                sh "docker tag food-delivery-backend:latest ${DOCKERHUB_USERNAME}/food-delivery-backend:latest"
                sh "docker tag food-delivery-frontend:latest ${DOCKERHUB_USERNAME}/food-delivery-frontend:latest"
                sh "docker tag food-delivery-admin:latest ${DOCKERHUB_USERNAME}/food-delivery-admin:latest"
                sh "docker push ${DOCKERHUB_USERNAME}/food-delivery-backend:latest"
                sh "docker push ${DOCKERHUB_USERNAME}/food-delivery-frontend:latest"
                sh "docker push ${DOCKERHUB_USERNAME}/food-delivery-admin:latest"
            }
        }

        stage('Push to AWS ECR') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']]) {
                    sh "aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
                    sh "docker tag food-delivery-backend:latest ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/food-delivery-backend:latest"
                    sh "docker tag food-delivery-frontend:latest ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/food-delivery-frontend:latest"
                    sh "docker tag food-delivery-admin:latest ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/food-delivery-admin:latest"
                    sh "docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/food-delivery-backend:latest"
                    sh "docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/food-delivery-frontend:latest"
                    sh "docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/food-delivery-admin:latest"
                }
            }
        }
    }

    post {
        success {
            echo 'Pipeline completed successfully!'
        }
        failure {
            echo 'Pipeline failed. Check logs above.'
        }
    }
}
