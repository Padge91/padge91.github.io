---
layout: post
title: 'API Design Considerations'
date: '2022-05-05'
categories: general
---


I've worked with a lot of types of Web Service API's: REST, SOAP, GraphQL, Restlike, and whatever inbetween. I don't think I have a huge grasp on all of the different design considerations, but I feel I have enough to have some opinions.

First, the archetypes of web service APIs.

# SOAP
This is typically a legacy API, in my experience. These APIs pass data in XML, where pretty much every other type of web service API uses JSON. 

It also only works with, in my experience, POST requests. So to retrieve data, you send a POST request to a url with a body asking for data, and the response contains the data. Not really a deal breaker, but a little abnormal.

The cool thing about a SOAP API is they usually have a WSDL, which shows you the structure of the responses and requests (if you parse it correctly). Unfortunately, it seems a lot of people like to use their own flavor of a WSDL so it's not as universal as you would hope.

It's not really a pain to use, but it's not convenient. The best way I found to use it is to copy/paste a request, template out the variables into function arguments, and do something similar with the responses.

But if you're looking for a web service for a legacy application, this is where I would start. E.G. LMGTFY oracle WSDL.

# REST & REST-like
REST is certainly interesting. It's interesting because the specific, strict definition isn't universal. I've seen a lot of APIs that called themselves REST APIs and only use POST, GET, PUT, DELETE requsts (where IIRC REST calls for PATCH and HEAD requests too). These are what I call the REST-like. Not a big deal.

In fact, I usually prefer the REST-like APIs. While I can't make some assumptions about them, it's usually to the benefit of the API. Instead of sticking to a strict definition to simply meet that definition, they curb the definition to make something better (in their opinion). I can't really fault them for that.

What's nice about these is they're usually entirely in JSON. Super easy format to pull things out of.

Not much else to say here.

# GraphQL
I've had the least experience with these, but what I have is generally positive. What makes this stand apart from REST is, when querying for objects, we must specify the fields we want to have returned as a result of the query.

This gives us several benefits: faster processing, less junk data returned, more intentional parsing of requests. It's a pretty good idea.

But, a big downside for me is if this is paired with poor documentation, it becomes much more difficult. For example, if a response returns an ID and a Name field on an object, and the documentation doesn't enumerate each other field; what am I to do? Guess? 

Another benefit is versioning. It's apparently easier to version this API, since the requested fields are added or removed and existing requests and responses remain the same (filling out removed fields with nulls, I presume).

Yet another benefit is the frontend can request exactly what it needs and how it needs it. Relationships made easy!

Finally, the biggest downside is the backend logic to make all this work. You gotta make a robust backend to handle the queries efficiently.

# Designs of APIs
Now I come to what I really wanted to discuss here. Different considerations when building out an API. Most of these topics aren't settled and are up for debate. I just want to record thoughts on each.

## How to handle relationships
Let's say we have an object, User. A User has a 1:M relationship to an Adddress object. When a User is requested, what do we do with the Addresses? More often than not, the Addresses would also be available on a different URL, (e.g. /api/v1/users/3/address/) but let's say our app REQUIRES the Addresses for functionality, so we should return it alongside the User object.

What do we do? Here are the options I've tried:
### Option A: Full Object
Just return the full object. If it's necessary for the functionality, just return it. But what if these objects are huge? Or worse, what if the list of them is huge? Ignoring paging for a moment, we're asking for the USER, not the ADDRESS.

Is it wise to include the full object? I would say if it's REQUIRED for the app to function, then we probably should. For example, if we can say 90% of the time we will need to submit a second request to get an Address, then we should save that time/complexity and just return the object.

### Option B: Brief Object
But if the object is too large, maybe we can return only what's needed? For example, if we're returning a USER object with a list of ADDRESSES, I don't think we need the ADDRESS object to include the foreign key user_id, since it's implied.

We can trim down the object to only what's necessary when listed from a relationship. But this adds some complexity both in our app and in the docs. Now we have two different representations of the same Object in our API. If this is a GraphQL API, it doesn't really make a big difference. But otherwise, it kind of would.

This is one of my preferred options if the related objects are NECESSARY. Provide a summary of the object.

### Option C: ID Only
What if it's not necessary most of the time? Well we can save complexity by just sending the ID. Seems easy enough.

But we can do a little better with just minimal effort.

### Option D: ID & Link Only
Instead of sending the ID, let's send the URL of the object also. That way, if a secondary request needs to be executed, the response will tell it which ID to use. The logic may be initially complex in the client, but I think it's very convenient for it to tell me where to go to access exactly what I'm looking for.

That being said, it's a little redundant. Chances are, I already know how to get that object and I don't really need more of your help. We also come into the same issue of having two different representations of the same object in our API.

## How to handle paging
Paging isn't something every API needs, but it's something I think every APi needs eventually. 

Paging improves performance and reduces costs, but at the expense of complexity.

The functionality of the Paging in the API is probably more determinant on how you actually want to implement the paging in the data layer.


### Option A: Use a Limit and an Offset
The easiest and most popular option, let the user provide a limit and an offset. A limit will tell us how many records we want (LIMIT in a db) and the offset will tell us where to start (OFFSET). 

If, for some reason, we have to do the paging in the application layer, we can still manually trim/offset an array.

This option is nice because we can have SQL do the heavy lifting, the responses can be cached, the requests can be run in parallel, the request can specify how big or small of a page, and responses can be skipped (e.g. first request at ?offset=220&limit=4).

The biggest downside is inconsitencies with frequently changing data. If data is being added/removed from the db between page requests, it's possible an item is returned more than once, or not at all. 

We're also at the mercy of the RDBMS, which the OFFSET command isn't performant for super large datasets. Of course we can improve that with partitioning but still...

Those are pretty big negatives.

### Option B: Use a Token/Keyset

Pre-generate results and cache them with a randomized key. We need a big place for caching paged results, and new updates wont be added to cache. Then need logic to expire the cache too.

### Option C: Use a Field

Pass an *after* or *before* field. I think this is more like filtering. Don't really like this approach.

## How to handle versioning

IMO it's best to go ahead and start building an API off V1 immediately. When the models change field names, it's best to either include it in the same model (duplicate fields). When you start removing fields, you should make a change to V2.

This way old code consuming the API will continue to work wihout needing any changes. When someone has time they can go back over and update it as needed. Same goes for structural changes too, but just modeling. In general, don't take things away if they could be being used.

The trouble with this, of course, is managing 2 different models under the covers. E.G. Reworking one model into a combination of models. In the original API, the original model will have to be recreated into a single model. Not difficult, at least not with good tests.

What about removing the old versioned code? If it's public facing, probably need to announce its deprecation date (being generous) and set up alerts/monitors for usage. Try to alert customers, try to return HTTP headers including warnings, etc.

If it's an internal API, you still sould set up monitors and logging for the traffic on it, but once its tested and without any traffic for a time, it's okay to drop it.

## How to handle filtering/searching

This is one I've still had a hard time modeling. The current way I'm doing it is passing in a *search* argument which is a key/value url encoded string. The ORM can then look for those args and add conditions to the query relativly easily. 

Still have to do some validation on whether the fields exist (probably rename some fields between db table and API) and such, but there's also compexities when searching for related objects. The join conditions with the filtering can get complex, especially when filtering on everything else.

Obviously, this isn't a major problem for GraphQL, they pretty much have this built in.
