#!/usr/bin/env python3
"""Exercise the simulator-only Remote pairing and FLEX publish path."""
import json
import pathlib
import sys
import time
import urllib.request
import urllib.error
import uuid
import threading
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler

state = None
rotated = False
for _ in range(100):
    try:
        state = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
    except (FileNotFoundError, json.JSONDecodeError):
        pass
    if state and state.get("state") == "running" and state.get("code"):
        break
    if state and state.get("state") == "running" and not state.get("code") and not rotated:
        (pathlib.Path(sys.argv[1]).parent / "RemoteTestCommand.json").write_text(json.dumps({"action": "rotate"}), encoding="utf-8")
        rotated = True
    time.sleep(0.1)
assert state and state["state"] == "running" and state["code"]
origin = state["url"]
cookie = ""
csrf = ""


def post(path, body):
    global cookie
    headers = {"Origin": origin, "Content-Type": "application/json"}
    if cookie:
        headers["Cookie"] = cookie
    if csrf:
        headers["x-dylix-csrf"] = csrf
    request = urllib.request.Request(origin + path, json.dumps(body).encode(), headers)
    with urllib.request.urlopen(request, timeout=10) as response:
        set_cookie = response.headers.get("Set-Cookie")
        if set_cookie:
            cookie = set_cookie.split(";", 1)[0]
        return json.load(response)


pair = post("/api/v1/pair", {"code": state["code"], "name": "FLEX integration fixture", "workspace": True})
assert pair["data"]["state"] == "approved" and cookie.startswith("DylixRemoteSession=")
status_request = urllib.request.Request(origin + "/api/v1/status", headers={"Cookie": cookie})
with urllib.request.urlopen(status_request, timeout=10) as response:
    status = json.load(response)
csrf = status["session"]["csrf"]
assert status["session"]["permission"] == "workspace"
next_request = urllib.request.Request(origin + "/api/v1/flex/next", headers={"Cookie": cookie})
with urllib.request.urlopen(next_request, timeout=10) as response:
    assert json.load(response)["data"] == {}
try:
    post("/api/v1/flex/reply", {"id": "unknown-command", "result": {"ok": True}})
    raise AssertionError("unissued FLEX command reply was accepted")
except urllib.error.HTTPError as failure:
    assert failure.code == 400


def job(action, arguments=None, project=""):
    started = post("/api/v1/workspace", {"action": action, "projectID": project, "arguments": arguments or {}})["data"]
    for _ in range(50):
        current = post("/api/v1/jobs/get", {"id": started["id"]})["data"]
        if current["state"] == "completed":
            return current["result"]
        if current["state"] == "failed":
            raise AssertionError(current.get("error"))
        time.sleep(0.1)
    raise AssertionError("job did not complete")


