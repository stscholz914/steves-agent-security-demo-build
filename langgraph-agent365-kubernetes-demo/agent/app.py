"""LangGraph ReAct agent wrapped with the Microsoft Agent 365 SDK (observability) and an Entra agent identity.
Runs in any Kubernetes cluster (EKS, on-premises). All credentials come from the pod's federated identity."""
import json, os, sys, urllib.parse, urllib.request, urllib.error
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import identity

OBS_SCOPE = "api://9b975845-388f-4429-889e-eab1ef63949c/.default"
GRAPH = "https://graph.microsoft.com/.default"
AOAI_SCOPE = "https://cognitiveservices.azure.com/.default"
ENV_NAME = os.environ.get("A365_ENVIRONMENT", "kubernetes")
AGENT_NAME = os.environ.get("A365_AGENT_NAME", "LangGraphAgent")

# ---- Step 1: existing OpenTelemetry stack (console exporter so spans are visible in pod logs) ----
from opentelemetry import trace
from opentelemetry.sdk.resources import SERVICE_NAME, Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor, ConsoleSpanExporter

provider = TracerProvider(resource=Resource.create({SERVICE_NAME: AGENT_NAME}))
provider.add_span_processor(BatchSpanProcessor(ConsoleSpanExporter(out=sys.stdout, formatter=lambda s: json.dumps(
    {"span": s.name, "trace": format(s.context.trace_id, "032x")[:8], "attrs": {k: str(v)[:80] for k, v in s.attributes.items() if k.startswith(("gen_ai.operation", "gen_ai.tool", "gen_ai.agent", "gen_ai.request.model"))}}) + "\n")))
trace.set_tracer_provider(provider)

# ---- Step 2: Agent 365 SDK configure(): adds the Agent 365 exporter to the same TracerProvider ----
from microsoft_agents_a365.observability.core import AgentDetails, InvokeAgentScope, InvokeAgentScopeDetails, Request, configure
from microsoft_agents_a365.observability.core.exporters.agent365_exporter_options import Agent365ExporterOptions

if not configure(service_name=AGENT_NAME, service_namespace="agent365-demo",
                 exporter_options=Agent365ExporterOptions(use_s2s_endpoint=True,
                                                         token_resolver=lambda agent_id, tenant_id: identity.get_token(OBS_SCOPE))):
    print("WARNING: Agent 365 observability configure() returned False", flush=True)

# ---- Step 2b: auto-instrument LangChain/LangGraph LLM and tool calls ----
from microsoft_agents_a365.observability.extensions.langchain import CustomLangChainInstrumentor
CustomLangChainInstrumentor()

# ---- Step 3: the LangGraph agent. Tools act as the agent identity; the LLM is called with its Entra token ----
from langchain_core.tools import tool
from langchain_openai import AzureChatOpenAI
from langgraph.prebuilt import create_react_agent


def _graph(path):
    req = urllib.request.Request("https://graph.microsoft.com/v1.0/" + path, headers={"Authorization": "Bearer " + identity.get_token(GRAPH)})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return r.status, json.load(r)
    except urllib.error.HTTPError as e:
        return e.code, {"error": json.loads(e.read() or b"{}").get("error", {}).get("code")}


@tool
def find_employee(name: str) -> str:
    """Look up an employee in the corporate directory by display name prefix. Returns name, title and email."""
    s, b = _graph("users?$filter=" + urllib.parse.quote(f"startswith(displayName,'{name}')") + "&$select=displayName,jobTitle,mail&$top=3")
    return json.dumps(b.get("value", b))


@tool
def list_security_groups() -> str:
    """List directory groups. (This identity has NOT been granted group access.)"""
    s, b = _graph("groups?$top=3&$select=displayName")
    return json.dumps({"status": s, **b})


llm = AzureChatOpenAI(azure_endpoint=os.environ["AZURE_OPENAI_ENDPOINT"], azure_deployment=os.environ.get("AZURE_OPENAI_DEPLOYMENT", "gpt-4.1-mini"),
                      api_version="2024-10-21", azure_ad_token_provider=lambda: identity.get_token(AOAI_SCOPE), temperature=0)
agent = create_react_agent(model=llm, tools=[find_employee, list_security_groups])
DETAILS = AgentDetails(agent_id=identity.AGENT, agent_name=AGENT_NAME, tenant_id=identity.TENANT)


def ask(question):
    with InvokeAgentScope.start(scope_details=InvokeAgentScopeDetails(), agent_details=DETAILS, request=Request(content=[question])) as scope:
        result = agent.invoke({"messages": [{"role": "user", "content": question}]})
        answer = result["messages"][-1].content
        scope.record_response(answer)
    trace.get_tracer_provider().force_flush()
    return answer


class H(BaseHTTPRequestHandler):
    def _send(self, code, obj):
        b = json.dumps(obj, indent=1).encode()
        self.send_response(code); self.send_header("Content-Type", "application/json"); self.send_header("Content-Length", str(len(b))); self.end_headers(); self.wfile.write(b)

    def do_GET(self):
        if self.path == "/healthz":
            return self._send(200, {"ok": True})
        if self.path == "/identity":
            return self._send(200, {"environment": ENV_NAME, "pod_service_account_token": identity.describe(identity.sa_token(), ("iss", "aud", "sub", "exp")),
                                    "graph_token": identity.describe(identity.get_token(GRAPH)), "openai_token": identity.describe(identity.get_token(AOAI_SCOPE), ("aud", "sub", "idtyp", "xms_par_app_azp", "exp"))})
        self._send(404, {})

    def do_POST(self):
        if self.path != "/ask":
            return self._send(404, {})
        q = json.loads(self.rfile.read(int(self.headers.get("Content-Length", 0))) or b"{}").get("q", "")
        try:
            self._send(200, {"environment": ENV_NAME, "question": q, "answer": ask(q)})
        except Exception as e:
            self._send(500, {"error": str(e)[:400]})

    def log_message(self, *a):
        pass


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "ask":
        print(ask(" ".join(sys.argv[2:])))
    else:
        print(f"{AGENT_NAME} listening on :8080 ({ENV_NAME})", flush=True)
        ThreadingHTTPServer(("0.0.0.0", 8080), H).serve_forever()
