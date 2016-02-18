## Project Hanlon-Microkernel (v3.0.1)

This is part of [Project Hanlon][hanlon] - the Microkernel is the in-memory
Linux instance used to discover the hardware details and initiate
provisioning operations.

You can find more information about Hanlon in general, as well as ways to get
help, over at the [Hanlon project on GitHub][hanlon].  That includes the
contributing guide, and the official list of committers to the project.

[hanlon]: https://github.com/csc/hanlon


## Project Description

This project contains the Ruby scripts/classes that are used to control the Hanlon Microkernel (and that interact with the Hanlon server). There are two primary services that are included in this project that are started up during the Microkernel boot process. Those services include:

1. The **Hanlon Microkernel Controller**, which is actually contained in the hnl_mk_control_server.rb file (which is, in turn, started up and controlled using the "Ruby Daemons" interface defined in the hnl_mk_controller.rb file)
1. The **Hanlon Microkernel Web Server**, which can be found in the hnl_mk_web_server.rb file and which is used (by the Hanlon Microkernel Controller) to save configuration changes from the Hanlon Server to the 'local filesystem' (remember, everything is in memory). During this process of saving the configuration changes, the Microkernel Web Server will actually restart the Hanlon Microkernel instance (in order to force it to pick up the newly saved Microkernel configuration).

In addition, this project also includes a number of additional ruby files and configuration files that are used by these services, and the 'hnl_mk_init.rb' script itself (which is used to start the appropriate Ruby-based services during the Microkernel boot process).

It should be noted that this project also includes a Dockerfile that is used to build a new instance of the Microkernel container. Instructions for building your own (custom) Microkernel container can be found in the project's Wiki.
