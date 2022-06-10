---
layout: 'post'
title: 'Stripe Integration'
date: '2022-05-19'
categories: general
---

Integrating with Sripe was supposed to be simple and quick. It's kind of assumed to be an end all be all of billing, but really, it gets you lke 75% of the way there for SaaS subscriptions. But you know what they say, 90% of the work is in the last 10%.

Trying to keep all of my findings here, but there's just so much I don't know if I can cover it all. I'm trying to include only the things we need to be aware of in our code, whereas everything excluded (e.g. refunds) can be mostly managed entirely in Stripe.

# Subscriptions

I have some Subscription objects in our db which are short json representations of associated Stripe subscriptions. They have fields such as tier, interval, trial_length, and products.

A Stripe subscriptions has multiple Prices under a Product, but I'm unsure of the best way to organize them, but I've set it up so all tiers/intervals are under a single product. When someone upgrades/downgrades, I have to manually convert each line item for the subscription into the correspoding tier.

For example, an upgrade from Tier A to Tier B would be adding 5 units of Tier B product, and removing 5 units of Tier B product. If there are multiple products associated with each tier, I have to do this for each product. Luckily with Stripe I can make the changes and then apply prorations to the amount.

Another thing: prices can't be changed after creation. So this means if a Subscription is created with those products, you either need to migrate them to th new Subscription or, more likely, support multiple Subscription types/architectures.

# Synchronization and Caching with Stripe

An account has two fields, a customer_token and a subscription_token, both are Stripe tokens. It also has a number of fields related to the customer info and subscription info. These other fields are routinely syned with Stripe. The subscription_token can be null in the case of cancelled subscriptions (will need to make a new one for a new sub).

For this, I register webhooks which receive most of the important events. Whenever I receive these events, I basically do a fetch to stripe to retrieve thew new customer & subscription info, and set the properties to their mirrored counterparts in the db fields. This could be simpler if you use a JSON field and cache the entire object, but you should at least have the subscription_token and customer_tokens as independent fields.

When a customer makes changes to their subscription, I record it locally and then push it out to Stripe. Of course if it fails I just won't commit to the db or I'll rollback.

# Webhooks

Stripe sends events to a configured Webhook when it's setup. This is pretty much the best way to have the billing info in your system kept up to date with Stripe. Otherwise your systems can be out of sync and bad things will happen!

Handling the signing and validation of the webhook is pretty straightforward, but Stripe will send a number of different webhooks. Below is the pseudocode for ones I have found to  be important.

# Upgrading/Downgrading Subscriptions
Upgrading and downgrading is a pain and I haven't found a perfect way to deal with it. But here is what I came up with.

Have a function for each translation. E.G. if 3 tiers, you have to do Tier A -> Tier B and Tier A -> Tier C. So that's 6 total combinations in this example. But wait! What if you offer annual pricing at a discounted rate? You could do this "off the books" with a Stripe coupon, but if you want to manage it in stripe then you need to have a method for each of these changes too.

A pain in the ass but I don't like the coupon method.

# Unit-based Pricing

This is also convenient. I can tell how many units are in-use at any time, but I do it beforehand. I tell Stripe when X event occurs, add one unit, and when Y event occurs, subtract 1 unit. When I do these, I can also tell Stripe how to handle the prorations. 

For annual licensing, we force the customers to claim a number of units beforehand. This is just an if-condition for the subscription interval, and if the current num units is less than the pre-purchased amount, we allow it. Otherwise we disallow it. It can be manually increased via our portal or in the Stripe dashboard. This will then create a proration for the amount, or we can create an invoice immediately for the amount due asap. 

You also need if conditions for which tier a customer is on. you want to make sure to add a unit of the right product for the correct tier and interval. E.G. You'll have to a switch-case or series of if-conditions or whatever to determine (is it a yearly subscription? is it for Product A? Is it for Product B?).

# Usage-based Pricing

Stripe makes this convenient. I can record a "use" and a timestamp for that use. What I do is tie this use to a cookie(could do something more fancy for more serious use-cases)and bypass the method to increase the usage.

The weird thing is the usage amount is due AFTER usage, so if your unit based license is pre-monthly, this will be 30 days behind it.

# Trials

Stripe let's us add trials to any product so that makes it easy. We can just have a length in the code, or db, and pass it along at account creation only.

## Ending Trials

One thing that's a pain is trials which end. You can set a trial for 14 days, and at the end of 14 days Stripe will attempt to convert it to a full subscription. If no card is provided then it will fail.

But, what if the trial has 0 units? Stripe doesn't even attempt to charge for it, so you have an active subscription with $0 recurring, which is a pain. Instead, you can create a subscription and set the cancel_at_period_end to true if it's a trial. This will default the subscription to end unless action is taken.

