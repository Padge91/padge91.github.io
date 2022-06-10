---
layout: post
title: 'Ubuntu Services'
date: '2022-06-10'
categories: general
---

Adding a ubuntu service isn't too difficult. You first need a .service file, like the one below.

example@.service (the @ means you can run several of these workers at a time)
{% highlight bash %}
[Unit]
Description=Multiple services.
After=network.target

[Service]
User=ubuntu
Group=group
WorkingDirectory=/home/ubuntu/example
Environment="PATH=/home/ubuntu/.local/share/virtualenvs/example/bin"
ExecStart=/home/ubuntu/.local/share/virtualenvs/example/bin/python /home/ubuntu/dexample/run.py

[Install]
WantedBy=multi-user.target

{% endhighlight %}

This service file can then be installed by adding it to /etc/systemd/system. Then you can start it like any other service.