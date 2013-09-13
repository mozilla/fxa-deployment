
AWSBoxen Deployment Scripting for PiCL Loadtest Environment
===========================================================

This directory specifies how to deploy the PICL loadtest environment.
It's a templated CloudFormation stack with some extra details about how
to build AMIs. You will need "awsboxen" to interpret and act on these
instructions:

  https://github.com/mozilla/awsboxen

Something like this:

  awsboxen deploy -c ./LoadTestStack loadtest-lcip-org

Right now all the build steps are scripted as shell scripts; they should be
ported over to puppet or chef or whatever is going to be used longer-term.

We have several different stacks that can be deployed:

  * DevStack:  supporting infrastructure for dev deployments; dev deployments
               of the projects themselves are handled separately.

  * LoadTestStack:  a more serious stack, including customized deployments of
                    each project, intended for running loadtests.
