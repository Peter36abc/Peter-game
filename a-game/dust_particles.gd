extends RefCounted


static var cached_dust_texture: Texture2D = null


static func spawn(
	tree: SceneTree,
	world_position: Vector2,
	particle_amount: int,
	strong_burst: bool,
	dust_color: Color
) -> void:
	if tree.current_scene == null:
		return

	var dust := CPUParticles2D.new()
	dust.z_index = 18
	dust.emitting = false
	dust.one_shot = true
	dust.amount = maxi(particle_amount, 1)
	dust.lifetime = 0.52 if strong_burst else 0.34
	dust.explosiveness = 0.95
	dust.direction = Vector2.UP
	dust.spread = 72.0 if strong_burst else 48.0
	dust.gravity = Vector2(0.0, 85.0)
	dust.initial_velocity_min = 24.0 if strong_burst else 9.0
	dust.initial_velocity_max = 62.0 if strong_burst else 25.0
	dust.scale_amount_min = 0.35 if strong_burst else 0.18
	dust.scale_amount_max = 0.8 if strong_burst else 0.42
	dust.texture = get_dust_texture()
	dust.color = dust_color

	var fade := Gradient.new()
	fade.set_color(0, dust_color)
	fade.set_color(1, Color(
		dust_color.r,
		dust_color.g,
		dust_color.b,
		0.0
	))
	dust.color_ramp = fade

	tree.current_scene.add_child(dust)
	dust.global_position = world_position
	dust.emitting = true

	tree.create_timer(dust.lifetime + 0.15).timeout.connect(
		dust.queue_free
	)


static func get_dust_texture() -> Texture2D:
	if cached_dust_texture != null:
		return cached_dust_texture

	var texture_size: int = 16
	var center := Vector2(texture_size, texture_size) * 0.5
	var image := Image.create(
		texture_size,
		texture_size,
		false,
		Image.FORMAT_RGBA8
	)

	for y: int in range(texture_size):
		for x: int in range(texture_size):
			var pixel_position := Vector2(x + 0.5, y + 0.5)
			var distance: float = pixel_position.distance_to(center) / center.x
			var alpha: float = clampf(1.0 - distance, 0.0, 1.0)
			alpha = alpha * alpha
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))

	cached_dust_texture = ImageTexture.create_from_image(image)
	return cached_dust_texture