context = job("flex_publish", {"bundleID": "test.fixture", "className": "UIView", "report": "UIView -> UIViewController"})
assert context["bundleID"] == "test.fixture" and context["className"] == "UIView"
projects = job("projects")["projects"]
assert isinstance(projects, list)
if projects:
    project = projects[0]["id"]

    sid = job("ai_create", project=project)["id"]
    other = job("ai_create", project=project)["id"]

    confirmations = []

    def permission(session, enabled=None):
        arguments = {"sessionID": session}
        if enabled is not None:
            arguments["enabled"] = enabled
        started = post("/api/v1/workspace", {"action": "flex_tool_permission", "projectID": project, "arguments": arguments})["data"]
        for _ in range(50):
            current = post("/api/v1/jobs/get", {"id": started["id"]})["data"]
            if current["state"] == "awaiting_confirmation":
                assert enabled is True
                confirmations.append(session)
                post("/api/v1/jobs/confirm", {"id": started["id"], "nonce": current["nonce"], "accepted": True})
            elif current["state"] == "completed":
                return current["result"]
            elif current["state"] == "failed":
                raise AssertionError(current.get("error"))
            time.sleep(0.1)
        raise AssertionError("FLEX permission job did not complete")

    assert permission(sid)["enabled"] is False
    granted = permission(sid, True)
    assert granted == {"sessionID": sid, "enabled": True, "scope": "conversation"}
    assert permission(sid, True) == granted  # idempotent, no second confirmation
    assert permission(other)["enabled"] is False
    assert permission(sid) == granted  # reopening same conversation keeps authorization
    assert permission(sid, False)["enabled"] is False
    assert permission(other)["enabled"] is False
    assert confirmations == [sid], "grant must require one overall confirmation only"

    # Production Remote -> runtime -> HTTP transport: same connection, two models.
    received = []; received_bodies = []
    class ModelEcho(BaseHTTPRequestHandler):
        def log_message(self, *args): pass
        def do_POST(self):
            request = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
            received.append(request["model"]); received_bodies.append(request)
            events = [{"choices": [{"index": 0, "delta": {"content": "echo:" + request["model"]}, "finish_reason": None}]},
                      {"choices": [{"index": 0, "delta": {}, "finish_reason": "stop"}]}]
            if any("permission-flow-fixture" in str(m.get("content")) for m in request.get("messages", [])):
                tools = [m for m in request["messages"] if m.get("role") == "tool"]
                if len(tools) < 2:
                    name = "flex_sensitive_read" if not tools else "flex_control"
                    args = {"operation": "defaults_get", "key": "AppleLocale"} if not tools else {"operation": "set_network_recording", "enabled": False}
                    events = [{"choices": [{"index": 0, "delta": {"tool_calls": [{"index": 0, "id": "permission-call-" + str(len(tools)), "type": "function", "function": {"name": name, "arguments": json.dumps(args)}}]}, "finish_reason": None}]}, {"choices": [{"index": 0, "delta": {}, "finish_reason": "tool_calls"}]}]
            raw = ("".join("data: " + json.dumps(e) + "\n\n" for e in events) + "data: [DONE]\n\n").encode()
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream")
            self.send_header("Content-Length", str(len(raw)))
            self.end_headers()
            self.wfile.write(raw)
    server = ThreadingHTTPServer(("127.0.0.1", 18991), ModelEcho)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    commands = pathlib.Path(sys.argv[1]).parent / "RemoteTestCommand.json"
    commands.write_text(json.dumps({"action": "fixture_model"}))
    try:
        for _ in range(30):
            connections = job("ai_connections", project=project)["connections"]
            if any(c["id"] == "remote-ui-fixture" for c in connections): break
            time.sleep(.2)
        for model in ["gpt-5-fixture", "gpt-5-fixture-alt"]:
            result = job("ai_send", {"sessionID": sid, "connectionID": "remote-ui-fixture", "model": model, "text": "model routing fixture", "mode": "ask"}, project=project)
            assert result["sessionID"] == sid
            record = job("ai_read", {"sessionID": sid}, project=project)
            assert record["modelID"] == model and record["connectionID"] == "remote-ui-fixture"
            assert any(m.get("role") == "assistant" and "echo:" + model in str(m.get("content")) for m in record["messages"])
        assert received == ["gpt-5-fixture", "gpt-5-fixture-alt"], received
        try:
            job("ai_send", {"sessionID": sid, "connectionID": "remote-ui-fixture", "model": "removed-model", "text": "invalid selection fixture"}, project=project)
            raise RuntimeError("unknown model silently fell back")
        except urllib.error.HTTPError as error:
            payload = json.load(error)
            assert error.code == 400 and "模型已移除" in payload["data"]["error"]
        assert len(received) == 2
        # Explicit choice -> persisted -> omitted effort -> actual provider body.
        opts = next(c['efforts'] for c in connections if c['model']=='gpt-5-fixture-alt')
        assert any(o['id']=='high' for o in opts), opts
        base={'sessionID':sid,'connectionID':'remote-ui-fixture','model':'gpt-5-fixture-alt','text':'thinking inheritance fixture','mode':'ask'}
        job('ai_send',{**base,'reasoningEffort':'high'},project=project)
        assert received_bodies[-1]['reasoning_effort']=='high'
        job('ai_send',base,project=project)
        assert received_bodies[-1]['reasoning_effort']=='high', 'omitted FLEX effort discarded session choice'
        assert job('ai_read',{'sessionID':sid},project=project)['reasoningEffort']=='high'
        job('ai_send',{**base,'reasoningEffort':'auto'},project=project)
        assert 'reasoning_effort' not in received_bodies[-1]
        job('ai_send',{**base,'reasoningEffort':'high'},project=project)
        job('ai_send',{**base,'model':'gpt-5-fixture'},project=project)
        assert 'reasoning_effort' not in received_bodies[-1], 'model change leaked old effort'
        count=len(received_bodies)
        try:
            job('ai_send',{**base,'reasoningEffort':'nonexistent'},project=project)
            raise AssertionError('invalid thinking effort accepted')
        except urllib.error.HTTPError as error:
            assert error.code==400
        assert len(received_bodies)==count
        print('PASS FLEX thinking explicit/inherited/auto/model-switch/invalid HTTP request regressions',flush=True)
        # Existing production approval path: one conversation grant covers both read and control.
        commands.write_text(json.dumps({"action": "fixture_model", "tools": True}))
        time.sleep(.5)
        approvals, delivered = [], []
        next_heartbeat = urllib.request.Request(origin + "/api/v1/flex/next", headers={"Cookie": cookie})
        with urllib.request.urlopen(next_heartbeat, timeout=10) as response: json.load(response)
        started = post("/api/v1/workspace", {"action": "ai_send", "projectID": project, "arguments": {"sessionID": other, "connectionID": "remote-ui-fixture", "model": "gpt-5-fixture", "text": "permission-flow-fixture", "mode": "develop"}})["data"]
        for _ in range(150):
            current = post("/api/v1/jobs/get", {"id": started["id"]})["data"]
            if current["state"] == "awaiting_confirmation":
                assert current["confirmation"]["summary"] == "授权本会话全部 FLEX 工具"
                approvals.append(current["nonce"])
                post("/api/v1/jobs/confirm", {"id": started["id"], "nonce": current["nonce"], "accepted": True})
            with urllib.request.urlopen(next_heartbeat, timeout=10) as response: command = json.load(response)["data"]
            if command.get("id"):
                assert command["sessionID"] == other
                delivered.append(command["operation"])
                post("/api/v1/flex/reply", {"id": command["id"], "result": {"fixture": True, "value": "zh_CN", "enabled": False}})
            if current["state"] == "completed": break
            assert current["state"] not in ["failed", "cancelled"], current.get("error")
            time.sleep(.1)
        assert current["state"] == "completed"
        assert delivered == ["defaults_get", "set_network_recording"], delivered
        assert len(approvals) == 1, approvals
        persisted = job("ai_read", {"sessionID": other}, project=project)
        completed = [r for r in persisted.get("processRecords", []) if r.get("status") == "completed"]
        assert [r["name"] for r in completed] == ["flex_sensitive_read", "flex_control"]
        assert persisted["remoteRevision"] > 0
        assert permission(other)["enabled"] is True
        assert permission(sid)["enabled"] is False
        assert permission(other, False)["enabled"] is False
    finally:
        commands.write_text(json.dumps({"action": "fixture_model_remove"}))
        server.shutdown()
