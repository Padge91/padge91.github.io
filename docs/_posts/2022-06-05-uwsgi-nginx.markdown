---
layout: post
title: 'uWSGI with Nginx'
date: '2022-06-05'
categories: 'general'
---

The purpose of this post is to review how to configure uwsgi with Nginx and python. It was kind of a pain to get working intially but I believe this is the process.

# Python
Just install the uwsgi package, and set up a flask app on a variable.

# INI file
This file will tell uwsgi how to run. You need to pass it ot the uwsgi executable so put ti somewhere accessible. The ini file looks like:

{% highlight bash %}
[uwsgi]
\# this will call the run.py python file and will load the variable 'app' as the app
module = run:app

\# this will log the output to the below file
logto = /var/log/uwsgi/%n.log

\# how many processes we want to start
master = true
processes = 30
buffer-size = 32768

\# this is important, where we want the uwsgi socket to be plaed
socket = /tmp/uwsgi.sock
chmod-socket = 660
vacuum = true
enable-threads = true

\# here we can set some more logging params
disable-logging = true
log-4xx = true
log-5xx = true

max-requests = 2000
die-on-term = true

\# I've found I need this to be true or run into other issues
lazy-apps = true

\# this is kind of important. If the below file is touched then it restarts the workers
\# convenient when doing a restart of the works, you can just add a touch command for this file
\# will then dynamically restart the workers
touch-chain-reload = .reloadFile

\# some internal stats for reporting
stats = 127.0.0.1:1717
stats-http = true

{% endhighlight %}

# Nginx Conf file

This file is a config file for nginx on how to talk to the uwsgi process.

{% highlight bash %}

server {
        \# gzip for best practices
        gzip on;
        gzip_min_length 2048;
        gzip_types text/plain text/html application/json text/javascript application/javascript text/css image/png image/jpeg image/svg+xml image/gif;
        gzip_disable "MSIE [1-6]\.";

        \# allow etag headers 
        etag on;

        \# the important bit to tie to the uwsgi socket
        location / {
                include uwsgi_params;
                uwsgi_pass unix:/tmp/uwsgi.sock;
        }
}

{% endhighlight %}

# Service

Service file to tie call the service in a convenient manner.

{% highlight bash %}
[Unit]
Description=uWSGI instance.
After=network.target

\# give a path to the working directory, the virtual environment, path to the python uwsgi executable in the environment and pass along the INI file as an argument
[Service]
User=ubuntu
Group=www-data
WorkingDirectory=/home/ubuntu/web-app
Environment="PATH=/home/ubuntu/.local/share/virtualenvs/web-app-JJSHW/bin"
ExecStart=/home/ubuntu/.local/share/virtualenvs/web-app-JJSHW/bin/uwsgi --ini /etc/nginx/example.ini --lazy-apps

[Install]
WantedBy=multi-user.target
{% endhighlight %}