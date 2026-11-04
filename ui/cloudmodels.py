# -*- coding: utf-8 -*-
"""Cloud model providers for the AI answer source (OpenAI-compatible APIs).

高级选项 → 答题来源 → OpenAI 兼容接口: pick a common provider to fill the address, or type
any address; the provider is recognised from the host. With the API key filled in,
GET <address>/models lists the models the key can use and the user picks one.
"""

from __future__ import annotations

import json
import urllib.error
import urllib.request
from urllib.parse import urlsplit

# OpenAI-compatible base addresses (the part before /chat/completions).
PROVIDERS = [
    {"id": "deepseek", "name": "DeepSeek", "endpoint": "https://api.deepseek.com/v1", "hosts": ["deepseek.com"]},
    {"id": "dashscope", "name": "通义千问（阿里云百炼）", "endpoint": "https://dashscope.aliyuncs.com/compatible-mode/v1",
     "hosts": ["dashscope.aliyuncs.com", "dashscope-intl.aliyuncs.com"]},
    {"id": "moonshot", "name": "Kimi（月之暗面）", "endpoint": "https://api.moonshot.cn/v1", "hosts": ["moonshot.cn", "moonshot.ai"]},
    {"id": "zhipu", "name": "智谱 GLM", "endpoint": "https://open.bigmodel.cn/api/paas/v4", "hosts": ["bigmodel.cn"]},
    {"id": "volcengine", "name": "豆包（火山方舟）", "endpoint": "https://ark.cn-beijing.volces.com/api/v3", "hosts": ["volces.com"]},
    {"id": "siliconflow", "name": "硅基流动", "endpoint": "https://api.siliconflow.cn/v1", "hosts": ["siliconflow.cn", "siliconflow.com"]},
    {"id": "hunyuan", "name": "腾讯混元", "endpoint": "https://api.hunyuan.cloud.tencent.com/v1", "hosts": ["hunyuan.cloud.tencent.com"]},
    {"id": "qianfan", "name": "百度千帆", "endpoint": "https://qianfan.baidubce.com/v2", "hosts": ["baidubce.com"]},
    {"id": "openai", "name": "OpenAI", "endpoint": "https://api.openai.com/v1", "hosts": ["openai.com"]},
    {"id": "openrouter", "name": "OpenRouter", "endpoint": "https://openrouter.ai/api/v1", "hosts": ["openrouter.ai"]},
]
LOCAL_HOSTS = ("localhost", "::1")


def identify(endpoint: str) -> str:
    """Provider name for an address: a known company, 本机模型服务, or ""."""
    try:
        host = (urlsplit((endpoint or "").strip()).hostname or "").lower()
    except ValueError:
        return ""
    if not host:
        return ""
    if host in LOCAL_HOSTS or host.startswith("127."):
        return "本机模型服务"
    for provider in PROVIDERS:
        if any(host == h or host.endswith("." + h) for h in provider["hosts"]):
            return provider["name"]
    return ""


class ModelListError(RuntimeError):
    pass


def _opener(proxy: str):
    if proxy.strip():
        return urllib.request.build_opener(urllib.request.ProxyHandler({"http": proxy.strip(), "https": proxy.strip()}))
    return urllib.request.build_opener()


def list_models(endpoint: str, key: str, proxy: str = "", timeout: float = 15) -> list[str]:
    """Model ids the key can use: GET <endpoint>/models (OpenAI format). Raises ModelListError."""
    base = (endpoint or "").strip().rstrip("/")
    if not base.lower().startswith(("http://", "https://")):
        raise ModelListError("请先填写以 http:// 或 https:// 开头的接口地址")
    host = (urlsplit(base).hostname or "").lower()
    local = host in LOCAL_HOSTS or host.startswith("127.")
    if not key.strip() and not local:
        raise ModelListError("请先填写 API Key")
    headers = {"Accept": "application/json", "User-Agent": "XueXiTong-Plus"}
    if key.strip():
        headers["Authorization"] = f"Bearer {key.strip()}"
    request = urllib.request.Request(base + "/models", headers=headers)
    try:
        opener = urllib.request.build_opener(urllib.request.ProxyHandler({})) if local else _opener(proxy)
        with opener.open(request, timeout=timeout) as resp:  # noqa: S310 - address entered by the user
            data = json.loads(resp.read(4 * 1024 * 1024).decode("utf-8", errors="replace") or "{}")
    except urllib.error.HTTPError as exc:
        if exc.code in (401, 403):
            raise ModelListError(f"API Key 不正确或没有权限（{exc.code}）") from exc
        if exc.code == 404:
            raise ModelListError("这个服务不提供模型列表，请手动填写模型名称（地址通常以 /v1 结尾）") from exc
        raise ModelListError(f"获取模型列表失败（HTTP {exc.code}）") from exc
    except (urllib.error.URLError, TimeoutError, OSError) as exc:
        reason = getattr(exc, "reason", exc)
        raise ModelListError(f"连不上 {base}：{reason}") from exc
    except ValueError as exc:
        raise ModelListError("返回内容不是模型列表，请检查接口地址") from exc
    items = data.get("data") if isinstance(data, dict) else None
    if not isinstance(items, list):
        items = data.get("models") if isinstance(data, dict) else None
    names = []
    for item in items if isinstance(items, list) else []:
        name = str(item.get("id") or item.get("name") or "").strip() if isinstance(item, dict) else ""
        if name and name not in names:
            names.append(name)
    if not names:
        raise ModelListError("服务没有返回任何模型，请手动填写模型名称")
    return sorted(names, key=str.lower)
