---
layout: post
title: "Writing a Terraform provider"
description: "How to write a Terraform provider ?"
category: 
tags: [terraform go golang]
---

There is already a bunch of articles out there to help you create a Terraform provider. However after having done it myself I wanted to write about it. Mostly to keep track of how I did it but also
to try to give you a few hints to write your own. The idea here is to go through the entire process.

If you are reading this post it's likely that you already know which provider you want to implement. You also probably know that the API you will be using to write your plugin will need to implement the default [CRUD](https://en.wikipedia.org/wiki/Create,_read,_update_and_delete) functions. If not, you should take a look at the [external data source](https://www.terraform.io/docs/providers/external/data_source.html) resource.

Before starting, some assumptions:

* You use Terraform and are familiar with all the core concepts (in particular providers and resources).
* You know how to write in Go. No need to be an expert but you should be able to use any kind of SDK or API by reading the documentation.

# Writing a Terraform provider

Basically a provider is composed of two parts : the "provider" itself and some resources. If you are using Terraform to manage your AWS infrastructure, you have something like :

{% highlight golang %}
provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region     = "${var.aws_region}"
}


resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}
{% endhighlight %}

Here, the "aws" provider part is taking care of setting up your AWS Client and authenticate you to the AWS API. Then the "aws_vpc" resource will create an AWS VPC with the correct CIDR block for you, using this AWS Client.

If you take a look at the existing providers, you will notice that the structure is almost always something like :

* `provider.go` : Implement the "core" of the Provider.
* `config.go` : Configure the API client with the credentials from the Provider.
* `resource_<resource_name>.go` : Implement a specific resource handler with the CRUD functions.
* `import_<resource_name>.go` : Make possible to import existing resources. We won't expand on resources in this post.
* `data_source_<resource_name>.go` : Used to fetch data from outside of Terraform to be used in other resources. For example, you will be able to fetch the latest AWS AMI ID and use it for an AWS
  instance. Same as "import", we won't go further on this in this post.

Writing the "provider" is the easiest part so let's start here.

# The provider