This also means when someone adds a unit, we need to set cancel_at_period_end to false.

# Invoices

Invoices are created for every charge for a Subscription. They can be paid manually or charged automatically, and you can choose this when the Subscription is created or modify it later.

You should have the option to allow users to toggle between receiving an invoice and paying manually or automatically.

If paying manually, you should probably give them a generous turnaround time for it  being paid.

## Quotes

I haven't found any convenient way to do a quote in Stripe. If you make a change to a Subscription, it is applied immediately and an invoice is generated or a proration occurs. 

It really sucks becuase this means you'll have to do a quote in an external system. And if you want the quote to apply at Subsription renewal time, tough luck. In my experience it's best to just wait a day before, make the change, and then the customer gets a little extra $$ back.

## Adjustments to Open Invoices

You can make changes to invoices by issueing a credit note aginst the invoice. About all you can do short of destroying and recreating the invoice.

# Product & Pricing Organization in Database

Have columns or a JSON column cache from Stripe. Both for the Subscriptions, Customer, and for Products. Just make sure you have a column for the ids too for easy searching. Also make sure you don't put in anything sensitive like payment info.

May want to keep things like address in Stripe, since you won't need it often. Then you can just retrieve it when a customer accesses their billing info.

# Changing Pricing

Pain in the ass. You can't change the prices after creation so you will have to manually handle multiple prices/products in the app or migrate the customers and apply a coupon.

It's probably best to migrate customers and then apply a coupon. But you'll still have some overlap so the code will need to be smart enough for that.

# Billing History

You can retrieve a list of invoices pretty easily. Should definitely do this. The API supports paging and can also provide receipt links to each invoice, which is a necessity.

# Billing Estimate

Receive an upcoming invoice and display the descriptions and whatnot. Make sure you show any credit notes and discounts too.

# Cancelling & Uncancelling

We have to pay attention to the fields cancel_at_period_end and cancel_at, because both can be used. We need to set/unset both accordingly, and we need to be aware of these. 

For example, someone could call and cancel, and the Stripe dashboard will allow a sales person to cancel the subscription at a specific date (maybe not at term end). We then need to display that time to any user visiting the CMS as a warning.

Additionally, if a subscription is cancelled we need to disallow use of the service. Pretty simple to use with the status field we synchronize from Stripe.

What about when someone uncancels? We need to set both fields to null, since either one could be used. Not so bad.


# Reactivating subscription

Stripe subscriptions, once cancelled, are gone for good. if a Stripe subscription is ccancelled, you need to create a new Subscription with matching tiers/amounts. 

# Payment Info

Let Stripe handle it with Checkout. You don't need to know anything about it. And you cna add a disclaimer to the field "Existing billing details are never shown". If you really want it, you can show a "current card #" and get the last 4 digits from Stripe and just show that. Then if they want a new card just open a popup to provide it.

# Coupons

Coupons are easy, but you need to validate they exist before using them. Nothing surprising but IIRC it won't throw an error if you try to use an invalid coupon, it just won't apply anything. 

# Some Code!

## Webhooks

event_data is the stripe object returned

{% highlight python %}

        # if a new subscription is created. This should replace the current subscription,
        # at least check to see if the product ids are the same
		if type == "customer.subscription.created":
			billing_info.subscription_token = event_data["data"]["object"]["id"]

        # if the customer info itself is changed
		elif type == "customer.updated":
			sync_billing_info(billing_info)

			# look at previous_attributes to see what changed
			previous_attributes = event_data["data"]["previous_attributes"]
			if "default_source" in previous_attributes.keys():
				# we already have an event for updated payment method
				pass
			elif "currency" in previous_attributes.keys():
                # dont care about currency changes, which re receive sometimes
				pass

        # if subscription is changed
        elif type == "customer.subscription.updated":
			# subscription changes plan or state
			sync_billing_info(billing_info, sqlalchemy_session)

			# look at previous_attributes to see what changed
			previous_attributes = event_data["data"]["previous_attributes"]

			# if cancelled
			if ("cancel_at" in previous_attributes.keys() and previous_attributes["cancel_at"] is None and event_data["data"]["object"]["cancel_at"] is not None) \
				or ("cancel_at_period_end" in previous_attributes.keys() and not previous_attributes["cancel_at_period_end"] and event_data["data"]["object"]["cancel_at_period_end"]):

                # then should inform customer of end time

		elif type == "customer.subscription.deleted":
            # notify customer of deletion

		elif type == "customer.source.updated" or type == "customer.source.created" or type == "customer.source.deleted":
            # notify customer


		elif type == "invoice.upcoming":
			stripe_invoice = event_data["data"]["object"]

            # notify about upcoming subscription renewal and send a link to the invoice

        elif type == "invoice.payment_action_required":
			# requires action, send a link to the invoice

        elif type == "invoice.payment_succeeded":
			# invoice charge succeeded
            # send a link to the receipt

        elif type == "invoice.payment_failed":
			# invoice charge failed
            # send a link to the invoice

		elif type == "customer.subscription.trial_will_end":
            # send a reminder about the trial ending in 3 days


