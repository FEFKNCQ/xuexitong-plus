# -*- coding: utf-8 -*-
"""桌面版的“暂停 / 继续”。

GUI 暂停时创建一个标记文件（路径通过环境变量 CHAOXING_PAUSE_FILE 传给任务进程），
继续时删除它。任务进程在安全的位置调用 wait_if_paused()：标记存在就一直等待，
返回等待的秒数。视频任务把这段时间从“已观看时长”里扣掉，所以暂停不会让进度突然跳一大截；
正在进行的请求或答题提交会先做完再停下。命令行运行时没有这个环境变量，函数什么也不做。
"""

from __future__ import annotations

import os
import threading
import time

from api.logger import logger

ENV = "CHAOXING_PAUSE_FILE"
_POLL = 0.5
_announce = threading.Lock()
_announced = False


def is_paused() -> bool:
    path = os.environ.get(ENV)
    return bool(path) and os.path.exists(path)


def wait_if_paused() -> float:
    """Block while the pause flag exists; return the seconds spent waiting (0 if not paused)."""
    global _announced
    if not is_paused():
        return 0.0
    started = time.monotonic()
    with _announce:                       # several worker threads may wait at once; log once
        if not _announced:
            _announced = True
            logger.info("任务已暂停，点击“继续”后接着运行")
    while is_paused():
        time.sleep(_POLL)
    with _announce:
        if _announced:
            _announced = False
            logger.info("任务已继续")
    return time.monotonic() - started
