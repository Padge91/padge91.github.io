---
layout: 'post'
title: 'Stripe Integration'
date: '2022-05-19'
categories: general
---

Integrating with Sripe was supposed to be simple and quick. It's kind of assumed to be an end all be all of billing, but really, it gets you lke 75% of the way there for SaaS subscriptions. But you know what they say, 90% of the work is in the last 10%.

Trying to keep all of my findings here, but there's just so much I don't know if I can cover it all. I'm trying to include only the things we need to be aware of in our code, whereas everything excluded (e.g. refunds) can be mostly managed entirely in Stripe.

# Synchronization and Caching with Stripe

# Webhooks

Stripe sends events to a configured Webhook when it's setup. This is pretty much the best way to have the billing info in your system kept up to date with Stripe. Otherwise your systems can be out of sync and bad things will happen!

Handling the signing and validation of the webhook is pretty straightforward, but Stripe will send a number of different webhooks. Below is the pseudocode for ones I have found to  be important.

{% highlight python %}

\# event_data is the Stripe webhook object

{% endhighlight %}

# Upgrading/Downgrading Subscriptions

## Tiers

## Intervals

# Unit-based Pricing

# Usage-based Pricing

# Trials

## Ending Trials

# Invoices

## Quotes

## Adjustments to Open Invoices

# Product & Pricing Organization in Database

# Changing Pricing

# Billing History

# Billing Estimate

# Cancelling & Uncancelling

# Reactivating subscription

# Payment Info