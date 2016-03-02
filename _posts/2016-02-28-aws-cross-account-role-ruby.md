---
layout: post
title: "Use AWS cross account Role in Ruby"
description: ""
category:
tags: ['aws', 'ruby', 'sensu']
---

I got recently the need to access resources from mulitple AWS accounts. For example, let's say that you have a monitoring service (i.e Sensu) and you want to monitor AWS resources (EC2 instances, RDS databases, ...) which are in mulitple AWS accounts (accounts per services or per environment as dev and production).

You basicaly have two solutions here. The first one is to create an user for your monitoring service in each account and play with what AWS calls "[SharedCredentials](http://docs.aws.amazon.com/sdkforruby/api/Aws/SharedCredentials.html)". You will put all your credentials in a file like `~/.aws/credentials` and define which profile you want to use in your script or try to look into all your accounts to find the resource you want. This solution will work but it means that you will have to maintain multiple users and so mulitple set of AWS credentials.

Having to maintain mulitple set of credentials for only one script can be painful. To fix that, you can use the second solution : IAM roles.

As define in this walkthrough from the AWS documentation : [Delegating Access Across AWS Accounts For Accounts You Own Using IAM Roles](http://docs.aws.amazon.com/IAM/latest/UserGuide/walkthru_cross-account-with-roles.html
http://docs.aws.amazon.com/IAM/latest/UserGuide/walkthru_cross-account-with-roles.html), create a cross account IAM Role is pretty easy.

Once you have your role here is an example to use it with the Ruby [AWS SDK](http://docs.aws.amazon.com/sdkforruby/api/index.html) :

{% highlight ruby %}
require 'aws-sdk'

# The credentials of the user in your 'main' AWS account
access_key_id = 'I_AM_AN_ACCESS_KEY_ID'
secret_access_key = 'I_AM_A_SECRET_ACCESS_KEY'

# Define the AWS region you want to use
region_name = 'us-west-2'

# A hash defining all your AWS accounts wit the cross account IAM roles
#
# The ARN addresses follow the format : 'arn::aws::iam::<ACCOUNT_ID>:role/<ROLE_NAME>'
#
accounts = {
 :dev     => { :role_arn => 'arn:aws:iam::123456:role/cross-account-ec2-ro' },
 :preprod => { :role_arn => 'arn:aws:iam::098765:role/cross-account-ec2-ro' },
}

begin
  # Here we start by creating an AWS Security Token Service client
  # See : [AWS Security Token Service](http://docs.aws.amazon.com/STS/latest/APIReference/Welcome.htm l)
  # Basicaly STS allow you to create a token to get access to the AWS API
  #
  sts = Aws::STS::Client.new(
    access_key_id: access_key_id,
    secret_access_key: secret_access_key,
    region: region_name
  )

  # With the STS client we can then instantiate the credentials with the Role we want to use
  role_credentials = Aws::AssumeRoleCredentials.new(
    client: sts,
    role_arn: accounts[:dev][:role_arn],
    role_session_name: 'temp'
  )
rescue StandardError => e
  puts "Error creating Role credentials: #{e.message}"
  exit -1
end

# Then created the EC2 client and play with it
ec2 = Aws::EC2::Client.new(credentials: role_credentials)
puts ec2.describe_instances()
{% endhighlight %}

You can see a real life example here : [https://github.com/Pryz/sensu/blob/master/awsdecomm.rb](https://github.com/Pryz/sensu/blob/master/awsdecomm.rb), a Sensu handler to clean out old Sensu clients from AWS instance which have been decommissioned.