To write your provider, you need to implement a [terraform.ResourceProvider](https://godoc.org/github.com/hashicorp/terraform/helper/schema#Provider). It might seem complicated at first but it's actually pretty easy.

This is how you start :

{% highlight golang %}
// File : provider.go
package main

import (
  "github.com/hashicorp/terraform/helper/schema"
  "github.com/hashicorp/terraform/terraform"
)

func Provider() terraform.ResourceProvider {
  return &schema.Provider{
    Schema: map[string]*schema.Schema{ },
    ResourcesMap: map[string]*schema.Resource{ },
    ConfigureFunc: configureProvider,
  }
}

func configureProvider(d *schema.ResourceData) (interface{}, error) {
  return nil, nil
}
{% endhighlight %}

Basically we have a function `Provider()` which is returning a `terraform.ResourceProvider` with all the required configuration to do the job :

* `Schema` is where you list the parameters of your provider. For instance, with AWS we have the access_key and the secret_key.
* `ResourceMap` is the list of the resources managed by your provider.
* `ConfigureFunc` is the function which, among other things, instantiates and configures the client you use to interact with the targeted API (AWS SDK for example).

Let's go ahead and write a unit test for this provider. Even is the Provider is not operational right now, I always try to write the test as soon as possible.

{% highlight golang %}
// File : provider_test.go
import (
  "os"
  "testing"

  "github.com/hashicorp/terraform/helper/schema"
  "github.com/hashicorp/terraform/terraform"
)

var testAccProvider *schema.Provider

func init() {
  testAccProvider = Provider().(*schema.Provider)
}

func TestProvider(t *testing.T) {
  if err := Provider().(*schema.Provider).InternalValidate(); err != nil {
    t.Fatalf("err: %s", err)
  }
}

func TestProvider_impl(t *testing.T) {
  var _ terraform.ResourceProvider = Provider()
}

func testAccPreCheck(t *testing.T) {
  // We will use this function later on to make sure our test environment is valid.
  // For example, you can make sure here that some environment variables are set.
}
{% endhighlight %}

The `init()` function set the `testAccProvider` variable with our provider and we'll just make sure here that Terraform is happy with our implementation.

{% highlight bash %}
$ go test -v
=== RUN   TestProvider
--- PASS: TestProvider (0.00s)
=== RUN   TestProvider_impl
--- PASS: TestProvider_impl (0.00s)
PASS
ok      github.com/Pryz/terraform-provider-fake 0.005s
{% endhighlight %}

Next you need to configure the client for the API you want to interact with. Let's say we are writing a provider for a really simple API. This API requires a user and a token for authentication.

This will be in the [Schema](https://godoc.org/github.com/hashicorp/terraform/helper/schema#Schema) of your provider :

{% highlight golang %}
// File : provider.go
Schema: map[string]*schema.Schema{
  "user": &schema.Schema{
    Type: schema.TypeString,
    Required: true,
    DefaultFunc: schema.EnvDefaultFunc("API_USER", nil),
    Description: "API User",
  },
  "token": &schema.Schema{
    Type: schema.TypeString,
    Required: true,
    DefaultFunc: schema.EnvDefaultFunc("API_TOKEN", nil),
    Description: "API Token",
  },
}
{% endhighlight %}

Those two variables are strings so we use the type `schema.TypeString`. Also we make sure that they are set by using `Required: true`.

Get yourself familiar with `schema.Schema`, you will also use it for the Resources. For instance, check the different types supported here :
[schema#Schema](https://godoc.org/github.com/hashicorp/terraform/helper/schema#Schema).

You can now use those parameters to configure the client within `configureProvider`. This function should return a configured API client. Hence the usage of `interface{}`.

{% highlight golang %}
func configureProvider(d *schema.ResourceData) (interface{}, error) {
  user := d.Get("user").(string)
  token := d.Get("token").(string)

  return SimpleFakeApi.New(user, token)
}
{% endhighlight %}

At this point you have a working provider ! Well, you don't have any resource so even if you use it in a Terraform manifest, you will see nothing happening :)

# The first resource

This is where the fun begins. As we did above with the `Provider`, let's define the skeleton of your first resource :


{% highlight golang %}
// File : resource_fake_object.go
package main

import (
  "github.com/hashicorp/terraform/helper/schema"
)

func resourceFakeObject() *schema.Resource {
  return &schema.Resource{
    Create: resourceFakeObjectCreate,
    Read:   resourceFakeObjectRead,
    Update: resourceFakeObjectUpdate,
    Delete: resourceFakeObjectDelete,
    Exists: resourceFakeObjectExists,

    Schema: map[string]*schema.Schema{ },
  }
}

func resourceFakeObjectExists(d *schema.ResourceData, meta interface{}) (b bool, e error) {
  return true, nil
}

func resourceFakeObjectCreate(d *schema.ResourceData, meta interface{}) error {
  return nil
}

func resourceFakeObjectRead(d *schema.ResourceData, meta interface{}) error {
  return nil
}

func resourceFakeObjectDelete(d *schema.ResourceData, meta interface{}) error {
  return nil
}
{% endhighlight %}

First things we have here is the definition of the CRUD functions :

* `Create` will simply create a new instance of your resource. The is also where you will have to set the ID (has to be an Int) of your resource. If the API you are using doesn't provide an ID, you can
  always use a random Int.
* `Read` will fetch the data of a resource.
* `Update` is optional if your Resource doesn't support update. For example, I'm not using update in the [Terraform LDAP Provider](https://github.com/Pryz/terraform-provider-ldap). I just destroy and
  recreate the resource everytime there is a change.
* `Exists` is called before `Read` and obviously makes sure the resource exists.

Then, as you can see, we have the `Schema` again ! Nothing really new here compare to the provider except if you have to use more complex attributes than string.

For instance, if you have something like a list of tags :

{% highlight golang %}
resource "fake_object" {
  ...
  tags = ["spaceship", "beer"]
}
{% endhighlight %}

You will want to use the `schema.TypeList` type. The declaration will be :


{% highlight golang %}
Schema: map[string]*schema.Schema{
  ...
  "tags": &schema.Schema{
    Type:     schema.TypeList,
    Required: true,
    ForceNew: true,
      Elem:   &schema.Schema{Type: schema.TypeString},
    },
}
{% endhighlight %}

To retrieve those `tags` within the CRUD function, you can do something like :

{% highlight golang %}
objectTags := []string{}
for _, tag := range d.Get("tags").([]interface{}) {
  objectTags = append(objectTags, tag.(string))
}
{% endhighlight %}

Things can quickly get tricky here. For example, if you need to implement attributes which can be specified multiple times like in the `aws_security_group` resource :

{% highlight bash %}
resource "aws_security_group" "web" {
  name = "web-http-https"
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
{% endhighlight %}

You will use the type `schema.TypeSet` or `schema.TypeMap` and use another level of `schema.Schema` to define all the parameters of the `ingress` and `egress` rules. See [resource_aws_security_group.go#L83](https://github.com/hashicorp/terraform/blob/master/builtin/providers/aws/resource_aws_security_group.go#L83).

In the case of the `schema.TypeSet`, you will have the use the function `Set()` in order to retrieve all the values. For instance :

{% highlight golang %}
ingressRules := d.Get("ingress").(*schema.Set).List()
{% endhighlight %}

# Build it and try it

Throughout this post we have been using the package `main`. We did this mostly because our plugin is `standalone`. If you want to Pull Request your plugin within the Terraform Github, you will
have to change `main` by the name of your plugin.

Since our plugin is standalone, we need a main :

{% highlight golang %}
package main

import (
  "github.com/hashicorp/terraform/plugin"
)

func main() {
  plugin.Serve(&plugin.ServeOpts{
    ProviderFunc: Provider,
  })
}
{% endhighlight %}

Build it with a name that Terraform can understand :

{% highlight bash %}
go build -o terraform-provider-fake
{% endhighlight %}

Tell Terraform where to find your plugin :

{% highlight bash %}
cat >> ~/.terraformrc <<EOF
providers {
  ldap = "${GOPATH}/bin/terraform-provider-fake"
}
EOF
{% endhighlight %}

Write a quick manifest : `main.tf`

{% highlight bash %}
provider "blah" {
  login = "foo"
  password = "bar"
}

resource "blah_service" {
  name = "foo"
  content = "bar"
}
{% endhighlight %}

Plan and apply !

```
terraform plan
terraform apply
```

# Final words

This post is a quick walkthrough to give you a starting point to write Terraform Providers. There is much more details to talk about like `Imports` and `Data Sources`, or also `Partial States`.

Also I didn't talk about how to test the Resources. There are really damn good examples out there. Take for instance this one : [resource_datadog_monitor_test.go](https://github.com/hashicorp/terraform/blob/master/builtin/providers/datadog/resource_datadog_monitor_test.go).

It's always a good idea to look at the existing providers. Some are pretty complex like the [AWS](https://github.com/hashicorp/terraform/blob/master/builtin/providers/aws) provider. Others are easier to
understand, for instance the [Datadog](https://github.com/hashicorp/terraform/tree/master/builtin/providers/datadog) one.