{% endhighlight %}

There are probably many more things you want to notify the cusomer of, but in my experience those mostly relate to marketing. You should send those through a Hubspot workflow or something similar, and keep your code clean with handling just these events.

## Billing Info

I have a whole group of services for managing billing info. In general, here's what they do:

BillingInfo.py
{% highlight python %}

def create_billing_info(account_name, billing_email, billing_name, billing_phone, is_trial=False, stripe_token=None, num_units=0, coupon=None):
    # do some validations
    stripe_customer = create_customer(account_name, billing_email, billing_name, stripe_token, coupon)
    stripe_sub = create_sub(stripe_customer, is_trial, num_units)

    billing_info = BillingInfo()
    billing_info.stripe_subscription_token = stripe_sub.id
    billing_info.stripe_customer_token = stripe_customer.id
    billing_info.customer_info = stripe_customer
    billing_info.sub_info = stripe_subscription
    billing_info.last_sync = now()
    return billing_info

def get_billing_info(billing_info):
    # convert billing_info into a customer-facing dictionary
    # e.g.
    return {"trialEnd":billing_info.sub_info.trial_end_at}

def sync_billing_info(billing_info):
    # retrieve new stripe info
    billing_info.sub_info = stripe.get_subscription(billing_info.stripe_subscription_token)
    billing_info.last_sync = now()
    
def is_account_tier_a(account):
    # determine if subscription is in tier a
    # legacy way to gate/block features
    # instead, use FeatureFlags and set FeatureFlags to defaults based on tiers
    # e.g. when upgrading to Professional, account.feature_flags = ProFlags.
    return billing_info.sub_info.product.name == "Tier A"


{% endhighlight %}

Conversions.py
{% highlight python %}

def convert_interval(billing_info, new_sub, num_units=0):
    items = []

    # clear out old products
    for sub_item in billing_info.sub_info.items:
        items.append({id: sub_item.id, deleted:True})

    # add new products
    # do whatever logic you need to find the right product to match the units
    items.append({id:new_sub.item[0].id, quantity: num_units})

    # update stripe
    stripe.modify(billing_info.sub_token, items=items, proration_behavior="none")

{% endhighlight %}

Coupons
{% highlight python %}

\# pretty straightforward

def apply_coupon():

def is_coupon_valid():

def create_coupon():
    # used primarily for referrl discounts

{% endhighlight %}

Customer.py
{% highlight python %}

def create_customer(email, name, coupon, ...etc):
    # create stripe customer

def update_customer(email, name, ...etc):
    # just give new customer info

def has_source(customer_id):
    # check if has a cc

def has_required_billing_info():
    # don't upgrade from trial if we don't have this

{% endhighlight %}

Invoice.py
{% highlight python %}

def create_invoice

def list_invoices

def get_upcoming_invoice

{% endhighlight %}

Licenses.py
{% highlight python %}

def get_num_licenses()
    # do manual count of licenses a user should have
    # or retrieve from stripe

def set_num_licenses(quantity, prorate=False):
    # set the number of licenses in stripe
    if prorate
				stripe.Subscription.modify(subscription_token, items=[{"id": subscription_item.id, "quantity": quantity}], proration_behavior="create_prorations")
			else:
				stripe.Subscription.modify(subscription_token, items=[{"id": subscription_item.id, "quantity": quantity}], proration_behavior="none")


{% endhighlight %}

Subscription.py
{% highlight python %}

def get_subscription():
    # retrieve sub info

def cancel_subscription():
    # set cancel_at_period_end to true

def create_subscription(customer, product, is_trial, num_units):
    # create normally

def reactivate_subscription(billing_info):
    # if status is canceled, need to create a new one using old one as a template
    # otherwise, set cancel_at_period_end and cancel_at to null

def is_sub_expiring():
    # easy method to know if we are about to expire

def is_annual():
    pass

def is_enterprise():
    pass

def is_tier_a():
    pass
{% endhighlight %}

That's most of it. Just pseudocode really.

I think the best way to manage it is to have ONE PRODUCT if at all possible, with different tiers. That way you don't have to do multiple if conditions for searching for different products. 

If you DO want to offer different products, make it a ADD-ON subscription. So the user will have 2 subscriptions, one for the first product, and one for an addon. You can set these to the same billing cycle to make it less confusing.