import json, sys, urllib.request, urllib.parse, uuid
data = json.load(sys.stdin)
token=data["token"]; host=data["wopiHost"]; fid=data["fileId"]
def url(doc_id, action=""):
    base=f"{host}/wopi/files/{urllib.parse.quote(doc_id)}"+("/"+action if action else "")
    return f"{base}?access_token={urllib.parse.quote(token,safe='')}"
# CFI -> UserId
try:
    req=urllib.request.Request(url(fid)); req.add_header("Authorization",f"Bearer {token}")
    import json as j
    info=j.loads(urllib.request.urlopen(req,timeout=15).read())
    print("CFI UserId:", info.get("UserId"), "| UserName:", info.get("UserFriendlyName") or info.get("UserName"))
except Exception as e:
    print("CFI err", e)
# try owning-style lock token
tok=f"wo:{info.get('UserId','u-1')}:{uuid.uuid4().hex}"
try:
    req=urllib.request.Request(url(fid),data=b"",method="POST"); req.add_header("X-WOPI-Override","LOCK"); req.add_header("X-WOPI-Lock",tok)
    print("LOCK own-style ->", urllib.request.urlopen(req,timeout=15).status)
except urllib.error.HTTPError as e:
    print("LOCK own-style ->", e.code, e.read()[:100])
# unlock
try:
    req=urllib.request.Request(url(fid),data=b"",method="POST"); req.add_header("X-WOPI-Override","UNLOCK"); req.add_header("X-WOPI-Lock",tok)
    print("UNLOCK ->", urllib.request.urlopen(req,timeout=15).status)
except urllib.error.HTTPError as e:
    print("UNLOCK ->", e.code, e.read()[:100])
