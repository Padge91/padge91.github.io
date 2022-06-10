---
layout: post
title: 'EC2 Lifecycle Hooks'
date: '2022-06-10'
categories: 'general'
---

I had a problem. When our EC2 Autoscaler would turn on instances, EC2 would think the instances are ready before they were actually ready. This would result in 5XX errors from the service while traffic was distributed between the two systems.

I initially thought it was because of the warmup delay setting, or the heath check grace period. Not so. EC2 Autoscaling apparently puts instances into service under an autoscaler DESPITE the health check (the health check only checks if instance needs ot be replaced, not if it's ready to be put into the group). The Warmup Delay is only to prevent multiple instances from being started from the same autoscaling event. E.G. you need to scale up because an instance went down, after 5 minutes the new instance may not be ready, but we don't want EC2 to add an EXTRA instance to the group.

Well, what if my instance takes 10 minutes to start up correctly? How do I get EC2 Autoscaling to not add it to the target group until it's ready? You're looking for Lifecycle Hooks.

# Autoscaling Lifecycle Hooks
The configurations for this aren't all that bad, you just need a few things.

## Autoscaling Group Configuration
You just need to go to the **Instance Management -> Lifecycle Hooks** tab in AWS. Here, create a lifecycle hook for the "instance launch" event, give it a heartbeat timeout (this says if we don't get the event in this time, the instance start failed), and set the default result to **ABANDON**.

A terraform config for this looks like below:

{% highlight bash %}

resource "aws_autoscaling_lifecycle_hook" "example_hook" {
  name                   = "example-ec2-lifecycle-complete"
  autoscaling_group_name = aws_autoscaling_group.example.name
  default_result         = "ABANDON"
  heartbeat_timeout      = 900
  lifecycle_transition   = "autoscaling:EC2_INSTANCE_LAUNCHING"
}

{% endhighlight %}

## IAM Policy

You need to have your EC2 instances be allowed to submit these hooks, and to do that we need a policy for it. Here is an example policy:

{% highlight bash %}

{
    "Statement": [
        {
            "Action": [
                "autoscaling:CompleteLifecycleAction"
            ],
            "Effect": "Allow",
            "Resource": [
                "arn:aws:autoscaling:us-east-1:example:autoScalingGroupName/example"
            ]
        }
    ],
    "Version": "2012-10-17"
}

{% endhighlight %}

This policy then needs to be added to an instance role which will be applied to the instance at startup.

## Call the Lifecycle Hook

This example is for Ubuntu, but you need to have the awscli package installed. The command is as follows:

{% highlight bash %}

INSTANCE_ID="`wget -q -O - http://instance-data/latest/meta-data/instance-id`"
REGION="`wget -q -O - http://instance-data/latest/meta-data/placement/region`"
AUTOSCALER_NAME="`wget -q -O - http://instance-data/latest/meta-data/tags/instance/aws:autoscaling:groupName`"
HOOK_NAME="example-ec2-lifecycle-complete"

/usr/bin/aws autoscaling complete-lifecycle-action --lifecycle-action-result CONTINUE --instance-id $INSTANCE_ID --lifecycle-hook-name $HOOK_NAME --auto-scaling-group-name $AUTOSCALER_NAME --region $REGION || \
/usr/bin/aws autoscaling complete-lifecycle-action --lifecycle-action-result ABANDON --instance-id $INSTANCE_ID --lifecycle-hook-name $HOOK_NAME --auto-scaling-group-name $AUTOSCALER_NAME --region $REGION

{% endhighlight %}

You can get most of the variables pretty easily from the instance-data, the only weird one is the AUTOSCALER_NAME, where you need extra permissions to get the tag for the autoscaler name. This is a metadata option. It's a setting on the launch template. In terraform you can configure it like so:

{% highlight bash %}

metadata_options {
    instance_metadata_tags = "enabled"
}

{% endhighlight %}
