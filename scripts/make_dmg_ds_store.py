# DMG 창 레이아웃(.DS_Store) 생성
import base64
import subprocess
import sys

from ds_store import DSStore

WINDOW_ORIGIN = (200, 100)
WINDOW_SIZE = (660, 432)
ICON_SIZE = 128.0
TEXT_SIZE = 16.0
GRID_SPACING = 100.0
ICON_Y = 210
APP_X = 170
APPLICATIONS_X = 490
# 숨김 파일 표시 때만 보이는 볼륨 아이콘 파일의 위치(창 안 위쪽, 스크롤이 생기지 않게)
VOLUME_ICON_POS = (APPLICATIONS_X, 70)
BOOKMARK_SCRIPT = """
ObjC.import("Foundation");
function run(argv) {
    const url = $.NSURL.fileURLWithPath(argv[0]);
    const data = url.bookmarkDataWithOptionsIncludingResourceValuesForKeysRelativeToURLError(0, $(), $(), null);
    return data.base64EncodedStringWithOptions(0).js;
}
"""


class Bookmark:
    """macOS 가 만든 파일 북마크."""

    def __init__(self, path):
        output = subprocess.run(
            ["/usr/bin/osascript", "-l", "JavaScript", "-e", BOOKMARK_SCRIPT, path],
            check=True, capture_output=True, text=True,
        ).stdout
        self.data = base64.b64decode(output)

    def to_bytes(self):
        return self.data


volume = sys.argv[1]
with DSStore.open(f"{volume}/.DS_Store", "w+") as store:
    store["."]["vSrn"] = ("long", 1)
    store["."]["icvl"] = ("type", b"icnv")
    store["."]["bwsp"] = {
        "WindowBounds": "{{%d, %d}, {%d, %d}}" % (WINDOW_ORIGIN + WINDOW_SIZE),
        "ShowToolbar": False,
        "ShowSidebar": False,
        "ContainerShowSidebar": False,
        "ShowStatusBar": False,
        "ShowPathbar": False,
        "ShowTabView": False,
        "PreviewPaneVisibility": False,
    }
    store["."]["icvp"] = {
        "viewOptionsVersion": 1,
        "arrangeBy": "none",
        "iconSize": ICON_SIZE,
        "textSize": TEXT_SIZE,
        "gridSpacing": GRID_SPACING,
        "gridOffsetX": 0.0,
        "gridOffsetY": 0.0,
        "labelOnBottom": True,
        "showItemInfo": False,
        "showIconPreview": False,
        "scrollPositionX": 0.0,
        "scrollPositionY": 0.0,
        "backgroundType": 2,
        "backgroundColorRed": 1.0,
        "backgroundColorGreen": 1.0,
        "backgroundColorBlue": 1.0,
    }
    store["."]["pBBk"] = Bookmark(f"{volume}/EleDocks.app/Contents/Resources/dmg-background.tiff")
    store["EleDocks.app"]["Iloc"] = (APP_X, ICON_Y)
    store["Applications"]["Iloc"] = (APPLICATIONS_X, ICON_Y)
    store[".VolumeIcon.icns"]["Iloc"] = VOLUME_ICON_POS
