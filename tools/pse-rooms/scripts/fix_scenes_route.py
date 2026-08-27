import os
# 1) fix the clause path
p = "services/reticulum/lib/ret_web/controllers/page_controller.ex"
s = open(p).read()
old = '  def render_for_path("/scenes/" <> _ = _path, _params, conn), do: conn |> render_static_asset()'
new = '  def render_for_path("/generated-scenes/" <> _ = _path, _params, conn), do: conn |> render_static_asset()'
assert old in s, "old clause not found"
s = s.replace(old, new, 1)
open(p, "w").write(s)
print("clause path -> /generated-scenes/")
