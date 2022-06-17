---
layout: post
title: 'Building Electron Apps'
date: '2022-06-16'
categories: general
---

Figuring out how to build SIGNED electron apps was kind of a challenge.

# Windows

First, you need a signing key. I got one from SSL.com for an EV Certificate. It came with a Pin # and a Yubikey. To do the signing, I gotta insert the Yubikey and at one point it'll prompt for the pin. 

So here's the code:

{% highlight bash %}
windows_cert = "../company.chained.crt"
./node_modules/.bin/electron-builder -w
osslsigncode sign -verbose -pkcs11engine /usr/local/mac-dev/lib/engines-1.1/libpkcs11.dylib -pkcs11module /Library/OpenSC/lib/opensc-pkcs11.so -h sha256 -n "App Name" -key '01' -in "./dist/App Setup $(version).exe" -out "./dist/App $(version).signed.exe" -certs $(windows_cert)
rm "./dist/App $(version).exe"
mv "./dist/App $(version).signed.exe" "./dist/App $(version).exe"
{% endhighlight %}

I had to install the dependencies OpenSC and libpkcs, but outside of that it was fine.

# Mac
This is a little harder, it was more of a trial and error process too. And I have a few rules in the Makefile:

{% highlight bash %}

version = "1.1"
appleid = "example""
applepassword = "example"
app_cert = "CERT"
pkg_cert = "Developer ID Installer: CERT ID"
provisionprofilepath = "./example.provisionprofile"
tmp_id_path = "./dist/tmp.id"

mac:
	make mac_app
	make mac_pkg

# build sign and notarize
mac_app:
	./node_modules/.bin/electron-builder -m
	make mac_app_sign
	make mac_app_notarize
	sleep 5s
	make notarize_wait id=$$(cat $(tmp_id_path))
	make mac_app_staple

mac_pkg:
	pkgbuild --version $(version) --install-location /Applications --component ./dist/mac/Example.app ./dist/mac/Example-$(version)-tmp.pkg
	productsign --sign $(pkg_cert) "./dist/mac/Example-$(version)-tmp.pkg" "./dist/mac/Example-$(version).pkg"
	rm "./dist/mac/Example-$(version)-tmp.pkg"
	make mac_pkg_notarize
	sleep 5s
	make notarize_wait id=$$(cat $(tmp_id_path))
	make mac_pkg_staple

mac_app_sign:
	cp $(provisionprofilepath) "../dist/mac/Example.app/Contents/embedded.provisionprofile"
	codesign --sign $(app_cert) --force --timestamp --options runtime --entitlements ../build/entitlements.mas.inherit.plist "../dist/mac/Example.app/Contents/Frameworks/Electron Framework.framework/Versions/A/Libraries/libGLESv2.dylib"
	codesign --sign $(app_cert) --force --timestamp --options runtime --entitlements ../build/entitlements.mas.inherit.plist "../dist/mac/Example.app/Contents/Frameworks/Electron Framework.framework/Versions/A/Libraries/libEGL.dylib"
	codesign --sign $(app_cert) --force --timestamp --options runtime --entitlements ../build/entitlements.mas.inherit.plist "../dist/mac/Example.app/Contents/Frameworks/Electron Framework.framework"
	codesign --sign $(app_cert) --force --timestamp --options runtime --entitlements ../build/entitlements.mas.inherit.plist "../dist/mac/Example.app/Contents/Frameworks/ReactiveCocoa.framework"
	codesign --sign $(app_cert) --force --timestamp --options runtime --entitlements ../build/entitlements.mas.inherit.plist "../dist/mac/Example.app/Contents/Frameworks/Squirrel.framework"
	codesign --sign $(app_cert) --force --timestamp --options runtime --entitlements ../build/entitlements.mas.inherit.plist "../dist/mac/Example.app/Contents/Frameworks/Mantle.framework"
	codesign --sign $(app_cert) --force --timestamp --options runtime --entitlements ../build/entitlements.mas.plist "../dist/mac/Example.app"

mac_app_notarize:
	ditto -c -k --keepParent "./dist/mac/Example.app/" "./dist/mac/Example.zip"
	xcrun altool --notarize-app --primary-bundle-id com.example.bundle -u "$(appleid)" -f "../dist/mac/Example.zip" -p "$(applepassword)" | sed "s/.*RequestUUID = \([A-Za-z0-9-]*\).*/\1/g" | sed -n 2p > $(tmp_id_path)

mac_app_staple:
	xcrun stapler staple "../dist/mac/Example.app"

mac_pkg_notarize:
	xcrun altool --notarize-app --primary-bundle-id com.example.bundle -u "$(appleid)" -f "../dist/mac/Example-$(version).pkg" -p "$(applepassword)" | sed "s/.*RequestUUID = \([A-Za-z0-9-]*\).*/\1/g" | sed -n 2p > $(tmp_id_path)

# has to be its own command since notarizing is asynchronous
mac_pkg_staple:
	xcrun stapler staple "../dist/mac/Example-$(version).pkg"

notarize_info:
	xcrun altool --notarization-info $(id) -u $(appleid) -p $(applepassword)

notarize_wait:
	@while echo $$(make notarize_info id=$(id)) | grep -q "Status: in progress"; do     \
		echo "Waiting for Notarization to complete...";														   \
		sleep 30s;																	   \
	done;																			   \

	@if echo $$(make notarize_info id=$(id)) | grep -q "Status: success" ; then \
		echo "NOTARIZATION: Success";										  	  \
		exit 0;															      \
	else																	      \
		echo "NOTARIZATION: Failure";										      \
		exit 1;															      \
	fi;																		      \


list_certs:
	security find-identity -v -p codesigning

{% endhighlight %}


The hardest part was the mac_app_sign body, as to find out everything that needing signing, I had to submit it to apple for approval, and then an automated response will tell you everything that wasn't signed. I've also truncated it for many of the dependencies.