extends SceneTree
# Quick GDScript speed check for the procedural world generation.
func hash2(x: float, y: float) -> float:
	var h := sin(x*127.1+y*311.7)*43758.5453
	return h-floor(h)
func vn(x: float, y: float) -> float:
	var xi := floorf(x); var yi := floorf(y); var xf := x-xi; var yf := y-yi
	var u := xf*xf*(3-2*xf); var v := yf*yf*(3-2*yf)
	var a := hash2(xi,yi); var b := hash2(xi+1,yi); var c := hash2(xi,yi+1); var d := hash2(xi+1,yi+1)
	return a+(b-a)*u+(c-a)*v+(a-b-c+d)*u*v
func _init():
	var t := Time.get_ticks_msec(); var s := 0.0
	for i in 1000000: s += vn(i*.013, i*.007)
	print("1M vn: ", Time.get_ticks_msec()-t, " ms ", s)
	quit()
