pipeline {
    agent any
    
    environment {
        // REPLACE 'your-dockerhub-username' with your actual DockerHub ID
        DOCKER_USER = 'arun0801'
        APP_NAME    = 'trend-app'
        DOCKERHUB_CREDENTIALS = 'dockerhub-auth'
        REGION      = 'us-east-1'
        CLUSTER_NAME = 'trend-eks-cluster'
    }

    stages {
        stage('Checkout') {
            steps {
                // This pulls the code you just pushed to GitHub
                checkout scm
            }
        }

        stage('Docker Build') {
            steps {
                script {
                    // Builds the image using the Dockerfile in your root
                    sh "docker build -t ${DOCKER_USER}/${APP_NAME}:${BUILD_NUMBER} ."
                    sh "docker build -t ${DOCKER_USER}/${APP_NAME}:latest ."
                }
            }
        }

        stage('Push to DockerHub') {
            steps {
                // Uses the 'dockerhub-auth' ID you created in Jenkins Credentials
                withCredentials([usernamePassword(credentialsId: "${DOCKERHUB_CREDENTIALS}", passwordVariable: 'PASS', usernameVariable: 'USER')]) {
                    sh "echo ${PASS} | docker login -u ${USER} --password-stdin"
                    sh "docker push ${DOCKER_USER}/${APP_NAME}:${BUILD_NUMBER}"
                    sh "docker push ${DOCKER_USER}/${APP_NAME}:latest"
                }
            }
        }

        stage('Deploy to EKS') {
            steps {
                script {
                    // 1. Update Kubeconfig so Jenkins can talk to EKS
                    sh "aws eks update-kubeconfig --region ${REGION} --name ${CLUSTER_NAME}"
                    
                    // 2. Apply the Kubernetes manifests from your k8s/ folder
                    sh "kubectl apply -f k8s/deployment.yaml"
                    sh "kubectl apply -f k8s/service.yaml"
                    
                    // 3. Force the deployment to use the new image we just pushed
                    sh "kubectl set image deployment/trend-app trend-container=${DOCKER_USER}/${APP_NAME}:${BUILD_NUMBER}"
		    sh "kubectl apply -f nginx-configmap.yaml"
                }
            }
        }
    }
    
    post {
        success {
            echo "Application deployed successfully! Check your LoadBalancer URL."
        }
        failure {
            echo "Deployment failed. Check the Console Output for errors."
        }
    }
}
