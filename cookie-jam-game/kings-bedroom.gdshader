shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture :
	hint_screen_texture,
	repeat_disable,
	filter_linear;

uniform float radius : hint_range(0.5, 8.0) = 3.0;
uniform float strength : hint_range(0.0, 1.0) = 0.95;
uniform float edge_threshold : hint_range(0.001, 0.5) = 0.045;
uniform float edge_softness : hint_range(0.001, 0.5) = 0.12;
uniform float detail_preservation : hint_range(0.0, 1.0) = 0.70;
uniform float diagonal_smoothing : hint_range(0.0, 2.0) = 1.35;


float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}


vec3 sample_screen(vec2 uv) {
	return texture(screen_texture, uv).rgb;
}


float color_difference(vec3 a, vec3 b) {
	vec3 d = a - b;

	return sqrt(
		d.r * d.r * 0.299 +
		d.g * d.g * 0.587 +
		d.b * d.b * 0.114
	);
}


void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE;
	vec2 uv = SCREEN_UV;

	vec3 c = sample_screen(uv);

	vec3 n  = sample_screen(uv + vec2(0.0, -px.y));
	vec3 s  = sample_screen(uv + vec2(0.0,  px.y));
	vec3 w  = sample_screen(uv + vec2(-px.x, 0.0));
	vec3 e  = sample_screen(uv + vec2( px.x, 0.0));

	vec3 nw = sample_screen(uv + vec2(-px.x, -px.y));
	vec3 ne = sample_screen(uv + vec2( px.x, -px.y));
	vec3 sw = sample_screen(uv + vec2(-px.x,  px.y));
	vec3 se = sample_screen(uv + vec2( px.x,  px.y));


	float lc  = luma(c);

	float ln  = luma(n);
	float ls  = luma(s);
	float lw  = luma(w);
	float le  = luma(e);

	float lnw = luma(nw);
	float lne = luma(ne);
	float lsw = luma(sw);
	float lse = luma(se);


	// Sobel gradient.
	float gx =
		-lnw - 2.0 * lw - lsw +
		 lne + 2.0 * le + lse;

	float gy =
		-lnw - 2.0 * ln - lne +
		 lsw + 2.0 * ls + lse;


	vec2 gradient = vec2(gx, gy);

	float gradient_length = length(gradient);

	vec2 normal_dir;

	if (gradient_length > 0.00001) {
		normal_dir = gradient / gradient_length;
	} else {
		normal_dir = vec2(1.0, 0.0);
	}


	// Direction along the edge rather than across it.
	vec2 tangent =
		vec2(-normal_dir.y, normal_dir.x);


	// Detect strong colour boundaries too, not only luminance.
	float max_difference = 0.0;

	max_difference = max(max_difference, color_difference(c, n));
	max_difference = max(max_difference, color_difference(c, s));
	max_difference = max(max_difference, color_difference(c, w));
	max_difference = max(max_difference, color_difference(c, e));

	max_difference = max(max_difference, color_difference(c, nw));
	max_difference = max(max_difference, color_difference(c, ne));
	max_difference = max(max_difference, color_difference(c, sw));
	max_difference = max(max_difference, color_difference(c, se));


	float edge_amount =
		smoothstep(
			edge_threshold,
			edge_threshold + edge_softness,
			max_difference
		);


	// ============================================================
	// WIDE EDGE-TANGENT RECONSTRUCTION
	// ============================================================

	vec2 tangent_step =
		tangent *
		px *
		radius *
		diagonal_smoothing;


	vec3 tangent_blur = c * 0.24;

	tangent_blur +=
		sample_screen(
			uv + tangent_step * 0.25
		) * 0.17;

	tangent_blur +=
		sample_screen(
			uv - tangent_step * 0.25
		) * 0.17;

	tangent_blur +=
		sample_screen(
			uv + tangent_step * 0.50
		) * 0.12;

	tangent_blur +=
		sample_screen(
			uv - tangent_step * 0.50
		) * 0.12;

	tangent_blur +=
		sample_screen(
			uv + tangent_step * 0.85
		) * 0.09;

	tangent_blur +=
		sample_screen(
			uv - tangent_step * 0.85
		) * 0.09;


	// ============================================================
	// SUBPIXEL CROSS-EDGE ANTIALIASING
	// ============================================================

	vec2 normal_step =
		normal_dir *
		px *
		radius *
		0.45;


	vec3 side_a =
		sample_screen(
			uv + normal_step * 0.35
		);

	vec3 side_b =
		sample_screen(
			uv - normal_step * 0.35
		);

	vec3 side_c =
		sample_screen(
			uv + normal_step * 0.75
		);

	vec3 side_d =
		sample_screen(
			uv - normal_step * 0.75
		);


	vec3 cross_blend =
		c * 0.48 +
		side_a * 0.18 +
		side_b * 0.18 +
		side_c * 0.08 +
		side_d * 0.08;


	// ============================================================
	// FXAA-STYLE DIAGONAL ESTIMATE
	// ============================================================

	vec2 fx_dir;

	fx_dir.x =
		-((lnw + lne) - (lsw + lse));

	fx_dir.y =
		 ((lnw + lsw) - (lne + lse));


	float dir_reduce =
		max(
			(
				lnw +
				lne +
				lsw +
				lse
			) * 0.03125,
			0.0078125
		);


	float rcp_dir_min =
		1.0 /
		(
			min(
				abs(fx_dir.x),
				abs(fx_dir.y)
			) +
			dir_reduce
		);


	fx_dir =
		clamp(
			fx_dir * rcp_dir_min,
			vec2(-8.0),
			vec2(8.0)
		);


	fx_dir *= px;


	vec3 fx_a =
		0.5 *
		(
			sample_screen(
				uv +
				fx_dir *
				(1.0 / 3.0 - 0.5)
			)
			+
			sample_screen(
				uv +
				fx_dir *
				(2.0 / 3.0 - 0.5)
			)
		);


	vec3 fx_b =
		fx_a * 0.5 +
		0.25 *
		(
			sample_screen(
				uv + fx_dir * -0.5
			)
			+
			sample_screen(
				uv + fx_dir * 0.5
			)
		);


	float luma_min =
		min(
			lc,
			min(
				min(lnw, lne),
				min(lsw, lse)
			)
		);


	float luma_max =
		max(
			lc,
			max(
				max(lnw, lne),
				max(lsw, lse)
			)
		);


	float fx_b_luma =
		luma(fx_b);


	vec3 fx_result;

	if (
		fx_b_luma < luma_min ||
		fx_b_luma > luma_max
	) {
		fx_result = fx_a;
	} else {
		fx_result = fx_b;
	}


	// ============================================================
	// COMBINE
	// ============================================================

	vec3 reconstructed =
		tangent_blur * 0.50 +
		cross_blend * 0.20 +
		fx_result * 0.30;


	// Preserve fine internal variation.
	float local_detail =
		(
			color_difference(c, n) +
			color_difference(c, s) +
			color_difference(c, w) +
			color_difference(c, e)
		) * 0.25;


	float detail_mask =
		1.0 -
		smoothstep(
			0.02,
			0.20,
			local_detail
		);


	reconstructed =
		mix(
			reconstructed,
			c,
			detail_mask *
			detail_preservation
		);


	vec3 final_color =
		mix(
			c,
			reconstructed,
			edge_amount *
			strength
		);


	COLOR = vec4(
		final_color,
		1.0
	);
}