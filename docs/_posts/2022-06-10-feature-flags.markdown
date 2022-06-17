---
layout: post
title: 'Feature Flags'
date: '2022-06-10'
categories: general
---

Feature flags are an easy way to enable/disable features for certain accounts, or allow administrators of accounts to upgrade/migrate to new features. It can be called when a customer upgrades or downgrades, or a sales engineer can do these manually behind the scenes. Here's the architecture I found out works well:

# Classes

The FeatureFlag class is a container for a named feature, and the key we want to save it in our eventual JSON. We can also provide a description for customer facing flags and a default value for when new accounts are created.

{% highlight python %}
class FeatureFlag:
	key = ""
	name = ""
	description = ""
	default = False

	def __init__(self, key, name, description, default):
		self.key = key
		self.name = name
		self.description = description
		self.default = default

	def __str__(self):
		return self.key

	def __hash__(self):
		return hash(self.key)

	def __eq__(self, other):
		return self.key == other

{% endhighlight %}

I think set up a Feature class with the properties as specific features.

{% highlight python %}

class Feature:
    FEATURE_ONE = FeatureFlag("feature_one", "Feature One", "Description for feature one", False)
    FEATURE_ONE = FeatureFlag("feature_two", "Feature Two", "Description for feature two", True)
    ALLOWED_STORAGE = FeatureFlag("gbs_allowed", "Allowed Storage", "Allowed GBs of Storage", 10)

{% endhighlight %}

Then we group the features into a few different sets. The first group is for user-exposed flags for Change Management. The example below only allows a user to set the FEATURE_TWO feature flag.

{% highlight python %}

class ChangeManagementFlags = [
    Feature.FEATURE_TWO
]

{% endhighlight %}

Then we have classes for the defaults on signup. You can override the defaults here, or use them.

{% highlight python %}

class StandardDefaults:
    flags = {
        Feature.FEATURE_ONE.key: False,
        Feature.FEATURE_TWO.key: True,
        Feature.ALLOWED_STORAGE.key: Feature.ALLOWED_STORAGE.default
    }

class EnterpriseDefaults:
    flags = {
        Feature.FEATURE_ONE.key: True,
        Feature.FEATURE_TWO.key: True,
        Feature.ALLOWED_STORAGE.key: 100
    }

{% endhighlight %}

# Using the flags

I have two methods to set and retrieve the flags for a customer. We use the assumption a JSON field named **feature_flags** exists on the customer.

{% highlight python %}

def get_feature_flag(self, flag):
    if self.feature_flags is not None:
        return self.feature_flags.get(flag.key, flag.default)
    else:
        return flag.default

def set_feature_flag(self, flag, value):
    if self.feature_flags is not None:
        self.feature_flags[flag.key] = value
    else:
        self.feature_Flags = {flag.key: value}

{% endhighlight %}

We can then check if a feature flag is enabled, or what the limit is, for a customer. So we can do somehing like 

{% highlight python %}

if not account.get_feature_flag(Feature.FEATURE_ONE):
    throw "Feature not enabled".

{% endhighlight %}

# Change Management

Just return a list of the ChangeMAnagementFlags array and render it on a screen. With a PUT request just validate the flag exists and set it in the JSON. Not bad at all!

And there you have it! We can provide Change Management, Developer Flags (on a per customer basis) and adjustable limits (on a per customer basis). This frees our subscription tiers from rigid amounts and we can use sane-defaults, but tweak as necessary for each customer. Love it!