extends Control
## Start-up and self-updater.
##
## The downloaded app ("shell") contains a complete copy of the game, so it always runs offline. On start it asks
## GitHub Releases whether a newer build exists. Updates come as two packs:
##   game.pck  - the mechanics: flight model, cockpits, UI, sound (small, changes often)
##   world.pck - the valley: terrain data and the world builder (downloaded only when the world itself changed)
## Downloaded packs live in user://update/. The shell then relaunches itself with --main-pack game.pck; that
## instance adds the world from world.pck (or from the shell's own copy if the world did not change).

const REPO := "Yaroshitel/Helicopter-simulator-for-public-use"
var BASE := "https://github.com/" + REPO + "/releases/latest/download/"
const PAGE := "https://github.com/" + REPO + "/releases/latest"
const DIR := "user://update/"
const MAIN := "res://main.tscn"

var me := {}           # this running build: {build, world, engine}
var st := {}           # update state saved in user://update/state.json
var from_pack := false
var man := {}          # manifest of the latest release
var need: Array = []   # files still to download
var http: HTTPRequest
var title: Label; var status: Label; var bar: ProgressBar; var buttons: HBoxContainer

static func engine_ver() -> String:
	var v := Engine.get_version_info()
	return "%d.%d.%d" % [v.major, v.minor, v.patch]

static func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if d is Dictionary else {}

func save_state() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var f := FileAccess.open(DIR + "state.json", FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(st, "  "))

func _ready() -> void:
	me = read_json("res://version.json")
	if me.is_empty(): me = {build = 0, world = "dev", engine = engine_ver()}
	st = read_json(DIR + "state.json")
	from_pack = OS.get_environment("HELISIM_FROM_UPDATE") == "1"   # set by the shell when it relaunches onto game.pck
	if not from_pack:
		st.shell_build = me.build; st.shell_world = me.world; save_state()
	else:
		st.erase("tries"); save_state()   # the downloaded game started: it works
	_build_ui()
	var test_url := OS.get_environment("HELISIM_UPDATE_URL")   # testing: use a local server instead of GitHub
	if test_url != "": BASE = test_url
	var quiet := DisplayServer.get_name() == "headless" or OS.get_cmdline_user_args().size() > 0 or from_pack or OS.has_feature("editor")
	if test_url != "" and not from_pack: quiet = false
	if quiet:
		proceed.call_deferred()
		return
	status.text = "Checking for updates…"
	http = HTTPRequest.new(); http.timeout = 6.0; add_child(http)
	http.request_completed.connect(_on_manifest)
	if http.request(BASE + "manifest.json") != OK: proceed()

## the newest build already on this computer
func local_build() -> int:
	var b := int(me.build)
	if FileAccess.file_exists(DIR + "game.pck") and st.get("engine", "") == engine_ver(): b = maxi(b, int(st.get("build", -1)))
	return b

func have_world(w: String) -> bool:
	return w == str(st.get("shell_world", me.world)) or (FileAccess.file_exists(DIR + "world.pck") and str(st.get("world", "")) == w)

