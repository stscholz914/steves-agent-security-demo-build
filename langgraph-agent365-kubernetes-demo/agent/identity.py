"""Secretless identity for a Kubernetes-hosted agent.
Presents the pod's projected service-account token (a short-lived OIDC JWT issued by the cluster) as the
federated assertion for the Entra agent identity blueprint, then exchanges it for the agent identity's tokens.
There is no client secret, certificate or key anywhere in the container or its configuration."""
import base64, json, os, threading, time, urllib.error, urllib.parse, urllib.request

TENANT = os.environ["AZURE_TENANT_ID"]
BLUEPRINT = os.environ["A365_BLUEPRINT_ID"]
AGENT = os.environ["A365_AGENT_ID"]
SA_TOKEN_FILE = os.environ.get("AZURE_FEDERATED_TOKEN_FILE", "/var/run/secrets/tokens/azure-identity-token")
TOKEN_URL = f"https://login.microsoftonline.com/{TENANT}/oauth2/v2.0/token"
ASSERTION = "urn:ietf:params:oauth:client-assertion-type:jwt-bearer"
_lock, _cache = threading.Lock(), {}


def claims(token):
    p = token.split(".")[1]
    return json.loads(base64.urlsafe_b64decode(p + "=" * (-len(p) % 4)))


def _post(fields):
    req = urllib.request.Request(TOKEN_URL, urllib.parse.urlencode(fields).encode(), {"Content-Type": "application/x-www-form-urlencoded"})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"token endpoint HTTP {e.code}: {e.read().decode()[:300]}") from None


def sa_token():
    return open(SA_TOKEN_FILE).read().strip()


def get_token(scope):
    """Agent-identity access token for `scope` (cached until 60 s before expiry)."""
    with _lock:
        tok, exp = _cache.get(scope, (None, 0))
        if tok and time.time() < exp - 60:
            return tok
        t1 = _post({"client_id": BLUEPRINT, "scope": "api://AzureADTokenExchange/.default", "grant_type": "client_credentials",
                    "client_assertion_type": ASSERTION, "client_assertion": sa_token(), "fmi_path": AGENT})["access_token"]
        r = _post({"client_id": AGENT, "scope": scope, "grant_type": "client_credentials",
                   "client_assertion_type": ASSERTION, "client_assertion": t1})
        _cache[scope] = (r["access_token"], time.time() + int(r.get("expires_in", 3600)))
        return r["access_token"]


def describe(token, keys=("iss", "aud", "sub", "appid", "idtyp", "xms_par_app_azp", "roles", "exp")):
    c = claims(token)
    return {k: c[k] for k in keys if k in c}
