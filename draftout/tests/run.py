"""Run from any directory: python tests/run.py. Requires pip install lupa."""
import os
import json
from pathlib import Path
from lupa.lua51 import LuaRuntime, lua_type

os.chdir(Path(__file__).resolve().parents[1])
# Discover Lua specs so new UI/regression checks cannot be silently omitted.
for spec in sorted(Path('tests').glob('*_spec.lua')):
    runtime = LuaRuntime(unpack_returned_tuples=True)
    def to_python(value):
        if lua_type(value) != 'table':
            return value
        items = dict(value.items())
        if items and set(items) == set(range(1, len(items)+1)):
            return [to_python(items[i]) for i in range(1, len(items)+1)]
        return {k: to_python(v) for k, v in items.items()}
    runtime.globals().python_json_encode = lambda value: json.dumps(to_python(value))
    runtime.globals().python_json_decode = lambda value: runtime.table_from(json.loads(value), recursive=True)
    runtime.execute('package.preload.json = function() return {encode=python_json_encode, decode=python_json_decode} end')
    runtime.execute(Path(spec).read_text())
