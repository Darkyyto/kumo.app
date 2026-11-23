# dmgbuild settings for the Kumo installer window.
# Build with: dmgbuild -s Scripts/dmg/settings.py -D app=/path/to/Kumo.app -D background=Scripts/dmg/background.tiff "Kumo" Kumo.dmg
import os

app = defines.get("app", "Kumo.app")  # noqa: F821 (provided by dmgbuild)

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

window_rect = ((200, 140), (660, 400))
icon_size = 112
text_size = 13
icon_locations = {
    os.path.basename(app): (180, 200),
    "Applications": (480, 200),
}
