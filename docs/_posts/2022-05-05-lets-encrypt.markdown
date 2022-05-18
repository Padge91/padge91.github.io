---
layout: post
title: 'Lets Encrypt'
date: '2022-05-17'
categories: general
---

Short one, LetsEncrypt can help you get free certs. Biggest downside, from a usability perspective, is the certs are only valid for 90 days. It has a number of ways to renew the certs, the easiest is from the command line. 

If the cert is on the same environment, you can run a command to renew the cert automatically. Something like below:

{% highlight shell %}

certbot-auto --renew

{% endhighlight %}

If the cert is instead in a load balancer or something similar then you'll need to run it to generate a key on a path, set the key to the path, and once it verifies upload the new certificate to the LB.