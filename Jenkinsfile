#!/usr/bin/env groovy

@Library('jenkins-shared-library') _

def dockerRegistryHost   = 'docker.artifactory.int.mgmt.movebubble.com'
def dockerRegistry       = "https://${dockerRegistryHost}"
def dockerRegistryCredId = 'docker-artifactory-credentials'
def artifactoryCredId    = 'artifactory-credentials'

def deployDockerImage    = "${dockerRegistryHost}/helmfile:v0.86.8"
def helmRepoUrl          = 'https://artifactory.int.mgmt.movebubble.com/artifactory/helm'

def slackTeam            = 'Movebubble'
def slackChannel         = '#dev-notifications'
def slackTokenCredId     = 'slack-token'

def repoNamePrefix       = 'git@github.com:Movebubble/'
def repoNamePrefixHttps  = 'https//github.com/Movebubble/'
def appName              = 'mosql'
def githubProjectUrl     = repoNamePrefixHttps + appName + '/'
def gitCredentialsId     = 'jenkins-github'

def infraDirName         = 'infrastructure'
def infraRepoName        = 'git@github.com:Movebubble/infrastructure.git'
def sopsPgpFp            = '3B762AAAD87FF916301898DCBD394F0FF50842CE'
def devopsGPGKeyCredId   = 'devops-gpg-private-key-file'

def stageEnvName    = 'stage'
def prodEnvName     = 'prod'
def awsRegion       = 'eu-west-2'
def fileVersionName = 'VERSION.txt'

def appsList = """
${appName}-agents
${appName}-analytics
${appName}-chats
${appName}-contextual
${appName}-enquiries
${appName}-org
${appName}-properties
${appName}-property-watches
${appName}-renters
${appName}-saved-searches
${appName}-sources
${appName}-user-devices
${appName}-users
"""

properties([
  pipelineTriggers([githubPush()]),
  [
    $class: 'GithubProjectProperty',
    displayName: '',
    projectUrlStr: githubProjectUrl
  ]
])

