# dmgbuild settings for the single-app installer window.
# dmgbuild -s Scripts/dmg/settings-single.py -D app=/path/to/App.app -D background=Scripts/dmg/background-<name>.tiff "<Name>" <Name>.dmg
import os

app = defines.get("app", "App.app")  # noqa: F821 (provided by dmgbuild)

format = "ULFO"
files = [app]
symlinks = {"Applications": "/Applications"}
background = defines.get("background", "background.tiff")  # noqa: F821

show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
default_view = "icon-view"
arrange_by = None

window_rect = ((200, 140), (660, 440))
icon_size = 112
text_size = 13
icon_locations = {
    os.path.basename(app): (180, 300),
    "Applications": (480, 300),
}
