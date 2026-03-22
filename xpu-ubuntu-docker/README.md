# Ubuntu XPU Setup (docker)

**Have docker installed**

We need to pull the intel IPEX docker image. In this case we will use the IPEX pytorch/jupyter base image and build our own that includes additional pips. This way as we do more things or require additional packages we can simply update the Dockerfile and rebuild.

- intel-xpu.sh will setup the driver, add you to needed groups and create the custom container. It also puts a script in your ~/ folder that you can simply bash execute to run the container.
    - This is also where you can specify where on the host you would like to put your work folder which will mounted in the container to /jupyter
- Dockerfile is our build file for the customized IPEX image. This is where you should make edits to things like pip packages or if you wanted to change the default working folder etc...