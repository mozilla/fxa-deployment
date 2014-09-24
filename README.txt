
-------------------------------------------------------------------------------
NOTE: this repository is on longer in active use.
FxA deployment details are now part of the mozilla-services puppet-config repo.
-------------------------------------------------------------------------------


AWSBoxen Deployment Scripting for PiCL Loadtest Environment
===========================================================

This directory specifies how to deploy the PICL loadtest environment.
It's a templated CloudFormation stack with some extra details about how
to build AMIs. You will need "awsboxen" to interpret and act on these
instructions:

  https://github.com/mozilla/awsboxen

Something like this:

  export AWS_REGION=us-west-2
  awsboxen deploy -c ./LoadTestStack loadtest-lcip-org

when you're done with a deployment, you can save money by tearing it down
like this:

  awsboxen teardown loadtest-lcip-org

Right now all the build steps are scripted as shell scripts; they should be
ported over to puppet or chef or whatever is going to be used longer-term.

We have several different stacks that can be deployed:

  * DevStack:  supporting infrastructure for dev deployments; dev deployments
               of the projects themselves are handled separately.

  * LoadTestStack:  a more serious stack, including customized deployments of
                    each project, intended for running loadtests.

  * LoadsCluster:  a custom deployment of loads broker and agents, useful
                   for running distributed loadtests.

