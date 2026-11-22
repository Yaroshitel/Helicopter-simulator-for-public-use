extends SceneTree
## Writes THIRD_PARTY_LICENSES.txt (Godot Engine licence + every third-party component compiled into the engine)
## from the engine's own embedded licence data:  godot --headless -s tools/dump_licenses.gd
func _init():
	var s := "THIRD-PARTY SOFTWARE NOTICES\n============================\n\n"
	s += "Helicopter Flying Simulator is built with the Godot Engine (%s).\n" % Engine.get_version_info().string
	s += "The Godot Engine and the components listed below are distributed inside the game executable.\n\n"
	s += "----------------------------------------------------------------------\nGodot Engine\n----------------------------------------------------------------------\n"
	s += Engine.get_license_text() + "\n\n"
	s += "----------------------------------------------------------------------\nThird-party components inside the Godot Engine\n----------------------------------------------------------------------\n"
	for comp in Engine.get_copyright_info():
		s += "\n" + str(comp.name) + "\n"
		for part in comp.parts:
			if part.files.size(): s += "  Files: " + ", ".join(part.files) + "\n"
			for c in part.copyright: s += "  Copyright: " + str(c) + "\n"
			s += "  License: " + str(part.license) + "\n"
	s += "\n----------------------------------------------------------------------\nFull licence texts\n----------------------------------------------------------------------\n"
	var li := Engine.get_license_info()
	for k in li:
		s += "\n==== " + str(k) + " ====\n\n" + str(li[k]) + "\n"
	var f := FileAccess.open("res://THIRD_PARTY_LICENSES.txt", FileAccess.WRITE); f.store_string(s); f.close()
	print("wrote ", s.length(), " chars")
	quit()
