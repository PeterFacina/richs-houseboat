extends RefCounted

# Small vector badges for the front, deck lid and steering wheel.
const EMBLEMS := {
	"wagon": """<ellipse cx="60" cy="25" rx="37" ry="21" fill="#20282e" stroke="url(#chrome)" stroke-width="4"/>
		<path d="M26 16Q41 17 60 36Q79 17 94 16Q88 31 60 43Q32 31 26 16Z" fill="url(#chrome)"/>""",
	"suv": """<ellipse cx="60" cy="25" rx="56" ry="21" fill="#083978" stroke="url(#chrome)" stroke-width="4"/>
		<ellipse cx="60" cy="25" rx="50" ry="16" fill="none" stroke="#ecf5ff" stroke-width="1.1"/>
		<path d="M25 19C28 11 47 10 69 14C59 18 53 14 47 15L40 23L49 22M31 33C34 30 39 20 46 15M27 28C33 24 41 23 49 22
		M49 26C43 30 48 34 53 29C58 23 51 23 48 27M56 30L61 23L58 27Q63 21 66 24M70 26C62 33 71 34 75 27C80 19 82 15 84 15C87 16 79 28 77 31Q81 32 87 26"
		fill="none" stroke="#f7fcff" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/>""",
	"sedan": """<ellipse cx="60" cy="25" rx="40" ry="21" fill="#252e34" stroke="url(#chrome)" stroke-width="3.8"/>
		<ellipse cx="60" cy="25" rx="12" ry="20" fill="none" stroke="url(#chrome)" stroke-width="3.6"/>
		<ellipse cx="60" cy="17" rx="30" ry="9" fill="none" stroke="url(#chrome)" stroke-width="3.6"/>""",
	"convertible": """<path d="M2 19Q29 19 48 20L60 16L72 20Q91 19 118 19L101 23L111 24L90 27L96 28L75 32L60 38L45 32L24 28L30 27L9 24L19 23Z"
		fill="url(#chrome)" stroke="#596267" stroke-width="1.3"/><ellipse cx="60" cy="26" rx="14" ry="9" fill="#193548" stroke="url(#chrome)" stroke-width="2"/>
		<path d="M52 27Q60 20 68 27Q60 25 52 27Z" fill="#d8e2ea"/>""",
	"coupe": """<ellipse cx="60" cy="25" rx="50" ry="20" fill="#22282b" stroke="url(#chrome)" stroke-width="4"/>
		<path d="M37 16V34M49 16L38 25L50 34M57 16V34M65 34L75 16H77L86 34" fill="none"
		stroke="#f3f5f4" stroke-width="3.8" stroke-linecap="square" stroke-linejoin="round"/>""",
}

const REAR_NAMES := {
	"wagon": ["MAZDA5", ""], "suv": ["ESCAPE", ""], "sedan": ["TOYOTA", "COROLLA"],
	"convertible": ["SEBRING", "LIMITED"], "coupe": ["FORTE", "KOUP"],
}
const PLATES := {"wagon": "DR  0512", "suv": "DR  1313", "sedan": "DR  2005",
	"convertible": "DR  0202", "coupe": "DR  2010"}

static var textures: Dictionary = {}


static func stamp(parent: Node3D, style: String, at: Vector3, width: float, front := false) -> Sprite3D:
	if not textures.has(style):
		var svg := """<svg xmlns="http://www.w3.org/2000/svg" width="240" height="100" viewBox="0 0 120 50">
			<defs><linearGradient id="chrome" x1="0" y1="0" x2="0" y2="1" gradientUnits="objectBoundingBox">
			<stop offset="0" stop-color="#f4f8ff"/><stop offset=".52" stop-color="#9faebc"/>
			<stop offset=".74" stop-color="#eef4f8"/><stop offset="1" stop-color="#7c8c98"/>
			</linearGradient></defs>%s</svg>""" % EMBLEMS[style]
		var image := Image.new()
		if image.load_svg_from_string(svg) != OK:
			push_warning("Could not rasterize a car emblem: " + style)
			return null
		image.generate_mipmaps()
		textures[style] = ImageTexture.create_from_image(image)
	var badge := Sprite3D.new()
	badge.texture = textures[style]
	badge.pixel_size = width / badge.texture.get_width()
	badge.shaded = true
	badge.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	badge.alpha_scissor_threshold = .24
	badge.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	badge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	badge.position = at
	badge.rotation.y = PI if front else 0.0
	badge.visibility_range_end = 40.0
	parent.add_child(badge)
	return badge


static func lettering(parent: Node3D, text: String, at: Vector3, height: float,
		color: Color, front := false) -> Label3D:
	var sign := Label3D.new()
	sign.text = text
	sign.font_size = 36
	sign.pixel_size = height / 36.0
	sign.outline_size = 0
	sign.modulate = color
	sign.position = at
	sign.rotation.y = PI if front else 0.0
	sign.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	sign.alpha_scissor_threshold = .27
	sign.visibility_range_end = 33.0
	parent.add_child(sign)
	return sign
