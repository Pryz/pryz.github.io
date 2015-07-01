---
layout: post
title: "Puppet dashboard with Logstash"
description: ""
category: 
tags: []
---

Puppet reports are really useful to see what's happening on your Puppetized infrastructure. You have many solutions to implement reports. One of the most popular is currently the PuppetDB. However if
you want to keep your configuration management platform as simple as possible and if you don't use exported resources, for example, this is probably not the best solution.

## Send Puppet Reports to Logstash

Another solution is to leverage Logstash. If you already have a Logstash platform, sending Puppet Reports to Logstash is really straigthforward. You just need to use a module which going to
implement Puppet::Reports.register_report. This resource will have to parse a Puppet report and send JSON to Logstash.

Folks from Elastic already did all the work for us :) See : https://github.com/elastic/puppet-logstash-reporter. Just follow the doc to implement it. Basically you will need to use the module on your
master, setup logstash.yaml and change your puppet.conf.

## Kibana dashboard example

This is an example of what you can have with these reports in Logstash :
![Kibana 3 Puppet Reports](/assets/screenshot.jpg)

You can find the source of this dashboard here : [https://gist.github.com/Pryz/aa6f78fa4c09e5356208](https://gist.github.com/Pryz/aa6f78fa4c09e5356208). This json configuration is for Kibana 3. I need to think about doing to same for Kibana 4 :)
For this dashboard I'm using a fork of the puppet-logstash-reporter module to have a better management of Puppet 2.x. See : [https://github.com/Pryz/puppet-logstash-reporter](https://github.com/Pryz/puppet-logstash-reporter).

We can probably improve this dashboard. Let me know if you have any idea :)

## Resources

* Documentation : [Puppet Reporting](https://docs.puppetlabs.com/guides/reporting.html)
* Puppet Module : [puppet-logstash-reporter](https://github.com/elastic/puppet-logstash-reporter)
* Kibana dashboard : [puppet_reports.json](https://gist.github.com/Pryz/aa6f78fa4c09e5356208)
