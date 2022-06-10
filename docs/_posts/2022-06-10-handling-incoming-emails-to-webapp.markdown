---
layout: post
title: 'Handling Incoming Emails to Webapp'
date: '2022-06-10'
categories: 'general'
---

Did you know your webapp can receive emails?? Well, kind of. You need an email provider, but a lot of these can be confingured to forward emails to your app endpoints.

I'm using Mailgun, it's pretty simple to setup.

# Mailgun setup
Just set up some routes for a configured domain. You can set a rule to the following:
{% highlight bash %}

match_recipient(".*@mail.example.com")
forward("https://example.com/api/v1/webhooks/email/")
stop()

{% endhighlight %}

Then an email send to any address to @mail.example.com will be forward to your system. you don't need to do all emails, but if you let users setup their own, or you provide them, then this may be the best.

# Webhook Handling

Like other webhooks, you need to first verify the signature of the request. It's not so bad:

{% highlight python %}

timestamp_and_token = (str(request.form["timestamp"]) + str(request.form["token"])).encode("utf-8")
our_signature = hmac.new(mailgun_api_key.encode("utf-8"), timestamp_and_token, digestmod=hashlib.sha256).hexdigest()
if request.form["signature"] != our_signature:
    raise Exception("Invalid Mailgun webhook signature.")

{% endhighlight %}

The body is on the "body-html" or "body-plain" objects.

# Attachments

These come through too!

{% highlight python %}

\# iterate through files
for key in request.files.keys():
    file = request.files[key]

    \# file.filename is the filename
    \# file.content_type is the mimetype
    \# file.tell() gets you the file size

{% endhighlight %}