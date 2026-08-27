import json, sys, urllib.request, urllib.parse, uuid
data = json.load(sys.stdin)
token=data["token"]; host=data["wopiHost"]; fid=data["fileId"]
def post(override, lock):
    req=urllib.request.Request(url(fid),data=b"",method="POST"); req.add_header("X-WOPI-Override",override); req.add_header("X-WOPI-Lock",lock)
    try:
        with urllib.request.urlopen(req,timeout=15) as r: return r.status, dict(r.headers)
    except urllib.error.HTTPError as e: return e.code, {k:v for k,v in e.headers.items() if k.lower().startswith("x-wopi")}
def url(doc_id, action=""):
    base=f"{host}/wopi/files/{urllib.parse.quote(doc_id)}"+("/"+action if action else "")
    return f"{base}?access_token={urllib.parse.quote(token,safe='')}"
st,hd=post("GET_LOCK","")
print("GET_LOCK:",st,hd.get("X-Wopi-Lock","")[:24])
cur=hd.get("X-Wopi-Lock","")
if cur:
    print("UNLOCK existing:", post("UNLOCK",cur)[0])
tok=f"wo:u-123:{uuid.uuid4().hex}"
st,hd=post("LOCK",tok)
print("LOCK own-style on unlocked file:", st, hd)
st,hd=post("GET_LOCK","")
print("GET_LOCK after:",st,hd.get("X-Wopi-Lock","")[:28])
st,hd=post("UNLOCK",tok)
print("UNLOCK cleanup:", st)
