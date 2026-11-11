# SPDX-License-Identifier: GPL-3.0-or-later
# The app icon, drawn as vectors from the same outline as the launcher icon (docs/icon.svg).
class_name Logo
extends Control

## Remote body outline, in the icon's 1024×1024 space.
const BODY_XY := [511.5, 423.5, 330.0, 423.5, 318.9, 424.0, 308.4, 425.5, 298.7, 428.0, 289.7, 431.4, 281.4, 436.0, 273.9, 441.5, 267.1, 448.1, 261.0, 455.7, 255.6, 464.4, 251.0, 474.2, 247.1, 485.1, 244.0, 497.0, 199.0, 664.0, 197.4, 672.5, 197.2, 681.0, 198.2, 689.3, 200.4, 697.3, 203.7, 704.8, 208.1, 711.8, 213.6, 718.0, 220.0, 723.4, 227.3, 727.8, 235.4, 731.2, 244.3, 733.3, 254.0, 734.0, 257.0, 733.9, 260.0, 733.7, 263.0, 733.3, 266.1, 732.7, 269.1, 732.0, 272.2, 731.1, 275.4, 730.1, 278.6, 729.0, 281.8, 727.7, 285.2, 726.2, 288.5, 724.7, 292.0, 723.0, 385.0, 663.0, 388.4, 660.6, 391.8, 658.5, 395.2, 656.7, 398.5, 655.1, 402.0, 653.7, 405.5, 652.5, 409.2, 651.5, 413.1, 650.8, 417.3, 650.2, 421.9, 649.8, 426.7, 649.6, 432.0, 649.5, 511.5, 649.5, 591.0, 649.5, 596.3, 649.6, 601.1, 649.8, 605.7, 650.2, 609.9, 650.8, 613.8, 651.5, 617.5, 652.5, 621.0, 653.7, 624.5, 655.1, 627.8, 656.7, 631.2, 658.5, 634.6, 660.6, 638.0, 663.0, 731.0, 723.0, 734.5, 724.7, 737.8, 726.2, 741.2, 727.7, 744.4, 729.0, 747.6, 730.1, 750.8, 731.1, 753.9, 732.0, 756.9, 732.7, 760.0, 733.3, 763.0, 733.7, 766.0, 733.9, 769.0, 734.0, 778.7, 733.3, 787.6, 731.2, 795.7, 727.8, 803.0, 723.4, 809.4, 718.0, 814.9, 711.8, 819.3, 704.8, 822.6, 697.3, 824.8, 689.3, 825.8, 681.0, 825.6, 672.5, 824.0, 664.0, 779.0, 497.0, 775.9, 485.1, 772.0, 474.2, 767.4, 464.4, 762.0, 455.7, 755.9, 448.1, 749.1, 441.5, 741.6, 436.0, 733.3, 431.4, 724.3, 428.0, 714.6, 425.5, 704.1, 424.0, 693.0, 423.5]

static var _body := PackedVector2Array()


static func make(px: float) -> Logo:
	var l := Logo.new()
	l.custom_minimum_size = Vector2(px, px)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _draw() -> void:
	if _body.is_empty():
		for i in range(0, BODY_XY.size(), 2):
			_body.append(Vector2(BODY_XY[i], BODY_XY[i + 1]))
	var BODY := _body
	var k := minf(size.x, size.y) / 1024.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(k, k))
	draw_circle(Vector2(511.5, 511.5), 500, Pal.VIOLET, true, -1.0, true)
	for x in [352.0, 638.0]:
		draw_rect(Rect2(x, 329, 34, 123), Pal.CREAM)
		draw_circle(Vector2(x + 17, 329), 17, Pal.CREAM, true, -1.0, true)
	draw_colored_polygon(BODY, Pal.CREAM)
	# A thin smooth edge, because filled polygons are not antialiased.
	var edge := BODY.duplicate()
	edge.append(BODY[0])
	draw_polyline(edge, Pal.CREAM, 1.0 / k, true)
	for x in [387.5, 635.5]:
		draw_circle(Vector2(x, 535.5), 55, Pal.TOY["gold"], true, -1.0, true)
		draw_circle(Vector2(x, 535.5), 22.5, Pal.LOGO_DOT, true, -1.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
