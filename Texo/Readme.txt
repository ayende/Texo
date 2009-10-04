Texo - construct
=================

*	This is meant to be a simple to use/configure build server that integrate with github's notification
	system. This means that it doesn't have to keep pooling all the time, which is nice.
*	No attempt at UI, only output is via email notifications.
*	No attempt was made to make this in any way robust.

Configuration
================
There are two items of configuration.
In the settings.config file you specify the SMTP settings for notification and the build settings for each project.

Permissions
===============
The build process is going to run as the same user as the IIS site, either fix the permissions or change the IIS site username