---
layout: post
title: 'Geocoder & IP Locations'
date: '2022-06-10'
categories: general
---

Sometimes it's nice to get coordinates from an IP Address or from a Street Address. These functions help with both of those:


{% highlight python %}

import geocoder
import requests

def get_coordinates_from_street_address(street_address):
    geo = geocoder.arcgis(stree_address)
    return g.latlng

def get_coordinate_from_ip_address(ip_address):
    response = requests.get("https://ipapi.co/"+str(ip_address)+"/json")
    body = response.json()
    return (body["latitude], body["longitude], body["timezone"])

{% endhighlight %}

The IpAPI service has rate limiting, but you can compare any new IP to an existing IP to see if you need ot retrieve the coordinates (otherwise you can just save them). The geocoder is an open python package which holds all that data internally, I believe.