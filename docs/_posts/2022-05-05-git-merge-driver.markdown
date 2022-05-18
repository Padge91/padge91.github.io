---
layout: post
title: 'Git Custom Merge Driver'
date: '2022-05-17'
categories: general
---

If Git doesn't recognize one of your file types as merge-able, but you have some other way to do the merge (a manual process or a cmd script which can do it) then you can write a custom merge driver under the covers. This way Git will call the custom merge driver to do the merge.

I came across this when I was trying to improve an existing script someone else had written. It basically wrapped Git commands in custom commands and args, and called a cmd line merge tool under the covers to perform a merge and clobber the working files. It as a brute force approach to start, but the custom commands made it pretty inconvenient. The commands, iirc, were fashioned in a Gitflow style, so you couldn't even do any other workflow. Pretty big drawbacks when the Git community has hundreds of different workflows.

Anyways...

# .gitconfig 

{% highlight shell %}

[merge "example"]
	name = Example merge driver.
	driver = command merge "%O" "%A" "%B"
[diff "example"]
	name = Example diff driver.
	command = command diff
[difftool "example"]
	name = Example diff driver.
	cmd = command diff

{% endhighlight %}

The **merge** block tells Git to use the provided command when the files meet the "example" type criteria (in the .gitattributes file below). In this example, we're calling the command **command** with an arg **merge** and pass in the Original, Modified, Other as %O, %A, and %B respectively.

The **diff** and **difftool** blocks tell Git what to do when calculating a diff between two files. The diff passes in a number of args by default, so best to look at docs to see specific args.

The **difftool** block is needed to work specifically with tools like SourceTree and such. On the command line, **diff** is all that's needed.

# .gitattributes

{% highlight shell %}

*.nick merge=example
*.nick diff=example

{% endhighlight %}

This file tells Git what commands to use when files with the xtension **.nick** are encountered. The names of the merge and diff commands are associated to the blocks in the **.gitconfig** file.

# Installation

Append the contents of the **.gitattributes** example to the.gitattributes file in the repository. This makes the repository, no matter where it is, try to use the custom merge driver.

Similarly, append the contents of the **.gitconfig** file to your global .gitconfig file, NOT the one in the repository. Then it should work for all repositories on the system. T find your .gitconfig file location, run the following:

{% highlight shell %}

git config --global --list --show-origin

{% endhighlight %}