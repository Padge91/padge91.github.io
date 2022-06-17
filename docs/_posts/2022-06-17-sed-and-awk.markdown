---
layout: post
title: 'Sed and AWK'
date: '2022-07-16'
categories: 'general'
---

I love Sed and Awk.

# Awk
It's a command line utility that I'm sure does a lot. But I've used it to pipe in values, and then use the values to format a string.

For example, the below line prints out the 5th column of my output, and we can use this to reformat the content.

{% highlight bash %}

stat | awk '{print "name: "$5}'

{% endhighlight %}

You can also do this in a loop for repeating lines automatically:

{% highlight bash %}

top -l 1 | awk '{print "col1: "$1}'

{% endhighlight %}

Which will automatically format the first column for all lines. Awesome!

# Sed
Sed let's you edit streams in unix systems, but I've pretty much exclusively used it for regex purposes.

{% highlight python %}

echo "hello      some random text" | sed 's/  */ /g'

{% endhighlight %}

The line above removes all whitespace, for example. Regex is another awesome thing I love.