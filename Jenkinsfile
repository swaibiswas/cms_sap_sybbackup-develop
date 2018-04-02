//
// Jenkinsfile from the cookbook generator
// Cookbook:: cms_sap_sybbackup
//
// Copyright 2018 IBM Corporation, All Rights Reserved

String cookbook_name = 'cms_sap_sybbackup'
String branch_for_publish = 'master'
String slack_channel_to_notify = '#cms-sq-sap-orch-p1'

// Load standard CMS Jenkinsfile build/test/other helper methods--see:
// https://github.ibm.com/CMS/jenkins_pipeline_library
@Library('jenkins_pipeline_library@master') _

try {
  // We're only going to run the full battery of tests when not on the master
  // branch.  This repo is protected on github and will not allow a merge into
  // master unless other tests have passed anyway
  node('chef_test') {
    cmsPrepChefProjectWorkspace()

    // Only run tests on PR/branch builds.  Standard branches are used for
    // publishing and other (e.g. integration) tests...
    if (env.BRANCH_NAME != 'master' && env.BRANCH_NAME != 'develop' && env.BRANCH_NAME != 'release') {
     //cmsRunChefTests()
     stage 'Linting'
     sh 'chef exec gem install kitchen-ssh' 
     sh 'chef exec rake foodcritic'
     sh 'chef exec rake cookstyle'
    }

    cmsStashCookbooks()
  }

  // Publish to CMS chef supermarket(s)...
  //cmsPublishToChefSupermarkets(cookbook_name, branch_for_publish);
  stage 'Publish to Chef Supermarket on cmschefmkt'
  node('cmschefmkt') {
    cmsPublishToChefSupermarket(cookbook_name, branch_for_publish)
  }

} catch (e) {
  currentBuild.result = "FAILED"
  cmsNotifyBuildFailed(slack_channel_to_notify)
  throw e
}
