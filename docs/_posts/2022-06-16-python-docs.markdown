---
layout: post
title: 'Python Docs'
date: '2022-06-16'
categories: 'general'
---


# PyDocs
There's a lot of ways we could document our code, I'm partial to the google format.

{% highlight python %}

def example(arg1, arg2, arg3=0):
    """Example description
    Args:
        arg1 (str): First argument.
        arg2 (str): Second argument.
        arg3 (int, optional): Third argument.
    Returns:
        list of dict: List of projects.
    Raises:
        Exception: If request fails or error occurs.
    """

{% endhighlight %}

Let's you specify types for arguments, return value, exceptions it can raise, and a description. PyCharm will also pick up these for hints which helps a lot.

# Sphinx

First you need a conf file in the src directory. We can also run an autogenerate command to handle a lot of the base formats.

{% highlight python %}

\# Configuration file for the Sphinx documentation builder.
\#
\# This file only contains a selection of the most common options. For a full
\# list see the documentation:
\# https://www.sphinx-doc.org/en/master/usage/configuration.html\\

\# -- Path setup --------------------------------------------------------------

\# If extensions (or modules to document with autodoc) are in another directory,
\# add these directories to sys.path here. If the directory is relative to the
\# documentation root, use os.path.abspath to make it absolute, like shown here.
\#
import os
import sys
sys.path.insert(0, os.path.abspath('./'))


\# -- Project information -----------------------------------------------------

project = 'boldcast-webapp'
copyright = '2021, Rocketscreens'
author = 'boldcast'


\# -- General configuration ---------------------------------------------------

\# Add any Sphinx extension module names here, as strings. They can be
\# extensions coming with Sphinx (named 'sphinx.ext.*') or your custom
\# ones.
extensions = [
    'sphinx.ext.autodoc',
    'sphinx.ext.todo',
    'sphinx.ext.napoleon',
]

\# Add any paths that contain templates here, relative to this directory.
templates_path = ['_templates']

\# List of patterns, relative to source directory, that match files and
\# directories to ignore when looking for source files.
\# This pattern also affects html_static_path and html_extra_path.
exclude_patterns = []


\# -- Options for HTML output -------------------------------------------------

\# The theme to use for HTML and HTML Help pages.  See the documentation for
\# a list of builtin themes.
\#
\# html_theme = 'alabaster'
html_theme = 'sphinx_rtd_theme'

\# Add any paths that contain custom static files (such as style sheets) here,
\# relative to this directory. They are copied after the builtin static files,
\# so a file named "default.css" will overwrite the builtin "default.css".
html_static_path = []

{% endhighlight %}

# Build
Build command is easy.

{% highlight bash %}

pipenv run sphinx-build -a -E -b html docs/src docs/out

{% endhighlight %}

docs/src is where the source file is, docs/out is where the HTML will be delivered.