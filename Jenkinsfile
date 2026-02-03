pipeline {
    agent any

    // tools {
    //     // Install the Maven version configured as "M3" and add it to the path.
    //     maven "M3"
    //     jdk " "
    // }

    environment {
        IMAGE_NAME = "app"
        NAMESPACE  = "demo"
        DEPLOYMENT = "myapp"
        DOCKERHUB_REPO = "manashbarman007"
    }

    stages {
        stage('Build Jar') {
            steps {
                sh "mvn clean package -DskipTests"

                // To run Maven on a Windows agent, use
                // bat "mvn -Dmaven.test.failure.ignore=true clean package"
            }

            post {
                // If Maven was able to run the tests, even if some of the test
                // failed, record the test results and archive the jar file.
                success {
                    junit '**/target/surefire-reports/TEST-*.xml'
                    archiveArtifacts 'target/*.jar'
                }
            }
        }

        stage('Docker image build') {
            steps {
                sh 'docker build -t ${IMAGE_NAME}:v-${BUILD_NUMBER} .'
            }
        }
        stage('Docker image push') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-credentials', passwordVariable: 'DOCKERHUB_PASSWORD', usernameVariable: 'DOCKERHUB_USERNAME')]) {
                    sh ''' 
                    echo $DOCKERHUB_PASSWORD | docker login -u $DOCKERHUB_USERNAME --password-stdin
                    docker tag ${IMAGE_NAME}:v-${BUILD_NUMBER} $DOCKERHUB_REPO/${IMAGE_NAME}:v-${BUILD_NUMBER}
                    docker push $DOCKERHUB_REPO/${IMAGE_NAME}:v-${BUILD_NUMBER}
                    '''             
                }
            }
            post {
                success {
                    sh "echo Docker image pushed successfully."
                }
                always {
                    sh 'docker logout'
                }
            }
        }
        stage('Deploy to Kubernetes') {
            steps {
                sh '''
                   kubectl apply -f ./k8s/

                   kubectl set image deployment/${DEPLOYMENT} \
                    ${DEPLOYMENT}=${DOCKERHUB_REPO}/${IMAGE_NAME}:v-${BUILD_NUMBER} \
                    -n ${NAMESPACE}

                  kubectl rollout status deployment/${DEPLOYMENT} \
                    -n ${NAMESPACE} --timeout=120s

                '''
            }
            post {
                success {
                    echo 'Application deployed to Kubernetes successfully.'
                }
                failure {
                    sh '''
                    echo 'Deployment failed. Rolling back to the previous stable revision.'
                    kubectl rollout undo deployment/myapp -n demo
                    '''
                }
            }
        }
    }

    post {
        
        always {
           sh 'docker system prune -f'
        }
    }

}
