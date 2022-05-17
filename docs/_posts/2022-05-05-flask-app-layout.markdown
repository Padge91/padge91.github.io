---
layout: post
title: 'Flask app organization'
date: '2022-05-17'
categories: general
---

Obviously the below code isn't completed - it doesn't capture all errors or check for values before accessing, but it should give you an accurate idea.

# Endpoints

This one should be pretty short and easy. I find it easiest to organize each section of endpoints into a module, and any paths as submodules. It makes it easy to reorganize the paths if needed, and also makes it simple to break into microservices eventually.

E.G
{% highlight python %}
src/
 - api/
    - v1/
       - assets/
          - files/
             - app.py
          - folders/
             - app.py
       - org/
          - billing/
             - app.py
          - users/
             - app.py
          - roles
             - app.py
{% endhighlight %}

In my example I'm using app.py but you could just as easily use the __init__.py instead (in fact it's probably best to do that instead). 

# Templates
Just use the default *templates/* folder. No need to move it elsewhere.

# Decorators
I think it's best to use decorators to bootstrap the response and to do the teardow too. These are the decorators I use:

## Required Authentication

{% highlight python %}

def requires_auth(f):
    @wraps(f)
    def wrapped(*args, **kwargs):
        userinfo = None
        try:
            userinfo = decode_flask_cookie(token)
        except Exception:
            try:
                userinfo = decode_jwt_token(token)
            except Exception:
                pass
        if userinfo is None:
            raise AuthenticationException("Unable to find userinfo in JWT.")

        user_uuid = userinfo["uuid"]

        # set user
        user = g.sqlalchemy_session.query(src.models.User)\
		    .filter_by(is_deleted=False, uuid=user_uuid).first()
        if user is None:
            raise NoUserFoundException()
        g.user = user
        return f(*args, **kwargs)
    return wrapped

{% endhighlight %}

## Format a success or failure response
Not technically decorators but could be used in a similar fashion based on whether a response is returned or an exception.

{% highlight python %}

def success_response(items, etag = None, pagination=None):
	data = {"success":True, "message":items}
	if pagination is not None:
		data["pagination"] = pagination
	response = make_response(data, 200)
	if etag is not None:
		response.headers["Etag"] = '"'+str(etag)+'"'
	return response


def error_response(e, response_code=400):
		return jsonify({"success": False, "message":str(e), "ref":"code"}), response_code

{% endhighlight %}

## Support an Etag response

{% highlight python %}

def if_modified_header(f):
    @wraps(f)
    def wrapped(*args, **kwargs):
        response = f(*args, **kwargs)
        etag = md5.hash(response)
        if etag == request.headers.get("If-None-Match"):
            return make_response(code=304)
        else:
            response.headers["Etag"] = etag
            return response

        return response
    return wrapped


{% endhighlight %}

## Open and close ORM sessions

{% highlight python %}

def requires_db_session(f):
    @wraps(f)
    def wrapped(*args, **kwargs):
        g.sqlalchemy_session = src.sqlalchemy.sessionmaker()
        response = None
        try:
            response = f(*args, **kwargs)
        except Exception as e:
            exception = e
        finally:
            sqlalchemy_session.close()
        return response
    return wrapped

{% endhighlight %}

## Handle already unhandled exceptions

{% highlight python %}

def handle_exceptions():
    def decorator(f):
        @wraps(f)
        def wrapped(*args, **kwargs):
            try:
                return f(*args, **kwargs)
            except AttributeError as e:
                logger.error(f"Unknown attribute {e}.\n{traceback.format_exc()}")
                return make_response("Internal Error", code=500)
            except ExpiredSignatureError as e:
                logger.error("JWT Signature has expired: "+str(e))
                return make_response("Internal Error.", code=500)
            except Exception as e:
                logger.error(f"{request.method} {request.path}: Exception: {e}.\n{traceback.format_exc()}")
                return make_response("Internal Error.", code=500)

        return wrapped

    return decorator

{% endhighlight %}

## Audit Log

{% highlight python %}

def audit_log(*args, log_body=False):
    def decorator(f):
        @wraps(f)
        def wrapped(*args, **kwargs):
            response = f(*args, **kwargs)

            account_id = kwargs.get("org_id")
            resource_id = kwargs.get("resource_id")

            audit_log_group_id = org_id
            audit_log_target_id = None

            body = None
            if log_body:
                body = request.body

            if response.status_code == 200:
                src.services.AuditLog.log(
                    g.user_guid, audit_log_target_id, audit_log_group_id, f.__name__,body)
            return response

        return wrapped

    if len(args) == 1 and callable(args[0]):
        return decorator(args[0])
    return decorator

{% endhighlight %}


# Services

## AuditLog

## Database ORM