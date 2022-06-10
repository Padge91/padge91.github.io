---
layout: post
title: 'Lambda Functions with NodeJS and Python'
date: '2022-06-10'
categories: general
---

# NodeJS

## Build command
Pretty simple build command:

{% highlight bash %}

\# build this stuff but exclude things we don't need (since theres an upload limit)
zip -x "assets/*" -x "dist/*" -x secrets.js -x secrets.json -x "*.git*" -x ".git/*" -x "build/*" -x "tmp/*" -x ".idea/*" -r example.zip . 

{% endhighlight %}


## Handler

You need to have a handler function, by default at index.handler. You can even do an old callback method or do a promise(async/await) method. Whatever way you do, you have to keep it consistent:

{% highlight javascript %}

exports.handler = function(event, context, callback) {
    // do processing
    callback();
}

{% endhighlight %}

# Python

## Build Command
This build command is more difficult since it needs the dependencies, and dependency management in Python is kinda dumb. I think all this does is create a requirements.txt which it then uses in the build.

{% highlight bash %}

mkdir build
pipenv lock -r | sed 's/-e //g' | pipenv run pip install --upgrade -r /dev/stdin --target build
cd build && zip -r ../build.zip . && cd ..
zip -g build.zip lambda_function.py
rm -rf build

{% endhighlight %}

## Handler

{% highlight python %}

def lambda_hanlder(event, context):
    return "{\"success\":true}"

{% endhighlight %}