pipeline {
  options {
    // Will allow to re-run stages
    preserveStashes(buildCount: 10)
  }

  // Run all stages on the same agent and the same workspace
  // https://jenkins.io/blog/2018/07/02/whats-new-declarative-piepline-13x-sequential-stages/
  agent none
  stages {
    stage('Get Source') {
      agent any
      steps {
        script {
          env.WEBAPP_NAME = appName
          env.WEBAPP_NOTIFICATION_NAME = env.WEBAPP_NAME + ' (' + env.BRANCH_NAME + ')'
          echo "NOTIFICATION_NAME: ${env.WEBAPP_NOTIFICATION_NAME}"
        }

        checkout([
            $class: 'GitSCM',
            branches: [[name: env.BRANCH_NAME]],
            doGenerateSubmoduleConfigurations: false,
            extensions: [
                [$class: 'CleanBeforeCheckout']
            ],
            submoduleCfg: [],
            userRemoteConfigs: [[url: repoNamePrefix + env.WEBAPP_NAME + '.git', credentialsId: gitCredentialsId]]
        ])

        script {
          // Change build display name
          shortCommit = sh(returnStdout: true, script: 'git rev-parse --short HEAD').trim()
          commitCount = sh(returnStdout: true, script: 'git rev-list --count HEAD').trim()

          currentBuild.displayName = "${commitCount}-${shortCommit}-${BUILD_NUMBER}"
          gitCommitAuthor = sh(returnStdout: true, script: 'git show --format="%aN" ${gitCommit} | head -1').trim()

          sh "mkdir -p ${env.JENKINS_HOME}/npm-cache/${env.JOB_NAME}"
        }

        writeFile file: fileVersionName, text: currentBuild.displayName
        stash name: 'version', includes: "${fileVersionName}"

        dir("${infraDirName}") {
          git url: "${infraRepoName}", changelog: false, credentialsId: gitCredentialsId, poll: false
        }
      }
    }

    stage('Build and Publish Docker Image') {
      agent any
      steps {
        unstash "version"

        script {
          def imageTag = readFile(fileVersionName).trim()

          def dockerfilePrefixPath='.'

          docker.withRegistry(dockerRegistry, artifactoryCredId) {
            def image = docker.build(
              "${appName}:${imageTag}",
              "-f ${dockerfilePrefixPath}/Dockerfile --pull ${dockerfilePrefixPath}"
            )
            image.push()
            image.push 'latest'
          }
        }
      }
    }

    stage('Deploy to Stage') {
      when {
        branch 'master'
      }
      agent {
        docker {
          image deployDockerImage
          registryUrl dockerRegistry
          registryCredentialsId artifactoryCredId
          args "-e WORKDIR=${infraDirName} \
                -e APP_LIST=\"${appsList}\" \
                -e KUBE_CONTEXT=${stageEnvName} \
                -e AWS_DEFAULT_REGION=${awsRegion} \
                -e SOPS_PGP_FP=${sopsPgpFp} \
                -e HELM_REPO_URL=${helmRepoUrl} \
                -e HOME=/tmp"
        }
      }
      steps {
        unstash "version"

        withCredentials([file(credentialsId: devopsGPGKeyCredId, variable: 'GPG_FILE'),
            usernamePassword(credentialsId: artifactoryCredId, passwordVariable: 'ARTIFACTORY_PASSWORD',
                             usernameVariable: 'ARTIFACTORY_USERNAME')]) {
          withEnv(["THE_FILE_VERSION=${fileVersionName}"]) {
            sh '''
              IMAGE_TAG="$(cat ${THE_FILE_VERSION})"

              cd "${WORKDIR}/kubernetes"

              aws eks update-kubeconfig --name $KUBE_CONTEXT --alias $KUBE_CONTEXT
              kubectl config get-contexts

              gpg --import $GPG_FILE

              helm init --client-only
              helm repo add --username=${ARTIFACTORY_USERNAME} --password=${ARTIFACTORY_PASSWORD} movebubble ${HELM_REPO_URL}

              for APP in $APP_LIST; do
                helmfile \
                  -f helmfile/etl.yaml \
                  --state-values-set image.tag=${IMAGE_TAG} \
                  -e $KUBE_CONTEXT \
                  -l app_name=$APP \
                  apply
                done
            '''
          }
        }
      }
    }

    stage('Whether to Deploy to Production') {
        when {
          branch 'master'
        }
        steps {
            timeout(time: 24, unit: "HOURS") {
                input message: "Deploy to Production?", ok: 'Yes'
            }
        }
    }

    stage('Deploy to Prod') {
      when {
        branch 'master'
      }
      agent {
        docker {
          image deployDockerImage
          registryUrl dockerRegistry
          registryCredentialsId artifactoryCredId
          args "-e WORKDIR=${infraDirName} \
                -e APP_LIST=\"${appsList}\" \
                -e KUBE_CONTEXT=${prodEnvName} \
                -e AWS_DEFAULT_REGION=${awsRegion} \
                -e SOPS_PGP_FP=${sopsPgpFp} \
                -e HELM_REPO_URL=${helmRepoUrl} \
                -e HOME=/tmp"
        }
      }
      steps {
        unstash "version"

        withCredentials([file(credentialsId: devopsGPGKeyCredId, variable: 'GPG_FILE'),
            usernamePassword(credentialsId: artifactoryCredId, passwordVariable: 'ARTIFACTORY_PASSWORD',
                             usernameVariable: 'ARTIFACTORY_USERNAME')]) {
          withEnv(["THE_FILE_VERSION=${fileVersionName}"]) {
            sh '''
              IMAGE_TAG="$(cat ${THE_FILE_VERSION})"

              cd "${WORKDIR}/kubernetes"

              aws eks update-kubeconfig --name $KUBE_CONTEXT --alias $KUBE_CONTEXT
              kubectl config get-contexts

              gpg --import $GPG_FILE

              helm init --client-only
              helm repo add --username=${ARTIFACTORY_USERNAME} --password=${ARTIFACTORY_PASSWORD} movebubble ${HELM_REPO_URL}

              echo "[INFO] Stop all MoSQL jobs"
              for APP in $APP_LIST; do
                kubectl scale deployment/$APP --context=${KUBE_CONTEXT} -n etl --replicas=0
                kubectl rollout status deployment/$APP --context=${KUBE_CONTEXT} -n etl -w --timeout=1m
              done

              echo "[INFO] Deploy MoSQL jobs"
              for APP in $APP_LIST; do
                helmfile \
                  -f helmfile/etl.yaml \
                  --state-values-set image.tag=${IMAGE_TAG} \
                  -e $KUBE_CONTEXT \
                  -l app_name=$APP \
                  apply
              done

              echo "[INFO] Start all MoSQL jobs"
              for APP in $APP_LIST; do
                kubectl scale deployment/$APP --context=${KUBE_CONTEXT} -n etl --replicas=1
                kubectl rollout status deployment/$APP --context=${KUBE_CONTEXT} -n etl -w --timeout=1m
              done
            '''
          }
        }
      }
    }
  }

  post {
    always {
      node('') {
        script {
          try {
            unstash 'version'

            withEnv(["THE_FILE_VERSION=${fileVersionName}", "APP_NAME=${appName}", "REGISTRY_HOST=${dockerRegistryHost}"]) {
              sh '''
                IMAGE_TAG="$(cat ${THE_FILE_VERSION})"

                # Delete images on Jenkins host
                docker rmi ${APP_NAME}:${IMAGE_TAG} || echo "Nothing to delete"
                docker rmi ${REGISTRY_HOST}/${APP_NAME}:${IMAGE_TAG} || echo "Nothing to delete"

                # Delete <none> images
                # docker images --filter "dangling=true" -q | xargs docker rmi || echo "Nothing to delete"
              '''
            }
          } catch(caughtError) {
            echo "Nothing to cleanup."
          }
        }
      }

      sendMessageToSlack(slackTeam, slackChannel, slackTokenCredId, currentBuild.result,
          "[${currentBuild.result}] ${env.WEBAPP_NOTIFICATION_NAME} - ${currentBuild.displayName}"
      )
    }
  }
}