documents = pathlib.Path(sys.argv[1]).parent
result_file = documents / "RemoteFlexResult.json"
result_file.unlink(missing_ok=True)
session_id = str(uuid.uuid4())
(documents / "RemoteTestCommand.json").write_text(json.dumps({"action": "flex_live_fixture", "device": status["session"]["id"], "session": session_id}), encoding="utf-8")
command = None
for _ in range(100):
    with urllib.request.urlopen(next_request, timeout=10) as response:
        command = json.load(response)["data"]
    if command.get("id"):
        break
    time.sleep(0.1)
assert command["operation"] == "current" and command["expiresAt"] > time.time()
fixture_result = {"screen": "fixture", "body": "x" * 16384}
assert post("/api/v1/flex/reply", {"id": command["id"], "result": fixture_result})["data"]["accepted"]
for _ in range(100):
    if result_file.exists():
        break
    time.sleep(0.1)
assert json.loads(result_file.read_text(encoding="utf-8"))["result"] == fixture_result
assert post("/api/v1/logout", {})["data"]["loggedOut"]
print(f"Remote FLEX HTTP integration passed: session-scoped grants, single approval, revocation, model switching with real HTTP echo, invalid model rejected; pair, heartbeat, queued command and reply, forged reply rejection, publish, jobs, logout; permission project available={bool(projects)}")
