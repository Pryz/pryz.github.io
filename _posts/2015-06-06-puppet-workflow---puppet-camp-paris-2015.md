---
layout: post
title: "Puppet Workflow - Puppet Camp Paris 2015"
description: ""
category:
tags: [puppet, automation, puppet camp, jenkins, r10k, gerrit]
---

Following the talk "Improving Operations Efficiency with Puppet" we prepared with [Nicolas Brousse](https://nicolas.brousse.info) for the Puppet Camp Paris 2015, I wanted to provide some details.

<center><iframe src="//www.slideshare.net/slideshow/embed_code/key/xJByZu61bfsTs5" width="425" height="355" frameborder="0" marginwidth="0" marginheight="0" scrolling="no" style="border:1px solid #CCC; border-width:1px; margin-bottom:5px; max-width: 100%;" allowfullscreen> </iframe></center> 

I will write two posts on this topic. The first one will give some details on the tools we are using. The second post will describe what we are currently implementing to have a better code testing and improve once again our productivity and efficiency to manage our infrastructure.

## Philosophy behind this Puppet workflow

At TubeMogul, we manage a relative complex infrastructure. We have a philosophy of "moving fast" which involve implementing a large numbers of technologies.
That's the main reason why after multiple years using Puppet we have more than 2000 Puppet agents running every hour, 225 different kind of nodes and more 120 Puppet modules.

Manage this kind of platform can be tricky when you have only few Ops to take care of it. Right now our team is represented by 13 Ops (9 SREs and 4 SA) working on two differents timezone. That's why we want to be able to change and deploy configuration as fast as possible in the most efficient possible way.

Be more developers than ops :)

## Automation and code review are the keys

We love Gerrit. We deeply think that Gerrit is one of the best Code Review solution currently available. Why ?

* The Stream-event service give you a powerful way to plug your Git activity with your CI solution,
* Review commit by commit can be really usefull to master infrastructure configuration and force atomic changes,
* The UI is great. Ok it's not looking that great but it's powerfull and give you all the keys to manage your changes

If you are interested about Gerrit, you should take a look at the [Gerrit Trigger](https://wiki.jenkins-ci.org/display/JENKINS/Gerrit+Trigger) plugin for Jenkins.
With this plugin, Jenkins will just read all the events through the [Gerrit Stream event](https://gerrit-documentation.googlecode.com/svn/Documentation/2.7/cmd-stream-events.html) and will be able to trigger a build for each change.

In order to programatically create our Jenkins jobs, we use the [Jenkins Job DSL plugin](https://github.com/jenkinsci/job-dsl-plugin). You will have to write some Groovy lines but you will basically able to reproduce all the jobs you want. See the [wiki](https://github.com/jenkinsci/job-dsl-plugin/wiki/Job-DSL-Commands) for more information.

If a plugin is not handle by the DSL you can write a patch or simply use the [configure block](https://github.com/jenkinsci/job-dsl-plugin/wiki/The-Configure-Block).
Example with the [HipChat notifier](https://wiki.jenkins-ci.org/display/JENKINS/HipChat+Plugin) plugin : 

{% highlight groovy %}
configure { project ->
  project / 'publishers' << 'org.jenkinsci.plugins.HipChatNotifier' {
    room 'Room 42'
    jobToken 'YOUR_TOKEN'
    successMessageFormat '${JOB_NAME} #${BUILD_NUMBER} (${BUILD_RESULT}) ${BUILD_URL}'
    failedMessageFormat '${JOB_NAME} #${BUILD_NUMBER} (${BUILD_RESULT}) ${BUILD_URL}'
    postSuccess 'true'
    postFailed 'true'
    notifyFailed 'true'
  }
}
{% endhighlight %}

## Keep Puppet efficient and simple

The biggest challenge you have when you implement Puppet within a complex infrastructure is to keep it simple and efficient. When you start working with Puppet, you write some manifests and then some modules to factorize your code. And then you discover Hiera and start to store all your variables at the same place. You think you have the best implementation of Puppet ever and keep going. Few years later you have more than 200 Puppet manifests and more than 100 modules. Having that many modules is not the problem but maintaining that many manifests is a pain. You probably have code duplication everywhere and overly use code inheritance.

Because you are using manifests (\*.pp files) you are probably relying on hostnames. Which is a design issue for all the cloud infrastructures and a big lack of flexibilty.

We got these issues and decided to fix them with two frameworks : Role and Profiles to organize better our codebase, Nodeless to stop relying on hostname.

### Role and Profiles

I will not explain once again this framework. Enough people already did it. I will just guide you to this really good talk by Craig Dunn : [https://puppetlabs.com/presentations/designing-puppet-rolesprofiles-pattern](https://puppetlabs.com/presentations/designing-puppet-rolesprofiles-pattern).

### Nodeless approach for an AWS EC2 infrastrucutre

The Nodeless approach is really smart. The main idea is to guide your Puppet code with facts. This way you can decide which code to apply depending of the definition of the server. If you pair this approach with something as flexible as the AWS EC2 tags, you have an easy win.

Let me give you a really simple example. We want to apply a specific role by just defining a tag "role" during the provisioning of an EC2 instance. For that you just need the following ```site.pp``` :

{% highlight ruby %}
node default {
  if $::ec2_tag_tm_role {
    notify {"Using role : ${ec2_tag_role}": }
    include "role::${::ec2_tag_role}"
  } else {
    notify {"No role found. If a node manifest has been defined Puppet will use it.": }
  }
}
{% endhighlight %}

Now if you create an instance with the tag ```role``` or just change this tag of a specific instance like that : 

{% highlight bash %}
aws ec2 create-tags --resources id-1234567 --tags Key=role,Value=webserver
{% endhighlight %}

Puppet will apply the role ```role::webserver``` during the next run. You can easily create a fact per tag with few lines of ruby using the [AWS Ruby SDK](https://github.com/aws/aws-sdk-ruby).

Thanks to this approach you are not relying on hostname anymore and your code is much more flexible.

## Open source our modules

We recently decided to release some of our modules to the Puppet Forge. We are trying to use more and more the Puppet community modules and we think that we have to participate in return. So far we have released only one module. Others will come soon. These modules are compatible with Puppet 2.7.x and 3.7.x. We are not using Puppet 4.x yet.

We use the really good skeleton from Gareth Rushgrove (garethr) available on Github : [https://github.com/garethr/puppet-module-skeleton](https://github.com/garethr/puppet-module-skeleton). This skeleton gives you a really good scaffolding to start writing a new module.

You can follow our releases here : [https://forge.puppetlabs.com/TubeMogul](https://forge.puppetlabs.com/TubeMogul).

## Next steps

Our current Puppet workflow is not perfect but it's fast, simple and reliable. We improved a lot our productivity by providing to our team a really simple way to push infrastructure changes : write code, git push, wait few seconds and your code is in Production.
The next big step for us will be to write more tests. We are thinking about using something like [Beaker](https://github.com/puppetlabs/beaker) but the challenge here will be to keep the same speed to deploy new changes.
