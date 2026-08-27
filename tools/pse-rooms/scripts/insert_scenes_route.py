p = "services/reticulum/lib/ret_web/controllers/page_controller.ex"
s = open(p).read()
anchor = '  def render_for_path("/app-icon.png", _params, conn), do: conn |> render_static_asset()'
add = (
    '\n'
    '  # Serve generated Hubs scene GLBs (S40 / hubs-scene-templates)\n'
    '  def render_for_path("/scenes/" <> _ = _path, _params, conn), do: conn |> render_static_asset()'
)
assert anchor in s, "anchor not found"
if add.strip() not in s:
    s = s.replace(anchor, anchor + add, 1)
    open(p, "w").write(s)
    print("INSERTED scenes clause")
else:
    print("already present")