func _on_manifest(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		proceed(); return
	var m = JSON.parse_string(body.get_string_from_utf8())
	if not (m is Dictionary) or not m.has("build"):
		proceed(); return
	man = m
	if int(man.build) <= local_build():
		proceed(); return
	if str(man.get("engine", "")) != engine_ver():
		title.text = "Build %d is out" % int(man.build)
		status.text = "This one needs a fresh download (the game engine was upgraded).\nYour current version still works."
		_button("Open download page", func(): OS.shell_open(PAGE); proceed())
		_button("Play current version", proceed)
		return
	need = ["game.pck"]
	if not have_world(str(man.world)): need.append("world.pck")
	var mb := 0.0
	for f in need: mb += float(man.files[f].size) / 1048576.0
	title.text = "Update available — build %d" % int(man.build)
	var notes := str(man.get("notes", "")).strip_edges()
	status.text = ("%s\n\n" % notes.left(400) if notes != "" else "") + "Download %.1f MB%s?" % [mb, "" if need.size() == 1 else " (includes a new world)"]
	_button("Update", _download_next)
	_button("Not now", proceed)
	if DisplayServer.get_name() == "headless": _download_next()   # unattended test run

func _download_next() -> void:
	_clear_buttons()
	if need.is_empty():
		_installed(); return
	var f: String = need[0]
	title.text = "Downloading build %d" % int(man.build)
	status.text = f
	DirAccess.make_dir_recursive_absolute(DIR)
	if http.request_completed.is_connected(_on_manifest): http.request_completed.disconnect(_on_manifest)
	if not http.request_completed.is_connected(_on_file): http.request_completed.connect(_on_file)
	http.timeout = 0.0; http.download_file = DIR + f + ".part"
	if http.request(BASE + f) != OK: _fail("Could not start the download.")

func _process(_dt: float) -> void:
	if http and http.download_file != "" and http.get_body_size() > 0:
		bar.visible = true; bar.value = 100.0 * http.get_downloaded_bytes() / http.get_body_size()

func _on_file(result: int, code: int, _h: PackedStringArray, _b: PackedByteArray) -> void:
	var f: String = need[0]; var part := DIR + f + ".part"
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_fail("Download failed (%s)." % ("HTTP %d" % code if result == HTTPRequest.RESULT_SUCCESS else "network error")); return
	if FileAccess.get_sha256(part) != str(man.files[f].sha256):
		DirAccess.remove_absolute(part); _fail("The download was damaged (checksum mismatch)."); return
	DirAccess.remove_absolute(DIR + f)
	DirAccess.rename_absolute(part, DIR + f)
	if f == "world.pck": st.world = str(man.world); save_state()
	need.pop_front()
	_download_next()

func _installed() -> void:
	st.build = int(man.build); st.engine = engine_ver(); st.erase("tries"); save_state()
	http.download_file = ""; bar.visible = false
	title.text = "Updated to build %d" % int(man.build); status.text = "Starting…"
	proceed()

func _fail(msg: String) -> void:
	http.download_file = ""; bar.visible = false
	title.text = "Update failed"; status.text = msg + "\nYou can play the version you have."
	_button("Try again", func(): _download_next())
	_button("Play current version", proceed)

## start the best available game: relaunch onto a downloaded build, or run what is loaded now
func proceed() -> void:
	_clear_buttons()
	if not from_pack and FileAccess.file_exists(DIR + "game.pck") and st.get("engine", "") == engine_ver() and int(st.get("build", -1)) > int(me.build):
		var tries := int(st.get("tries", 0))
		if tries < 2:   # if the downloaded build fails to start twice, fall back to the built-in one
			st.tries = tries + 1; save_state()
			var args := PackedStringArray(["--main-pack", ProjectSettings.globalize_path(DIR + "game.pck")])
			if DisplayServer.get_name() == "headless": args.insert(0, "--headless")
			var ua := OS.get_cmdline_user_args()
			if ua.size(): args.append("--"); args.append_array(ua)
			OS.set_environment("HELISIM_FROM_UPDATE", "1")
			if OS.create_process(OS.get_executable_path(), args) > 0:
				get_tree().quit(); return
	if from_pack: _mount_world()
	if not FileAccess.file_exists("res://baked/height.bin"):
		title.text = "World data missing"
		status.text = "This copy of the game cannot find its world. Please download the full game again."
		_button("Open download page", func(): OS.shell_open(PAGE))
		_button("Quit", func(): get_tree().quit())
		if DisplayServer.get_name() == "headless": printerr("[boot] world data missing"); get_tree().quit(1)
		return
	print("[boot] starting build %s (%s)" % [str(me.build), "downloaded" if from_pack else "built-in"])
	get_tree().change_scene_to_file.call_deferred(MAIN)

## the world files are not part of game.pck: add them without replacing any of the game's own files
func _mount_world() -> void:
	if FileAccess.file_exists(DIR + "world.pck") and str(st.get("world", "")) == str(me.world):
		ProjectSettings.load_resource_pack(DIR + "world.pck", false)
	var sp := shell_pack()
	if sp != "": ProjectSettings.load_resource_pack(sp, false)
	if FileAccess.file_exists(DIR + "world.pck"):   # last resort: an older downloaded world beats no world
		ProjectSettings.load_resource_pack(DIR + "world.pck", false)

## where the shell keeps its built-in copy of the game: next to the exe, in the macOS bundle, or embedded in the exe
static func shell_pack() -> String:
	var exe := OS.get_executable_path(); var d := exe.get_base_dir()
	if FileAccess.file_exists(exe.get_basename() + ".pck"): return exe.get_basename() + ".pck"
	var res := d.path_join("../Resources")
	if DirAccess.dir_exists_absolute(res):
		for f in DirAccess.get_files_at(res):
			if f.get_extension() == "pck": return res.path_join(f)
	return exe

# ---------------------------------------------------------------- UI
func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new(); bg.color = Color(.06, .08, .1); bg.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(bg)
	var c := CenterContainer.new(); c.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(c)
	var v := VBoxContainer.new(); v.custom_minimum_size = Vector2(520, 0); v.add_theme_constant_override("separation", 14); c.add_child(v)
	var h := Label.new(); h.text = "Helicopter Flying Simulator"; h.add_theme_font_size_override("font_size", 30); h.add_theme_color_override("font_color", Color("#ffd166")); v.add_child(h)
	title = Label.new(); title.add_theme_font_size_override("font_size", 20); v.add_child(title)
	status = Label.new(); status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; status.add_theme_color_override("font_color", Color(.8, .85, .9)); v.add_child(status)
	bar = ProgressBar.new(); bar.visible = false; bar.custom_minimum_size.y = 18; v.add_child(bar)
	buttons = HBoxContainer.new(); buttons.add_theme_constant_override("separation", 12); v.add_child(buttons)
	var ver := Label.new(); ver.text = "build %s · %s" % [str(me.build), "updated copy" if from_pack else "built-in copy"]
	ver.add_theme_font_size_override("font_size", 11); ver.add_theme_color_override("font_color", Color(.5, .55, .6)); v.add_child(ver)

func _button(t: String, f: Callable) -> void:
	var b := Button.new(); b.text = t; b.custom_minimum_size = Vector2(160, 36); b.pressed.connect(f); buttons.add_child(b)

func _clear_buttons() -> void:
	if buttons:
		for b in buttons.get_children(): b.queue_free()
