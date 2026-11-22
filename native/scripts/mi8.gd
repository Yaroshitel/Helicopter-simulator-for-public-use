class_name Mi8 extends HeliBase
var G8: Array = []
var pn8_vp: SubViewport
func _init(s: Sim) -> void:
	sim = s; _init_mats(); model = Node3D.new(); add_child(model)
func animate(dt: float, t: float) -> void: pass
func redraw_panels() -> void: pass
func cam_seat() -> Vector3: return Vector3(-.55, .33, -5.32)
