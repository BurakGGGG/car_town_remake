#!/usr/bin/env python3
"""Blender açmadan, `bpy` Python modülüyle (pip install bpy) dekor partisi üretir.

Kullanım:  CT_DECOR_OUT=assets/decor python tools/decor/run_bpy.py tools/decor/props_v3_salon.py [...]
      ya da: blender --background --factory-startup --python tools/decor/run_bpy.py -- <parti.py> [...]
  - kit.py başa eklenir (blender_send.py --kit ile aynı isim alanı).
  - CT_DECOR_OUT verilmezse kit.py'deki varsayılan klasör kullanılır.
  - CT_DECOR_ONLY=ad1,ad2 → yalnızca bu adlarla finish() edilen eşyalar dışa aktarılır (hızlı deneme).
"""
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
if os.environ.get("CT_DECOR_OUT"):
    os.environ["CT_DECOR_OUT"] = os.path.abspath(os.environ["CT_DECOR_OUT"])
kit = open(os.path.join(HERE, "kit.py"), encoding="utf-8").read()
only = [n for n in os.environ.get("CT_DECOR_ONLY", "").split(",") if n]
# Blender ikilisiyle çalışınca betik argümanları "--"den sonra gelir
targets = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
for target in targets:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scope: dict = {"__name__": "__decor__"}
    exec(compile(kit, "kit.py", "exec"), scope)
    if only:
        real_finish = scope["finish"]
        scope["finish"] = lambda name, export=True: real_finish(name, export and name in only)
    exec(compile(open(target, encoding="utf-8").read(), target, "exec"), scope)
