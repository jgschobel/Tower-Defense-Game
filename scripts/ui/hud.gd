extends CanvasLayer

## In-game HUD showing gold, lives, wave info, and tower shop.

signal tower_selected_for_placement(tower_data: Resource)
signal placement_cancelled
signal next_wave_requested
signal pause_requested
signal auto_wave_toggled(enabled: bool)

@onready var gold_icon: TextureRect = $TopBar/HBox/GoldIcon
@onready var gold_label: Label = $TopBar/HBox/GoldLabel
@onready var lives_label: Label = $TopBar/HBox/LivesLabel
@onready var wave_label: Label = $TopBar/HBox/WaveLabel
@onready var enemy_count_label: Label = $TopBar/HBox/EnemyCountLabel
@onready var speed_button: Button = $TopBar/HBox/SpeedButton
@onready var pause_button: Button = $TopBar/HBox/PauseButton
@onready var next_wave_button: Button = $BottomPanel/BottomBar/ButtonRow/NextWaveButton
@onready var cancel_button: Button = $BottomPanel/BottomBar/ButtonRow/CancelButton
@onready var tower_shop: VBoxContainer = $SideShop/SideShopVBox/ShopScroll/TowerShop
@onready var shop_scroll: ScrollContainer = $SideShop/SideShopVBox/ShopScroll
@onready var tower_info: PanelContainer = $TowerInfo

var tower_data_list: Array = []
var _cost_labels: Array = []
var _game_speed: float = 1.0
var _selected_tower: BaseTower = null
var _is_placing: bool = false
var _placing_button: Button = null

var _shop_tower_ids: Array = ["basic", "sniper", "splash", "cordula", "slow", "farm", "support", "joe", "justus", "seve"]

# Side-shop collapse state + responsive sizing. `shop_collapsed` persists
# across one session only (not saved). Shop width is computed per-viewport
# in _apply_safe_area / _refresh_side_shop_layout.
var shop_collapsed: bool = false
var _shop_width: float = 152.0
var _shop_collapse_tween: Tween = null


func _ready() -> void:
	CurrencyManager.gold_changed.connect(_on_gold_changed)
	GameManager.lives_changed.connect(_on_lives_changed)
	if ComboTracker:
		ComboTracker.combo_changed.connect(_on_combo_changed)

	_on_gold_changed(CurrencyManager.gold)
	_on_lives_changed(GameManager.lives)
	# Bump top-bar text size for mobile readability — defaults were ~14px
	# on a 1280×720 phone screen, hard to read at arm's length.
	for lbl in [gold_label, lives_label, wave_label, enemy_count_label]:
		if lbl:
			lbl.add_theme_font_size_override("font_size", 22)
			lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
			lbl.add_theme_constant_override("outline_size", 3)
	if gold_label:
		gold_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.25))
	# Shop section header — match the gold language used across the HUD
	var shop_header: Label = get_node_or_null("SideShop/SideShopVBox/ShopHeader")
	if shop_header:
		shop_header.add_theme_font_size_override("font_size", 18)
		shop_header.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		shop_header.add_theme_color_override("font_outline_color", Color(0.15, 0.05, 0))
		shop_header.add_theme_constant_override("outline_size", 3)
		shop_header.text = "🏰 TÜRM"
	_populate_tower_shop()
	_apply_safe_area()
	_build_shop_collapse_handle()
	_start_threat_watcher()
	# Re-apply layout if the viewport resizes (orientation change, window
	# resize on desktop / web). Both events can fire; idempotent refresh.
	get_tree().root.size_changed.connect(_on_viewport_resized)

	if tower_info:
		tower_info.visible = false
		# Style the panel — was using default theme transparency that
		# let the playfield show through and made stats hard to read.
		var ti_sb := StyleBoxFlat.new()
		ti_sb.bg_color = Color(0.08, 0.07, 0.06, 0.96)
		ti_sb.border_color = Color(0.95, 0.78, 0.18, 0.85)
		ti_sb.border_width_left = 2
		ti_sb.border_width_right = 2
		ti_sb.border_width_top = 2
		ti_sb.border_width_bottom = 2
		ti_sb.corner_radius_top_left = 12
		ti_sb.corner_radius_top_right = 12
		ti_sb.corner_radius_bottom_left = 12
		ti_sb.corner_radius_bottom_right = 12
		ti_sb.content_margin_left = 16
		ti_sb.content_margin_right = 16
		ti_sb.content_margin_top = 12
		ti_sb.content_margin_bottom = 12
		tower_info.add_theme_stylebox_override("panel", ti_sb)
		# Style the sell + close buttons consistently with the rest of
		# the gold-warm UI language. Sell: warm orange-red. Close: neutral.
		var sell_btn: Button = tower_info.get_node_or_null("VBox/HBox/SellButton")
		if sell_btn:
			_apply_tower_info_button_style(sell_btn, Color(0.85, 0.45, 0.20))
		var close_btn: Button = tower_info.get_node_or_null("VBox/CloseButton")
		if close_btn:
			_apply_tower_info_button_style(close_btn, Color(0.55, 0.50, 0.45))
	cancel_button.visible = false


func _apply_tower_info_button_style(btn: Button, accent: Color) -> void:
	var base := StyleBoxFlat.new()
	base.bg_color = Color(0.16, 0.13, 0.10, 1.0)
	base.border_color = accent
	base.border_width_left = 2
	base.border_width_right = 1
	base.border_width_top = 1
	base.border_width_bottom = 1
	base.corner_radius_top_left = 6
	base.corner_radius_top_right = 6
	base.corner_radius_bottom_left = 6
	base.corner_radius_bottom_right = 6
	base.content_margin_left = 10
	base.content_margin_right = 10
	base.content_margin_top = 4
	base.content_margin_bottom = 4
	var hover := base.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.28, 0.22, 0.14, 1.0)
	hover.border_color = Color(accent.r * 1.2, accent.g * 1.2, accent.b * 1.2, 1.0)
	var pressed := base.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.40, 0.30, 0.16, 1.0)
	btn.add_theme_stylebox_override("normal", base)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
	btn.add_theme_font_size_override("font_size", 16)


func _start_threat_watcher() -> void:
	# ROADMAP #5: was a 0.5s poll; now driven by enemy spawn/death events.
	# Threat badges refresh on wave_manager.enemies_remaining_changed
	# (wired by game_level). Boss HP bar keeps a 0.25s timer because it
	# needs smooth HP updates while bosses are being damaged.
	if has_node("BossHPTimer"):
		return
	var t := Timer.new()
	t.name = "BossHPTimer"
	t.wait_time = 0.25
	t.autostart = true
	t.one_shot = false
	add_child(t)
	t.timeout.connect(_refresh_boss_hpbar_live)


func on_enemy_count_changed() -> void:
	# Called from game_level when wave_manager emits
	# enemies_remaining_changed. Re-scans the enemy group once per event
	# instead of every 0.5s. Same _refresh_threat_badges body, renamed
	# so the poll-driven and event-driven paths are obvious.
	_refresh_threat_badges()


func _refresh_threat_badges() -> void:
	var has_healer: bool = false
	var boss_refs: Array = []
	for n in get_tree().get_nodes_in_group("enemies"):
		var e := n as BaseEnemy
		if e == null or e.is_dead or not e.data:
			continue
		match e.data.id:
			"healer":
				has_healer = true
			"boss":
				boss_refs.append(e)
	_set_threat_badge("HealerBadge", has_healer, "+ HEAL", Color(0.4, 1.0, 0.5))
	_set_threat_badge("BossBadge", not boss_refs.is_empty(), "⚠ BOSS", Color(1.0, 0.35, 0.25))
	_refresh_boss_hpbar(boss_refs)


func _refresh_boss_hpbar_live() -> void:
	# Faster-cadence tick just for the boss HP bar (bosses take time to
	# kill, HP bar needs smooth updates). Threat badges don't need this.
	var boss_refs: Array = []
	for n in get_tree().get_nodes_in_group("enemies"):
		var e := n as BaseEnemy
		if e == null or e.is_dead or not e.data:
			continue
		if e.data.id == "boss":
			boss_refs.append(e)
	_refresh_boss_hpbar(boss_refs)


func _refresh_boss_hpbar(boss_refs: Array) -> void:
	# Prominent boss HP bar anchored top-center below the TopBar. Shows
	# pooled HP of all active bosses (for multi-boss waves like L5-10).
	# Disappears cleanly when no boss is alive.
	var existing: Control = get_node_or_null("BossHPBar") as Control
	if boss_refs.is_empty():
		if existing:
			existing.queue_free()
		return
	var total_max: float = 0.0
	var total_cur: float = 0.0
	for e in boss_refs:
		# Guard: a boss in mid-death-tween stays in the enemies group for
		# ~0.35s; skip so we don't sum NaN/0 into the bar. Audit P1 #7.
		if not is_instance_valid(e) or e.is_dead:
			continue
		total_max += e.max_health
		total_cur += maxf(0.0, e.health)
	if total_max <= 0.0:
		# All bosses mid-death — skip update this tick
		return
	if existing == null:
		existing = _build_boss_hpbar()
		add_child(existing)
	var bar: ProgressBar = existing.get_node_or_null("VBox/Bar") as ProgressBar
	var label: Label = existing.get_node_or_null("VBox/Label") as Label
	if bar:
		bar.max_value = total_max
		bar.value = total_cur
	if label:
		if boss_refs.size() > 1:
			label.text = "DE M-TÜÜFEL × %d" % boss_refs.size()
		else:
			label.text = "DE M-TÜÜFEL"


func _build_boss_hpbar() -> Control:
	var wrap := PanelContainer.new()
	wrap.name = "BossHPBar"
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Responsive anchoring — 20% left / 80% right instead of hard-coded
	# 340px insets so narrower viewports don't produce a negative-width
	# bar (audit P1 #6). Top offset still uses a pixel for now; the
	# safe-area pass will replace that in a follow-up.
	wrap.anchor_left = 0.2
	wrap.anchor_top = 0.0
	wrap.anchor_right = 0.8
	wrap.anchor_bottom = 0.0
	wrap.offset_left = 0.0
	# Respect the top safe-area inset — on a notched phone TopBar lives
	# at `_inset_top + 65`, so the HP bar below it must be pushed down
	# accordingly. Agent-audit BUG #10.
	wrap.offset_top = _inset_top + 72.0
	wrap.offset_right = 0.0
	wrap.offset_bottom = _inset_top + 130.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.15, 0.05, 0.05, 0.85)
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_color = Color(1, 0.3, 0.2, 1)
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	wrap.add_theme_stylebox_override("panel", sb)
	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 2)
	var label := Label.new()
	label.name = "Label"
	label.text = "DE M-TÜÜFEL"
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(1, 0.75, 0.6))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 2)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)
	var bar := ProgressBar.new()
	bar.name = "Bar"
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 16)
	bar.modulate = Color(1, 0.3, 0.25, 1)
	vbox.add_child(bar)
	wrap.add_child(vbox)
	return wrap


func _set_threat_badge(badge_name: String, visible_flag: bool, text: String, color: Color) -> void:
	var top_bar: Node = get_node_or_null("TopBar")
	if top_bar == null:
		return
	var existing: Label = top_bar.get_node_or_null(badge_name) as Label
	if not visible_flag:
		if existing:
			existing.queue_free()
		return
	if existing:
		return  # already showing, let the pulse tween keep running
	var lbl := Label.new()
	lbl.name = badge_name
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.anchors_preset = Control.PRESET_TOP_RIGHT
	lbl.anchor_left = 1.0
	lbl.anchor_right = 1.0
	lbl.offset_left = -130.0
	# Stagger vertical position so two badges don't overlap:
	# boss below the top bar, healer further below.
	if badge_name == "HealerBadge":
		lbl.offset_top = 70.0
	else:
		lbl.offset_top = 92.0
	lbl.offset_right = -12.0
	lbl.offset_bottom = lbl.offset_top + 20.0
	top_bar.add_child(lbl)
	# Gentle pulse so the warning is noticeable without being annoying
	var pulse := lbl.create_tween().set_loops()
	pulse.tween_property(lbl, "modulate:a", 0.5, 0.6)
	pulse.tween_property(lbl, "modulate:a", 1.0, 0.6)


var _safe_area_applied: bool = false
var _inset_right: float = 0.0
var _inset_top: float = 0.0

func _apply_safe_area() -> void:
	# Idempotent guard: without this, running twice (rotation, re-init)
	# stacks offsets and pushes the UI off-screen. Audit #2.
	if _safe_area_applied:
		return
	var safe_rect := DisplayServer.get_display_safe_area()
	var screen_size := DisplayServer.window_get_size()
	var inset_left := safe_rect.position.x
	var inset_right := screen_size.x - (safe_rect.position.x + safe_rect.size.x)
	var inset_top := safe_rect.position.y
	var inset_bottom := screen_size.y - (safe_rect.position.y + safe_rect.size.y)
	_inset_right = float(inset_right)
	_inset_top = float(inset_top)
	# Responsive shop width — scales with viewport width. Clamps between
	# 136px (minimum readable) and 190px (avoid dominating ultra-wide).
	# Step 3 goal: narrow phones get a narrower shop; iPads get wider.
	var vp_w: float = float(screen_size.x if screen_size.x > 0 else 1280)
	_shop_width = clampf(vp_w * 0.135, 136.0, 190.0)
	if inset_left == 0 and inset_right == 0 and inset_top == 0 and inset_bottom == 0:
		_refresh_side_shop_layout()
		_safe_area_applied = true
		return
	var top_bar: PanelContainer = $TopBar
	top_bar.offset_left = float(inset_left)
	top_bar.offset_right = float(-inset_right)
	top_bar.offset_top = float(inset_top)
	top_bar.offset_bottom = float(inset_top) + 65.0
	# BottomPanel shrunk to just the button row; the tower shop moved
	# to the SideShop widget (anchored right-center).
	var bottom_panel: PanelContainer = $BottomPanel
	bottom_panel.offset_left = float(inset_left)
	bottom_panel.offset_top = -76.0 - float(inset_bottom)
	bottom_panel.offset_bottom = float(-inset_bottom)
	_refresh_side_shop_layout()
	_safe_area_applied = true


func _refresh_side_shop_layout() -> void:
	# Applies the current `shop_collapsed` state + computed `_shop_width`
	# to the SideShop panel and the BottomPanel right-offset. Called on
	# safe-area apply, collapse toggle, and responsive-resize events.
	var side_shop: PanelContainer = $SideShop if has_node("SideShop") else null
	if side_shop == null:
		return
	var visible_w: float = 18.0 if shop_collapsed else _shop_width
	# SideShop uses anchor_right=1.0, so offsets are relative to the right edge.
	# When collapsed we push it mostly off-screen (leaving an 18px handle).
	if shop_collapsed:
		side_shop.offset_left = -18.0 - _inset_right
		side_shop.offset_right = 0.0 - _inset_right
	else:
		side_shop.offset_left = -_shop_width - 8.0 - _inset_right
		side_shop.offset_right = -8.0 - _inset_right
	# Reserve right-edge space on BottomPanel so the next-wave button
	# doesn't underlap the shop.
	if has_node("BottomPanel"):
		var bottom_panel: PanelContainer = $BottomPanel
		var reserve: float = visible_w + 16.0
		bottom_panel.offset_right = -reserve - _inset_right
	_refresh_shop_toggle_position()


func _build_shop_collapse_handle() -> void:
	# Toggle MUST be a sibling of SideShop, not a child. SideShop is a
	# PanelContainer; containers force-fit all children to their own rect,
	# so custom offsets get ignored and the toggle ends up stretched over
	# the whole shop — blocking every click on the tower rows because the
	# toggle has MOUSE_FILTER_STOP. Parenting to HUD (CanvasLayer) keeps
	# the toggle independent so the anchors/offsets stick.
	if not has_node("SideShop"):
		return
	if has_node("ShopToggle"):
		return
	var toggle := Button.new()
	toggle.name = "ShopToggle"
	toggle.text = ">"
	toggle.custom_minimum_size = Vector2(32, 48)
	toggle.add_theme_font_size_override("font_size", 18)
	toggle.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	toggle.mouse_filter = Control.MOUSE_FILTER_STOP
	# Anchor to right edge + vertical center, mirroring SideShop so the
	# toggle hugs its left side. Actual offsets get set per-layout in
	# _refresh_shop_toggle_position().
	toggle.anchor_left = 1.0
	toggle.anchor_right = 1.0
	toggle.anchor_top = 0.5
	toggle.anchor_bottom = 0.5
	add_child(toggle)
	toggle.pressed.connect(_toggle_shop_collapse)
	_refresh_shop_toggle_position()


func _refresh_shop_toggle_position() -> void:
	if not has_node("ShopToggle"):
		return
	var toggle: Button = $ShopToggle
	# Sit 4px LEFT of the SideShop's left edge, 32px wide. SideShop's
	# left-edge offset mirrors what's computed in _refresh_side_shop_layout.
	var shop_left: float
	if shop_collapsed:
		shop_left = -18.0 - _inset_right
	else:
		shop_left = -_shop_width - 8.0 - _inset_right
	toggle.offset_right = shop_left - 4.0
	toggle.offset_left = shop_left - 36.0
	# Vertical: SideShop is centered (anchor_top/bottom = 0.5, offset_top = -260).
	# Put the toggle 8px below its top.
	toggle.offset_top = -252.0
	toggle.offset_bottom = -200.0


func _toggle_shop_collapse() -> void:
	shop_collapsed = not shop_collapsed
	SfxManager.play_click()
	# Hide the scroll contents entirely when collapsed — saves layout +
	# render cost for the 5 rows that would otherwise sit behind a 32px
	# strip with 0 visible width.
	if has_node("SideShop/SideShopVBox/ShopScroll"):
		var scroll: Control = $SideShop/SideShopVBox/ShopScroll
		scroll.visible = not shop_collapsed
	if has_node("SideShop/SideShopVBox/ShopHeader"):
		var header: Control = $SideShop/SideShopVBox/ShopHeader
		header.visible = not shop_collapsed
	# Kill any in-flight slide tween so rapid taps don't fight.
	if _shop_collapse_tween and _shop_collapse_tween.is_valid():
		_shop_collapse_tween.kill()
		_shop_collapse_tween = null
	# Update the arrow glyph to point where the shop WILL go on next tap.
	var toggle: Button = $ShopToggle if has_node("ShopToggle") else null
	if toggle:
		toggle.text = "<" if shop_collapsed else ">"
	# Animate the offsets instead of snapping so the slide feels
	# responsive. Compute target offsets same as _refresh_side_shop_layout.
	var side_shop: PanelContainer = $SideShop
	var bottom_panel: PanelContainer = $BottomPanel
	var target_left: float
	var target_right: float
	var bp_target_right: float
	if shop_collapsed:
		target_left = -18.0 - _inset_right
		target_right = 0.0 - _inset_right
		bp_target_right = -34.0 - _inset_right
	else:
		target_left = -_shop_width - 8.0 - _inset_right
		target_right = -8.0 - _inset_right
		bp_target_right = -(_shop_width + 16.0) - _inset_right
	_shop_collapse_tween = create_tween().set_parallel(true)
	_shop_collapse_tween.tween_property(side_shop, "offset_left", target_left, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_shop_collapse_tween.tween_property(side_shop, "offset_right", target_right, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_shop_collapse_tween.tween_property(bottom_panel, "offset_right", bp_target_right, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# Toggle hugs the shop's left edge — tween its offsets too so it tracks
	# the slide instead of jumping at the end.
	if toggle:
		var toggle_right: float = target_left - 4.0
		var toggle_left: float = target_left - 36.0
		_shop_collapse_tween.tween_property(toggle, "offset_right", toggle_right, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_shop_collapse_tween.tween_property(toggle, "offset_left", toggle_left, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _on_viewport_resized() -> void:
	# Recompute shop width for the new viewport size and re-apply layout.
	# Clears the safe-area-applied flag so insets are recomputed too.
	_safe_area_applied = false
	_apply_safe_area()
	# Tear down live overlays that depend on the stale insets — they'll
	# be rebuilt on the next threat-watcher tick / next-wave button show.
	# Agent-audit BUG #9.
	var existing_boss: Control = get_node_or_null("BossHPBar") as Control
	if existing_boss:
		existing_boss.queue_free()
	for badge_name in ["HealerBadge", "BossBadge"]:
		var b: Node = get_node_or_null("TopBar/%s" % badge_name)
		if b:
			b.queue_free()
	var existing_preview: Node = get_node_or_null("NextWavePreview")
	if existing_preview:
		existing_preview.queue_free()


func _populate_tower_shop() -> void:
	# Idempotency guard — if _ready somehow re-fires (scene reparenting,
	# hot-reload, autoload quirks), avoid duplicating the shop entries.
	# Same class of fix as the safe-area audit finding.
	if not tower_data_list.is_empty():
		return
	for tower_id in _shop_tower_ids:
		var data_path := "res://resources/tower_data/%s.tres" % tower_id
		if not ResourceLoader.exists(data_path):
			continue
		var td: TowerData = load(data_path)
		tower_data_list.append(td)

		# Tower unlock gating (ROADMAP #49). Locked rows render disabled
		# with a padlock overlay + required-stars hint instead of hiding,
		# so players know what's coming.
		var is_locked: bool = false
		var stars_req: int = 0
		if GameManager and GameManager.has_method("is_tower_unlocked"):
			is_locked = not GameManager.is_tower_unlocked(tower_id)
			stars_req = GameManager.stars_required_for(tower_id)

		var btn := Button.new()
		# BTD-style side-shop row: full container width, 84px tall —
		# bumped from 76 because "Banani-Hof" + "+20 G/Wälle" needed
		# more vertical room next to the lock capsule (was clipping
		# the bottom of the cost label per user screenshot).
		btn.custom_minimum_size = Vector2(0, 84)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.clip_contents = true
		btn.disabled = is_locked
		if is_locked:
			btn.tooltip_text = "🔒 Brich %d Stärn zum z'freischalte" % stars_req
		else:
			# D24: hover preview showing key stats at a glance
			var tip_lines: Array = [
				td.display_name if "display_name" in td else tower_id,
				"Kosch:   %d G" % td.buy_cost,
				"Schade: %d" % td.damage,
				"Reichwiiti: %d px" % int(td.attack_range),
				"Schussrate: %.1f/s" % (1.0 / maxf(td.attack_speed, 0.01)),
			]
			if "gold_per_round" in td and td.gold_per_round > 0:
				tip_lines.append("+%d G / Welle" % td.gold_per_round)
			if "is_support" in td and td.is_support:
				tip_lines.append("Buff: +25% Schade i de Nöchi")
			btn.tooltip_text = "\n".join(tip_lines)
		# Per-tier faint tint on the row background so the 5 friends are
		# visually distinguishable even when the icons are loading.
		_style_shop_button(btn, td)
		# Use button_down (press) instead of pressed (release) so the player
		# can press-and-drag the shop button straight to the map (drag-and-
		# drop placement). The press fires placement mode immediately; the
		# subsequent drag events go to TowerPlacement via _unhandled_input;
		# release-on-map places the tower.
		# Use standard `pressed` (fires on release) — the `button_down`
		# experiment for drag-from-shop was unreliable on HTML5/touch
		# and effectively broke tower selection entirely (user report).
		btn.pressed.connect(func(): _on_shop_tower_selected(td, btn))

		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 8)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		# Icon on the left
		if td.custom_texture:
			var icon := TextureRect.new()
			icon.texture = td.custom_texture
			icon.custom_minimum_size = Vector2(60, 60)
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(icon)
		else:
			var placeholder := ColorRect.new()
			placeholder.custom_minimum_size = Vector2(48, 48)
			placeholder.color = td.base_color
			placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(placeholder)

		# Stacked text on the right
		var text_col := VBoxContainer.new()
		text_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text_col.add_theme_constant_override("separation", 0)
		text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER

		var name_label := Label.new()
		name_label.text = td.display_name
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		name_label.add_theme_font_size_override("font_size", 14)
		name_label.add_theme_color_override("font_color", Color(1, 0.96, 0.88))
		name_label.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0, 0.9))
		name_label.add_theme_constant_override("outline_size", 3)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Truncate (don't autowrap) — autowrap on a narrow column made
		# 2-line names overflow the row. Ellipsis keeps the row height
		# stable while still fitting "Banani-Hof" / "Migros-Villa".
		name_label.clip_text = true
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		text_col.add_child(name_label)

		var cost_label := Label.new()
		cost_label.text = "%d g" % td.buy_cost
		cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		cost_label.add_theme_font_size_override("font_size", 12)
		cost_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
		cost_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
		cost_label.add_theme_constant_override("outline_size", 2)
		cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text_col.add_child(cost_label)
		_cost_labels.append(cost_label)

		var dps_label := Label.new()
		# Farm towers (gold_per_round > 0) deal no DPS — show their economy
		# stat instead. "DPS 0" was confusing for the Banani-Hof / farm
		# tower which is meant for income, not killing.
		if "gold_per_round" in td and td.gold_per_round > 0:
			dps_label.text = "+%d G/Wälle" % int(td.gold_per_round)
		else:
			dps_label.text = "DPS %.0f" % (td.damage * td.attack_speed)
		dps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		dps_label.add_theme_font_size_override("font_size", 10)
		dps_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0, 0.9))
		dps_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
		dps_label.add_theme_constant_override("outline_size", 2)
		dps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text_col.add_child(dps_label)

		row.add_child(text_col)
		btn.add_child(row)
		# Locked overlay — padlock + stars-required hint. Anchored to the
		# right edge with a dark backing so it stops overlapping the cost/
		# DPS text on narrow shop rows (visible bug in playtest screenshots).
		if is_locked:
			var lock_box := PanelContainer.new()
			lock_box.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
			lock_box.offset_left = -54
			lock_box.offset_right = -6
			lock_box.offset_top = -14
			lock_box.offset_bottom = 14
			lock_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var lock_bg := StyleBoxFlat.new()
			lock_bg.bg_color = Color(0, 0, 0, 0.65)
			lock_bg.corner_radius_top_left = 6
			lock_bg.corner_radius_top_right = 6
			lock_bg.corner_radius_bottom_left = 6
			lock_bg.corner_radius_bottom_right = 6
			lock_bg.content_margin_left = 4
			lock_bg.content_margin_right = 4
			lock_bg.content_margin_top = 1
			lock_bg.content_margin_bottom = 1
			lock_box.add_theme_stylebox_override("panel", lock_bg)
			var lock_label := Label.new()
			lock_label.text = "🔒 %d*" % stars_req
			lock_label.add_theme_font_size_override("font_size", 13)
			lock_label.add_theme_color_override("font_color", Color(1, 0.95, 0.4))
			lock_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			lock_box.add_child(lock_label)
			btn.add_child(lock_box)
			# Dim the row contents so the lock reads clearly.
			row.modulate = Color(0.5, 0.5, 0.5, 0.9)
		tower_shop.add_child(btn)


func _style_shop_button(btn: Button, td: TowerData) -> void:
	# Build per-state StyleBoxFlat's for the shop row. The base color is
	# a muted version of the tower's projectile color so each friend's
	# row reads at a glance; hover/pressed lift brightness.
	var c: Color = td.projectile_color if td and td.projectile_color.a > 0.01 else Color(0.3, 0.3, 0.35)
	var base := StyleBoxFlat.new()
	base.bg_color = Color(c.r * 0.18 + 0.08, c.g * 0.18 + 0.08, c.b * 0.18 + 0.08, 0.95)
	base.border_color = Color(c.r * 0.6, c.g * 0.6, c.b * 0.6, 0.85)
	base.border_width_top = 1
	base.border_width_bottom = 1
	base.border_width_left = 2
	base.border_width_right = 1
	base.corner_radius_top_left = 8
	base.corner_radius_top_right = 8
	base.corner_radius_bottom_left = 8
	base.corner_radius_bottom_right = 8
	base.content_margin_left = 8
	base.content_margin_right = 6
	base.content_margin_top = 4
	base.content_margin_bottom = 4
	var hover := base.duplicate() as StyleBoxFlat
	hover.bg_color = Color(c.r * 0.25 + 0.1, c.g * 0.25 + 0.1, c.b * 0.25 + 0.1, 0.98)
	hover.border_color = Color(c.r * 0.85, c.g * 0.85, c.b * 0.85, 0.95)
	var pressed := base.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(c.r * 0.35 + 0.12, c.g * 0.35 + 0.12, c.b * 0.35 + 0.12, 1.0)
	pressed.border_color = Color.WHITE
	var disabled := base.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.08, 0.08, 0.1, 0.8)
	disabled.border_color = Color(0.25, 0.25, 0.3, 0.7)
	btn.add_theme_stylebox_override("normal", base)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.set_meta("shop_base_style", base)


func show_enemy_intro(enemy_id: String, enemy_data: Resource) -> void:
	# Big first-appearance reveal per enemy type. 1.2s animation that
	# eats the middle of the screen. After this, no more persistent
	# name labels float over enemies of this type (handled by
	# `WaveManager._seen_enemy_ids` emitting `enemy_introduced` only on
	# the first spawn).
	# Boss telegraph — a brief red screen flash + heavier shake fires
	# BEFORE the panel slides in. Tells the player "danger" before they
	# can read the text.
	if enemy_id == "boss":
		_flash_boss_telegraph()
	var overlay := PanelContainer.new()
	overlay.modulate = Color(1, 1, 1, 0)
	overlay.anchors_preset = Control.PRESET_CENTER
	overlay.anchor_left = 0.5
	overlay.anchor_top = 0.5
	overlay.anchor_right = 0.5
	overlay.anchor_bottom = 0.5
	# Responsive width — agent-audit BUG #7: was fixed ±280 which clipped
	# on narrow phones (after safe-area inset the viewport can be <620px
	# wide). Now scales to 45% of viewport width, clamped to stay usable.
	var vp_w: float = get_viewport().get_visible_rect().size.x
	var half_w: float = clampf(vp_w * 0.45 * 0.5, 180.0, 300.0)
	overlay.offset_left = -half_w
	overlay.offset_right = half_w
	overlay.offset_top = -90
	overlay.offset_bottom = 90
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)

	var warning := Label.new()
	warning.text = "⚠ NÖÖI BEDROHIG"
	warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning.add_theme_font_size_override("font_size", 22)
	warning.add_theme_color_override("font_color", Color(1, 0.6, 0.2))
	vbox.add_child(warning)

	# Enemy sprite preview — shows either the custom_texture (if set) or
	# the drawn fallback via a tiny BaseEnemy instance. Gives the player
	# a visual cue about what's coming, not just a name.
	var preview := _build_enemy_preview(enemy_data)
	if preview:
		vbox.add_child(preview)

	var name_lbl := Label.new()
	name_lbl.text = enemy_data.display_name if enemy_data and "display_name" in enemy_data else enemy_id
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 38)
	name_lbl.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	name_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	name_lbl.add_theme_constant_override("outline_size", 5)
	vbox.add_child(name_lbl)

	overlay.add_child(vbox)
	add_child(overlay)

	# Screen-shake the game scene on boss reveal (HUD CanvasLayer unaffected)
	# + deep procedural roar for tactile "oh no" feedback.
	if enemy_id == "boss":
		if EffectPlayer:
			EffectPlayer.screen_shake(7.0, 0.45)
		if SfxManager and SfxManager.has_method("play_boss_roar"):
			SfxManager.play_boss_roar()

	# Zoom-in + fade — 0.25s in, 0.7s hold, 0.25s out
	overlay.scale = Vector2(2.0, 2.0)
	var tw := overlay.create_tween()
	tw.set_parallel(true)
	tw.tween_property(overlay, "modulate:a", 1.0, 0.25)
	tw.tween_property(overlay, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(0.7)
	tw.chain().tween_property(overlay, "modulate:a", 0.0, 0.25)
	tw.chain().tween_callback(overlay.queue_free)


func _build_enemy_preview(enemy_data: Resource) -> Control:
	# Build a 90px square thumbnail of the enemy. If custom_texture is
	# set, use a TextureRect. Otherwise instantiate a BaseEnemy off-tree
	# and let its _draw() render onto a SubViewport. For simplicity here
	# we fall back to a colored circle for non-texture enemies — the
	# _draw path would need a SubViewport pipeline which is heavier.
	if not enemy_data:
		return null
	var wrap := CenterContainer.new()
	wrap.custom_minimum_size = Vector2(96, 96)
	if "custom_texture" in enemy_data and enemy_data.custom_texture:
		var tex_rect := TextureRect.new()
		tex_rect.texture = enemy_data.custom_texture
		tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.custom_minimum_size = Vector2(90, 90)
		wrap.add_child(tex_rect)
	else:
		# Colored disc as fallback (base_color from EnemyData)
		var col := Color.RED
		if "base_color" in enemy_data:
			col = enemy_data.base_color
		var disc := ColorRect.new()
		disc.color = col
		disc.custom_minimum_size = Vector2(72, 72)
		# Rounded corners via a small StyleBoxFlat in a wrapper panel
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(82, 82)
		var sb := StyleBoxFlat.new()
		sb.bg_color = col
		sb.corner_radius_top_left = 36
		sb.corner_radius_top_right = 36
		sb.corner_radius_bottom_left = 36
		sb.corner_radius_bottom_right = 36
		sb.border_width_top = 3
		sb.border_width_bottom = 3
		sb.border_width_left = 3
		sb.border_width_right = 3
		sb.border_color = Color.BLACK
		panel.add_theme_stylebox_override("panel", sb)
		wrap.add_child(panel)
	return wrap


var _wave_progress_bar: ProgressBar = null
var _combo_badge: Label = null
var _combo_tween: Tween = null


func _ensure_combo_badge() -> Label:
	if _combo_badge and is_instance_valid(_combo_badge):
		return _combo_badge
	var lbl := Label.new()
	lbl.name = "ComboBadge"
	# Anchor center-top with explicit half-widths so the label clips
	# symmetrically. PRESET_CENTER_TOP without width put the text origin
	# at center but the text grew rightward only — and since centered
	# Label aligns its CONTAINER center, the long string at higher combos
	# overflowed off the left side of the screen.
	lbl.anchor_left = 0.5
	lbl.anchor_right = 0.5
	lbl.anchor_top = 0.0
	lbl.anchor_bottom = 0.0
	lbl.offset_left = -180
	lbl.offset_right = 180
	lbl.offset_top = 78  # below the wave progress bar at y=46-60
	lbl.offset_bottom = 110
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", Color(1, 0.95, 0.4))
	lbl.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0, 1))
	lbl.add_theme_constant_override("outline_size", 5)
	lbl.modulate.a = 0.0
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lbl)
	_combo_badge = lbl
	return lbl


func _on_combo_changed(counter: int, multiplier: float) -> void:
	var badge := _ensure_combo_badge()
	if _combo_tween and _combo_tween.is_valid():
		_combo_tween.kill()
	if counter <= 0:
		_combo_tween = badge.create_tween()
		_combo_tween.tween_property(badge, "modulate:a", 0.0, 0.25)
		_clear_combo_screen_tint()
		return
	badge.text = "RUUSCH! x%d  ·  %.1fx Gold" % [counter, multiplier]
	badge.pivot_offset = badge.size * 0.5
	_combo_tween = badge.create_tween().set_parallel(true)
	_combo_tween.tween_property(badge, "modulate:a", 1.0, 0.1)
	_combo_tween.tween_property(badge, "scale", Vector2(1.15, 1.15), 0.08)
	_combo_tween.chain().tween_property(badge, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_SINE)
	# At combo ≥5, amp the screen with a faint gold vignette so the player
	# feels the "in the zone" state. Strength scales modestly with counter.
	if counter >= 5:
		_apply_combo_screen_tint(counter)


var _combo_tint_rect: ColorRect = null

func _apply_combo_screen_tint(counter: int) -> void:
	if not _combo_tint_rect or not is_instance_valid(_combo_tint_rect):
		_combo_tint_rect = ColorRect.new()
		_combo_tint_rect.name = "ComboTint"
		_combo_tint_rect.anchors_preset = Control.PRESET_FULL_RECT
		_combo_tint_rect.anchor_right = 1.0
		_combo_tint_rect.anchor_bottom = 1.0
		_combo_tint_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_combo_tint_rect.z_index = -10  # behind HUD widgets
		add_child(_combo_tint_rect)
		move_child(_combo_tint_rect, 0)
	var alpha: float = clampf(0.06 + (counter - 5) * 0.012, 0.06, 0.18)
	_combo_tint_rect.color = Color(1.0, 0.8, 0.2, alpha)


func _clear_combo_screen_tint() -> void:
	if _combo_tint_rect and is_instance_valid(_combo_tint_rect):
		var fade := _combo_tint_rect.create_tween()
		fade.tween_property(_combo_tint_rect, "color:a", 0.0, 0.4)


func _flash_boss_telegraph() -> void:
	# Red full-screen ColorRect that flashes briefly before boss intro.
	# Layered behind the intro overlay (z_index lower) so the panel still
	# reads on top. Auto-frees.
	var flash := ColorRect.new()
	flash.color = Color(0.85, 0.1, 0.1, 0.0)
	flash.anchors_preset = Control.PRESET_FULL_RECT
	flash.anchor_right = 1.0
	flash.anchor_bottom = 1.0
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.z_index = -1
	add_child(flash)
	var tw := flash.create_tween()
	tw.tween_property(flash, "color:a", 0.42, 0.10)
	tw.tween_property(flash, "color:a", 0.0, 0.45)
	tw.tween_callback(flash.queue_free)
	if SfxManager and SfxManager.has_method("play_boss_roar"):
		SfxManager.play_boss_roar()
	if EffectPlayer and EffectPlayer.has_method("screen_shake"):
		EffectPlayer.screen_shake(7.5, 0.45)


func show_wave_clear_celebration() -> void:
	# Brief big "WÄLLE GSCHAFFT!" text mid-screen at end of each wave.
	# Cheap mid-game reward — keeps the player feeling progress.
	var lbl := Label.new()
	lbl.name = "WaveClearCelebration"
	lbl.text = "WÄLLE GSCHAFFT!"
	lbl.add_theme_font_size_override("font_size", 56)
	lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.25))
	lbl.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0))
	lbl.add_theme_constant_override("outline_size", 6)
	lbl.anchors_preset = Control.PRESET_CENTER
	lbl.anchor_left = 0.5
	lbl.anchor_right = 0.5
	lbl.anchor_top = 0.5
	lbl.anchor_bottom = 0.5
	lbl.offset_left = -260
	lbl.offset_right = 260
	lbl.offset_top = -50
	lbl.offset_bottom = 50
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.modulate.a = 0.0
	lbl.scale = Vector2(0.6, 0.6)
	add_child(lbl)
	var tw := lbl.create_tween().set_parallel(true)
	tw.tween_property(lbl, "modulate:a", 1.0, 0.15)
	tw.tween_property(lbl, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(0.6)
	tw.chain().tween_property(lbl, "modulate:a", 0.0, 0.35)
	tw.chain().tween_callback(lbl.queue_free)


func _format_gold(amount: int) -> String:
	# Swiss thousands separator: 1'234 instead of 1234. Plain digits below
	# 1000 — adding the apostrophe for sub-thousand looks weird.
	if amount < 1000:
		return str(amount)
	var s: String = str(amount)
	var out: String = ""
	var n: int = s.length()
	for i in n:
		if i > 0 and ((n - i) % 3 == 0):
			out += "'"
		out += s[i]
	return out


func _ensure_wave_progress_bar() -> ProgressBar:
	if _wave_progress_bar and is_instance_valid(_wave_progress_bar):
		return _wave_progress_bar
	# Lazily create, anchored just below the wave label at top. No
	# .tscn edit needed — all settings applied here.
	var bar := ProgressBar.new()
	bar.name = "WaveProgress"
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = 0.0
	bar.custom_minimum_size = Vector2(320, 14)
	# Anchor center-top so the bar stays 320px wide regardless of viewport
	# width. PRESET_TOP_WIDE with offset_right=510 was interpreted as
	# 510px from the right edge, making the bar span 1410px on a 1920p
	# desktop / 1830px on the user's phone (full-width-blob bug).
	bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	bar.anchor_left = 0.5
	bar.anchor_right = 0.5
	bar.offset_left = -160
	bar.offset_right = 160
	bar.offset_top = 46
	bar.offset_bottom = 60
	bar.show_percentage = false
	# Custom styled fill — was the default light grey blob, barely
	# readable. Now warm gold gradient with dark backing.
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.10, 0.08, 0.06, 0.85)
	bg.corner_radius_top_left = 4
	bg.corner_radius_top_right = 4
	bg.corner_radius_bottom_left = 4
	bg.corner_radius_bottom_right = 4
	var fg := StyleBoxFlat.new()
	fg.bg_color = Color(1.0, 0.78, 0.18, 0.95)
	fg.corner_radius_top_left = 4
	fg.corner_radius_top_right = 4
	fg.corner_radius_bottom_left = 4
	fg.corner_radius_bottom_right = 4
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
	add_child(bar)
	_wave_progress_bar = bar
	return bar


func update_wave_progress(pct: float) -> void:
	var bar := _ensure_wave_progress_bar()
	var tw := create_tween()
	tw.tween_property(bar, "value", clampf(pct, 0.0, 1.0), 0.2)


func update_wave_info(current: int, total: int) -> void:
	if wave_label:
		if current == 0:
			# Bereit state — gold so it visually belongs to the wave
			# progress bar below it. Was default theme color (white-ish).
			wave_label.text = "✦ Bereit"
			wave_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.30))
		else:
			wave_label.text = "Welle %d/%d" % [current, total]
			wave_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.78))
			# Wave announcement — big text that fades
			_show_wave_announcement(current, total)
			# Reset sub-wave bar to 0 for the new wave
			var bar := _ensure_wave_progress_bar()
			bar.value = 0.0
	_update_wave_progress_bar(current, total)


func _update_wave_progress_bar(current: int, total: int) -> void:
	# Create-on-first-use: a thin ProgressBar at the bottom of TopBar showing
	# how far through the level's waves the player is. Glanceable "how much
	# is left" cue that complements the "Welle X/Y" text.
	var top_bar := get_node_or_null("TopBar")
	if top_bar == null:
		return
	var bar: ProgressBar = top_bar.get_node_or_null("WaveProgressBar") as ProgressBar
	if bar == null:
		bar = ProgressBar.new()
		bar.name = "WaveProgressBar"
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 6)
		bar.anchors_preset = Control.PRESET_BOTTOM_WIDE
		bar.anchor_top = 1.0
		bar.anchor_right = 1.0
		bar.anchor_bottom = 1.0
		bar.offset_top = -6.0
		bar.modulate = Color(1, 0.9, 0.3, 0.85)
		bar.max_value = 100
		bar.value = 0
		top_bar.add_child(bar)
	if total <= 0:
		bar.value = 0
		return
	bar.value = float(current) / float(total) * 100.0


func _show_wave_announcement(current: int, _total: int) -> void:
	var announce := Label.new()
	announce.text = "— WELLE %d —" % current
	var is_danger: bool = current >= 7
	announce.add_theme_font_size_override("font_size", 54 if not is_danger else 62)
	var txt_color := Color(1, 0.3, 0.2) if is_danger else Color(1, 0.92, 0.2)
	announce.add_theme_color_override("font_color", txt_color)
	announce.add_theme_color_override("font_outline_color", Color(0.15, 0.05, 0))
	announce.add_theme_constant_override("outline_size", 6)
	announce.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	announce.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	announce.custom_minimum_size = Vector2(700, 80)
	announce.set_anchors_preset(Control.PRESET_CENTER)
	announce.pivot_offset = Vector2(350, 40)
	add_child(announce)
	# Slide in from the right, hold, then fade out — D27
	announce.position.x = 1400.0
	announce.position.y = -40.0
	var tw := announce.create_tween()
	tw.tween_property(announce, "position:x", -350.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(announce, "position:x", -350.0, 0.55)  # hold
	tw.tween_property(announce, "modulate:a", 0.0, 0.35)
	tw.tween_callback(announce.queue_free)


func show_next_wave_button(visible_flag: bool) -> void:
	if next_wave_button:
		next_wave_button.visible = visible_flag
		# Kill any live pulse tween before creating a new one so rapid
		# auto-wave toggles don't stack fighting tweens on modulate.
		# Audit P1 #8.
		if _next_wave_pulse_tween and _next_wave_pulse_tween.is_valid():
			_next_wave_pulse_tween.kill()
			_next_wave_pulse_tween = null
		if visible_flag:
			next_wave_button.modulate = Color.WHITE
			_next_wave_pulse_tween = next_wave_button.create_tween().set_loops(3)
			_next_wave_pulse_tween.tween_property(next_wave_button, "modulate", Color(1.3, 1.2, 0.8), 0.4)
			_next_wave_pulse_tween.tween_property(next_wave_button, "modulate", Color.WHITE, 0.4)
	_refresh_next_wave_preview(visible_flag)


func _refresh_next_wave_preview(visible_flag: bool) -> void:
	# Shows a compact panel above the Next Wave button with the enemy
	# composition of the upcoming wave — "Chunt: 15x Brötli, 3x Cervelat".
	# Hidden while a wave is in progress. ROADMAP #7: fade out instead of
	# instant queue_free so the preview slides off gracefully when a
	# wave starts.
	var existing: Node = get_node_or_null("NextWavePreview")
	if existing:
		if existing is Control:
			var ctl: Control = existing
			var fade := ctl.create_tween()
			fade.tween_property(ctl, "modulate:a", 0.0, 0.2)
			fade.tween_callback(ctl.queue_free)
		else:
			existing.queue_free()
	if not visible_flag:
		return
	# Find the game's WaveManager. current_scene may briefly be wrong
	# during reload_current_scene transitions, so prefer the group lookup.
	# Audit P1 #10.
	var wm: Node = get_tree().get_first_node_in_group("wave_manager")
	if wm == null:
		var game: Node = get_tree().current_scene
		if game:
			wm = game.get_node_or_null("WaveManager")
	if not wm or not wm.has_method("get_next_wave_preview"):
		return
	var preview: Array = wm.get_next_wave_preview()
	if preview.is_empty():
		return
	var panel := PanelContainer.new()
	panel.name = "NextWavePreview"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.anchors_preset = Control.PRESET_BOTTOM_WIDE
	panel.anchor_top = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	# Keep clear of the right-anchored SideShop (~170px wide)
	panel.offset_left = 20
	panel.offset_right = -190
	# Park just above the now-76px-tall BottomPanel, give preview ~60px
	panel.offset_top = -146.0
	panel.offset_bottom = -86.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.1, 0.12, 0.85)
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_color = Color(1, 0.8, 0.3, 0.7)
	panel.add_theme_stylebox_override("panel", sb)
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 14)
	var prefix := Label.new()
	prefix.text = "Chunt:"
	prefix.add_theme_font_size_override("font_size", 16)
	prefix.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	hbox.add_child(prefix)
	# Boss warning — if any group in this wave is a boss, prepend a red
	# "⚠ BOSS" tag so the player is forewarned. Pulses to draw attention.
	var has_boss: bool = false
	for g in preview:
		if g.get("enemy_id", "") == "boss":
			has_boss = true; break
	if has_boss:
		var warn := Label.new()
		warn.text = "⚠ BOSS"
		warn.add_theme_font_size_override("font_size", 17)
		warn.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2))
		warn.add_theme_color_override("font_outline_color", Color(0.25, 0.05, 0))
		warn.add_theme_constant_override("outline_size", 3)
		hbox.add_child(warn)
		var warn_pulse := warn.create_tween().set_loops()
		warn_pulse.tween_property(warn, "modulate:a", 0.5, 0.5)
		warn_pulse.tween_property(warn, "modulate:a", 1.0, 0.5)
	for group in preview:
		var enemy_id: String = group.get("enemy_id", "")
		var icon_tex: Texture2D = _enemy_icon_texture(enemy_id)
		if icon_tex:
			var icon := TextureRect.new()
			icon.texture = icon_tex
			icon.custom_minimum_size = Vector2(22, 22)
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			hbox.add_child(icon)
		else:
			var swatch := ColorRect.new()
			swatch.custom_minimum_size = Vector2(14, 14)
			swatch.color = _enemy_preview_color(enemy_id)
			swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			hbox.add_child(swatch)
		var entry := Label.new()
		var display_name: String = _short_name_for_enemy(enemy_id)
		entry.text = "%dx %s" % [group.get("count", 0), display_name]
		entry.add_theme_font_size_override("font_size", 16)
		entry.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
		hbox.add_child(entry)
	panel.add_child(hbox)
	add_child(panel)


func _enemy_icon_texture(enemy_id: String) -> Texture2D:
	var data_path := "res://resources/enemy_data/%s.tres" % enemy_id
	if not ResourceLoader.exists(data_path):
		return null
	var ed = load(data_path)
	if ed and "custom_texture" in ed and ed.custom_texture is Texture2D:
		return ed.custom_texture
	return null


func _enemy_preview_color(enemy_id: String) -> Color:
	match enemy_id:
		"basic": return Color(0.9, 0.8, 0.5)
		"fast": return Color(0.8, 0.5, 0.2)
		"tank": return Color(0.5, 0.35, 0.25)
		"healer": return Color(0.4, 0.7, 0.95)
		"flying": return Color(0.3, 0.75, 0.35)
		"boss": return Color(0.9, 0.2, 0.15)
		"swarm": return Color(0.9, 0.9, 0.75)
		"camo": return Color(0.3, 0.4, 0.3)
		"lead": return Color(0.5, 0.5, 0.55)
		"regrow": return Color(0.5, 0.8, 0.4)
		_: return Color(0.6, 0.6, 0.7)


func _short_name_for_enemy(enemy_id: String) -> String:
	# Compact display names for the preview panel — full names are too
	# long for a single row with 3+ groups.
	match enemy_id:
		"basic": return "Brötli"
		"fast": return "Toblerone"
		"tank": return "Cervelat"
		"healer": return "Dr.Rivella"
		"flying": return "Fondue"
		"swarm": return "Tofu"
		"boss": return "M-TÜÜFEL"
		_: return enemy_id.capitalize()


func update_enemy_count(count: int) -> void:
	if not enemy_count_label:
		return
	if count > 0:
		enemy_count_label.text = "%d übrig" % count
		enemy_count_label.add_theme_color_override("font_color", Color(1, 0.9, 0.8))
	else:
		# Briefly celebrate wave clear before going blank
		if enemy_count_label.text != "":
			enemy_count_label.text = "Wälle gschafft!"
			enemy_count_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
			var fade := enemy_count_label.create_tween()
			fade.tween_interval(1.6)
			fade.tween_callback(func():
				if enemy_count_label:
					enemy_count_label.text = "")


func set_placing(placing: bool) -> void:
	_is_placing = placing
	cancel_button.visible = placing
	if placing:
		next_wave_button.visible = false
	else:
		cancel_button.visible = false
		next_wave_button.visible = true
		_highlight_placing_button(null)


var _glow_tween: Tween = null


func show_tower_info(tower: BaseTower) -> void:
	# Kill any existing glow tween — audit P0 #3: the old infinite-loop
	# tween was never killed on deselect, so the previous tower kept
	# pulsing its modulate forever even after selection moved on.
	if _glow_tween and _glow_tween.is_valid():
		_glow_tween.kill()
	# Deselect previous
	if _selected_tower and is_instance_valid(_selected_tower):
		_selected_tower.modulate = Color.WHITE
		_selected_tower.show_range(false)
	_selected_tower = tower
	tower.show_range(true)
	# Wipe stale upgrade buttons from a prior selection — they'd otherwise
	# linger with cached text from a different tower's data ("Lemurius"
	# header + "Volleyball-Hagel" button bug from screenshots). They get
	# rebuilt fresh by _refresh_branching_buttons / _ensure_linear_upgrade_button.
	if tower_info:
		var hbox := tower_info.get_node_or_null("VBox/HBox")
		if hbox:
			for child in hbox.get_children():
				if child is Button and (child.name == "PathAButton" or child.name == "PathBButton"):
					child.queue_free()
	# Dim every OTHER tower so the eye lands on the active one. Restored
	# in hide_tower_info via the same group iteration.
	for n in get_tree().get_nodes_in_group("towers"):
		var t := n as Node2D
		if t and t != tower:
			t.modulate = Color(0.6, 0.6, 0.65, 1.0)
	# Gold-warm pulse on selected tower so it's obvious which one is
	# active — was a faint blue-white that read as "noise" rather than
	# "this is your selection".
	_glow_tween = tower.create_tween().set_loops()
	_glow_tween.tween_property(tower, "modulate", Color(1.35, 1.2, 0.7), 0.45).set_trans(Tween.TRANS_SINE)
	_glow_tween.tween_property(tower, "modulate", Color.WHITE, 0.55).set_trans(Tween.TRANS_SINE)
	SfxManager.play_click()
	if tower_info:
		tower_info.visible = true
		_refresh_tower_info()
		_clamp_tower_info_to_viewport()


func _clamp_tower_info_to_viewport() -> void:
	# The TowerInfo PanelContainer is anchored center-bottom with fixed
	# offsets (-175/+175). On narrow viewports (safe-area insets, split-
	# screen) it can clip off the left/right edge. After the panel lays
	# out, clamp its global_position + size into the viewport rect so
	# it's always fully usable. (User report: popup "ganz am Rand".)
	if not tower_info:
		return
	await get_tree().process_frame  # let container layout settle
	if not is_instance_valid(tower_info) or not tower_info.visible:
		return
	var vp: Rect2 = get_viewport().get_visible_rect()
	var p: Vector2 = tower_info.global_position
	var s: Vector2 = tower_info.size
	var clamped: Vector2 = p
	clamped.x = clampf(p.x, 10.0, vp.size.x - s.x - 10.0)
	clamped.y = clampf(p.y, 10.0, vp.size.y - s.y - 10.0)
	if clamped != p:
		tower_info.global_position = clamped


func hide_tower_info() -> void:
	# Kill the glow-loop tween so the deselected tower stops pulsing
	if _glow_tween and _glow_tween.is_valid():
		_glow_tween.kill()
		_glow_tween = null
	# Clear any stray "selected for placement" gold-border highlight in
	# the shop — was lingering on Lemurius after closing the tower-info
	# panel (visible bug in screenshots — the row stayed gold-bordered
	# even with no active placement).
	if _placing_button and is_instance_valid(_placing_button):
		_highlight_placing_button(null)
	# Restore all-tower brightness — undo the dim from show_tower_info.
	for n in get_tree().get_nodes_in_group("towers"):
		var t := n as Node2D
		if t:
			t.modulate = Color.WHITE
	# Disarm the sell button if it was armed — otherwise next reopen
	# would be hair-trigger.
	_sell_armed = false
	_sell_arm_timer = null
	if _selected_tower and is_instance_valid(_selected_tower):
		_selected_tower.show_range(false)
		_selected_tower.modulate = Color.WHITE
		_selected_tower = null
	if tower_info:
		tower_info.visible = false


func _notification(_what: int) -> void:
	# Previous focus-out auto-cancel was firing spuriously in the HTML5
	# deploy (any tab-blur, dev-tools-open, or pause-button click was
	# dismissing an active placement). User reported inability to place
	# towers as a result. Dropped the behavior entirely — user can
	# cancel via the explicit ABBRECHE button.
	pass


func _unhandled_input(event: InputEvent) -> void:
	# Auto-hide tower info panel when user taps on empty map area. Audit
	# #3: the panel occludes the middle band of the map and towers
	# behind it can't be clicked. Tap-outside-to-close is BTD-style.
	# Audit round-3 P1 #17: skip the close when tap is on a tower, so
	# GameLevel._check_tower_tap can re-open immediately without a
	# close/reopen flash frame.
	if not tower_info or not tower_info.visible:
		return
	var tap_pos: Vector2
	var is_tap: bool = false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tap_pos = event.global_position
		is_tap = true
	elif event is InputEventScreenTouch and event.pressed:
		tap_pos = event.position
		is_tap = true
	if not is_tap:
		return
	# Inside the panel? Keep showing.
	var panel_rect: Rect2 = Rect2(tower_info.global_position, tower_info.size)
	if panel_rect.has_point(tap_pos):
		return
	# On a tower? Let GameLevel handle the reselect — don't hide+flash.
	if _tap_is_on_a_tower(tap_pos):
		return
	hide_tower_info()


func _tap_is_on_a_tower(screen_pos: Vector2) -> bool:
	var world_pos: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * screen_pos
	for tower_node in get_tree().get_nodes_in_group("towers"):
		var t := tower_node as Node2D
		if t and t.global_position.distance_to(world_pos) < 50.0:
			return true
	return false


# F18: Dynamically switch scroll_deadzone so desktop mouse gets instant
# drag start (0) while touch keeps the 12px deadzone that prevents
# accidental scrolls during button taps.
func _input(event: InputEvent) -> void:
	if not shop_scroll:
		return
	if event is InputEventMouse:
		shop_scroll.scroll_deadzone = 0
	elif event is InputEventScreenTouch or event is InputEventScreenDrag:
		shop_scroll.scroll_deadzone = 12


func _refresh_tower_info() -> void:
	if not _selected_tower or not _selected_tower.data or not tower_info:
		return

	var td := _selected_tower.data
	var name_lbl: Label = tower_info.get_node_or_null("VBox/NameLabel")
	var stats_lbl: Label = tower_info.get_node_or_null("VBox/StatsLabel")
	var upgrade_btn: Button = tower_info.get_node_or_null("VBox/HBox/UpgradeButton")
	var sell_btn: Button = tower_info.get_node_or_null("VBox/HBox/SellButton")

	# Side-by-side layout: portrait left (~64px), stats column right.
	# Lazily build a "Header" HBoxContainer that holds them so the
	# original scene structure stays intact for the upgrade/sell row below.
	var vbox: VBoxContainer = tower_info.get_node_or_null("VBox")
	if vbox:
		var header: HBoxContainer = vbox.get_node_or_null("Header")
		if header == null:
			header = HBoxContainer.new()
			header.name = "Header"
			header.add_theme_constant_override("separation", 12)
			vbox.add_child(header)
			vbox.move_child(header, 0)
			# Reparent name + stats labels into the header's right column
			var stats_col := VBoxContainer.new()
			stats_col.name = "StatsCol"
			stats_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			stats_col.add_theme_constant_override("separation", 4)
			header.add_child(stats_col)
			# Move existing NameLabel + StatsLabel into stats_col if present
			if name_lbl and name_lbl.get_parent() == vbox:
				vbox.remove_child(name_lbl)
				stats_col.add_child(name_lbl)
				name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
				name_lbl.add_theme_font_size_override("font_size", 22)
				name_lbl.add_theme_color_override("font_color", Color(1, 0.92, 0.6))
				name_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
				name_lbl.add_theme_constant_override("outline_size", 3)
			if stats_lbl and stats_lbl.get_parent() == vbox:
				vbox.remove_child(stats_lbl)
				stats_col.add_child(stats_lbl)
				stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
				stats_lbl.add_theme_font_size_override("font_size", 14)
				stats_lbl.add_theme_color_override("font_color", Color(0.92, 0.92, 0.85))
		# Portrait is the first child of Header (created if missing)
		var portrait: TextureRect = header.get_node_or_null("Portrait")
		if portrait == null:
			portrait = TextureRect.new()
			portrait.name = "Portrait"
			portrait.custom_minimum_size = Vector2(64, 64)
			portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			header.add_child(portrait)
			header.move_child(portrait, 0)
		# Clear stale texture FIRST — was reusing the previous selection's
		# portrait when the new tower's custom_texture was null + the
		# friend_photo lookup returned null. Visible bug: switching from
		# Cordula → Lemurius left Cordula's photo in the panel.
		portrait.texture = null
		# Resolution order matches base_tower._update_visual exactly so
		# the panel and the on-map sprite always show the same character.
		if td.friend_character_id != "" and GameManager and GameManager.has_method("get_friend_photo"):
			var photo := GameManager.get_friend_photo(td.friend_character_id)
			if photo:
				portrait.texture = photo
		if portrait.texture == null and td.custom_texture:
			portrait.texture = td.custom_texture

	if name_lbl:
		if td.has_branching_upgrades():
			name_lbl.text = "%s  ·  A%d / B%d" % [
				td.display_name,
				_selected_tower.path_a_tier,
				_selected_tower.path_b_tier,
			]
		else:
			name_lbl.text = "%s  ·  Lv %d" % [td.display_name, _selected_tower.upgrade_level + 1]
	if stats_lbl:
		var dps: float = _selected_tower.effective_damage * _selected_tower.effective_speed
		var kills: int = _selected_tower.kill_count if "kill_count" in _selected_tower else 0
		# D25: tier pip row using ASCII-safe glyphs. Was ●○ — those render
		# as tofu boxes in the bundled web font. [#] for filled, [-] for
		# remaining keep alignment + read clearly.
		var pip_str: String = ""
		if td.has_branching_upgrades():
			var max_tier: int = 3
			pip_str = "A:"
			for i in max_tier:
				pip_str += " [#]" if i < _selected_tower.path_a_tier else " [ ]"
			pip_str += "   B:"
			for i in max_tier:
				pip_str += " [#]" if i < _selected_tower.path_b_tier else " [ ]"
			pip_str += "\n"
		stats_lbl.text = "%sSchade: %.0f   DPS: %.1f   Kills: %d\nTempo: %.1f   Reichwiiti: %.0f" % [
			pip_str,
			_selected_tower.effective_damage,
			dps,
			kills,
			_selected_tower.effective_speed,
			_selected_tower.effective_range,
		]

	if td.has_branching_upgrades():
		_refresh_branching_buttons(upgrade_btn)
	elif upgrade_btn:
		_ensure_linear_upgrade_button(upgrade_btn)
		var cost := _selected_tower.get_upgrade_cost()
		if cost < 0:
			upgrade_btn.text = "MAXIMUM"
			upgrade_btn.disabled = true
		else:
			upgrade_btn.text = "Verbessere %d" % cost
			upgrade_btn.disabled = not _selected_tower.can_upgrade()

	if sell_btn:
		_paint_sell_button(sell_btn)
	# Re-clamp after refresh — post-upgrade the branching path buttons
	# appear and grow the panel height, which can push it off-screen on
	# narrow viewports. Agent-audit BUG #8.
	if tower_info and tower_info.visible:
		_clamp_tower_info_to_viewport()


func _paint_sell_button(sell_btn: Button) -> void:
	# Centralized sell-button styling so _refresh_tower_info (fired on
	# every gold change) doesn't silently overwrite the armed "Sicher? ✖"
	# state. Audit P0 #1: without this, a kill during the 2s arm window
	# reverted the label to "Verchaufe X" but left _sell_armed=true, so
	# the next tap sold with no visible warning.
	if _sell_armed:
		sell_btn.text = "Sicher? ✖"
		sell_btn.modulate = Color(1.0, 0.5, 0.3)
		return
	sell_btn.modulate = Color.WHITE
	if not _selected_tower or not _selected_tower.data:
		return
	var td := _selected_tower.data
	var sell_val: int
	if td.has_branching_upgrades():
		sell_val = td.get_sell_value_branched(_selected_tower.path_a_tier, _selected_tower.path_b_tier)
	else:
		sell_val = td.get_sell_value(_selected_tower.upgrade_level)
	# Coin-icon prefix instead of plain "Verchaufe" — shorter, scannable.
	sell_btn.text = "🪙 %d" % sell_val


func _ensure_linear_upgrade_button(upgrade_btn: Button) -> void:
	upgrade_btn.visible = true
	var parent := upgrade_btn.get_parent()
	if parent:
		var path_a_btn: Button = parent.get_node_or_null("PathAButton")
		var path_b_btn: Button = parent.get_node_or_null("PathBButton")
		if path_a_btn:
			path_a_btn.visible = false
		if path_b_btn:
			path_b_btn.visible = false


func _refresh_branching_buttons(linear_btn: Button) -> void:
	if not _selected_tower or not _selected_tower.data:
		return
	var td := _selected_tower.data
	var parent := linear_btn.get_parent() if linear_btn else tower_info.get_node_or_null("VBox/HBox")
	if parent == null:
		return
	if linear_btn:
		linear_btn.visible = false

	var path_a_btn: Button = parent.get_node_or_null("PathAButton")
	var path_b_btn: Button = parent.get_node_or_null("PathBButton")
	if path_a_btn == null:
		path_a_btn = Button.new()
		path_a_btn.name = "PathAButton"
		path_a_btn.custom_minimum_size = Vector2(0, 60)
		path_a_btn.pressed.connect(_on_path_a_button_pressed)
		parent.add_child(path_a_btn)
		# Put path buttons before the sell button
		var sell_idx := parent.get_node_or_null("SellButton")
		if sell_idx:
			parent.move_child(path_a_btn, sell_idx.get_index())
	if path_b_btn == null:
		path_b_btn = Button.new()
		path_b_btn.name = "PathBButton"
		path_b_btn.custom_minimum_size = Vector2(0, 60)
		path_b_btn.pressed.connect(_on_path_b_button_pressed)
		parent.add_child(path_b_btn)
		var sell_idx2 := parent.get_node_or_null("SellButton")
		if sell_idx2:
			parent.move_child(path_b_btn, sell_idx2.get_index())

	path_a_btn.visible = true
	path_b_btn.visible = true
	_style_path_button(path_a_btn, "a", td)
	_style_path_button(path_b_btn, "b", td)


func _style_path_button(btn: Button, path_letter: String, td: TowerData) -> void:
	var display: String = td.path_a_display if path_letter == "a" else td.path_b_display
	var tier := _selected_tower.path_a_tier if path_letter == "a" else _selected_tower.path_b_tier
	var cost := _selected_tower.get_path_upgrade_cost(path_letter)
	var tint: Color = td.path_a_tint if path_letter == "a" else td.path_b_tint
	var affordable: bool = cost >= 0 and _selected_tower.can_upgrade_path(path_letter)
	if cost < 0:
		btn.text = "%s  [MAX]" % display
		btn.disabled = true
	else:
		var next_name := _selected_tower.get_path_next_tier_name(path_letter)
		btn.text = ">> %s\n%d G" % [next_name if next_name != "" else display, cost]
		btn.disabled = not _selected_tower.can_upgrade_path(path_letter)
	btn.add_theme_color_override("font_color", tint)
	btn.add_theme_color_override("font_outline_color", Color.BLACK)
	btn.add_theme_constant_override("outline_size", 2)
	btn.add_theme_font_size_override("font_size", 14)
	# Per-state stylebox so disabled buttons read clearly different
	var base := StyleBoxFlat.new()
	base.bg_color = Color(0.18, 0.15, 0.10, 0.95) if affordable else Color(0.10, 0.10, 0.10, 0.85)
	base.border_color = tint if affordable else Color(0.35, 0.30, 0.28, 0.6)
	base.border_width_left = 2
	base.border_width_right = 1
	base.border_width_top = 1
	base.border_width_bottom = 1
	base.corner_radius_top_left = 6
	base.corner_radius_top_right = 6
	base.corner_radius_bottom_left = 6
	base.corner_radius_bottom_right = 6
	base.content_margin_left = 8
	base.content_margin_right = 8
	base.content_margin_top = 4
	base.content_margin_bottom = 4
	var hover := base.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.30, 0.24, 0.10, 1.0)
	hover.border_color = Color(1.0, 0.95, 0.5, 1.0)
	var pressed := base.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.46, 0.32, 0.10, 1.0)
	btn.add_theme_stylebox_override("normal", base)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", base)


func _on_path_a_button_pressed() -> void:
	if not _selected_tower:
		return
	if _selected_tower.upgrade_path("a"):
		_refresh_tower_info()


func _on_path_b_button_pressed() -> void:
	if not _selected_tower:
		return
	if _selected_tower.upgrade_path("b"):
		_refresh_tower_info()


var _last_gold: int = -1
var _last_lives: int = -1
var _next_wave_pulse_tween: Tween = null


func _on_gold_changed(amount: int) -> void:
	if gold_label:
		gold_label.text = _format_gold(amount)
		# Quick pulse on gold gain (not on spend) so the player sees income
		if _last_gold >= 0 and amount > _last_gold and gold_label.get_parent():
			var pulse := gold_label.create_tween()
			pulse.tween_property(gold_label, "modulate", Color(1.5, 1.3, 0.5), 0.12)
			pulse.tween_property(gold_label, "modulate", Color.WHITE, 0.2)
		_last_gold = amount
	# Whole-row affordability feedback: disabled state uses our styled
	# disabled stylebox (darker grey), cost label goes red, and the row
	# modulate drops to 0.75 so the icon dims too. Just-barely-affordable
	# entries (player can afford but only just) pulse their cost amber
	# to invite the buy.
	for i in tower_shop.get_child_count():
		if i >= tower_data_list.size():
			continue
		var btn: Button = tower_shop.get_child(i)
		var cost: int = tower_data_list[i].buy_cost
		var affordable: bool = CurrencyManager.can_afford(cost)
		# Threshold-crossing pulse: previously unaffordable, now affordable
		# → brief gold pulse on the cost label so the player notices the
		# new option opening up. Stored in metadata to avoid an extra dict.
		var was_affordable: bool = btn.get_meta("was_affordable", true)
		if affordable and not was_affordable and i < _cost_labels.size():
			var lbl: Label = _cost_labels[i]
			var pulse := lbl.create_tween()
			pulse.tween_property(lbl, "scale", Vector2(1.25, 1.25), 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			pulse.tween_property(lbl, "scale", Vector2.ONE, 0.14)
		btn.set_meta("was_affordable", affordable)
		btn.disabled = not affordable
		btn.modulate = Color.WHITE if affordable else Color(0.7, 0.7, 0.75, 1.0)
		if i < _cost_labels.size():
			var col: Color
			if not affordable:
				col = Color(1, 0.35, 0.25)
			elif amount < int(float(cost) * 1.2):  # barely — <20% spare
				col = Color(1, 0.75, 0.3)
			else:
				col = Color(1, 0.9, 0.3)
			_cost_labels[i].add_theme_color_override("font_color", col)
	if _selected_tower:
		_refresh_tower_info()


func _on_lives_changed(amount: int) -> void:
	if lives_label:
		lives_label.text = "%d Läbe" % amount
	# Red screen-flash on life loss — big "you lost one!" cue
	if _last_lives >= 0 and amount < _last_lives:
		_flash_life_lost()
	_last_lives = amount


func _flash_life_lost() -> void:
	if SfxManager and SfxManager.has_method("play_life_lost"):
		SfxManager.play_life_lost()
	var flash := ColorRect.new()
	flash.color = Color(1.0, 0.15, 0.1, 0.35)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.anchors_preset = Control.PRESET_FULL_RECT
	flash.anchor_right = 1.0
	flash.anchor_bottom = 1.0
	add_child(flash)
	var tween := flash.create_tween()
	tween.tween_property(flash, "color:a", 0.0, 0.35)
	tween.tween_callback(flash.queue_free)


func _on_shop_tower_selected(td: TowerData, btn: Button) -> void:
	# Block + flash red if player can't afford this tower instead of
	# entering placement mode silently and frustrating them when they
	# tap to confirm.
	if td and CurrencyManager.gold < td.buy_cost:
		_flash_button_red(btn)
		show_toast("Z'wenig Gäld!")
		return
	_highlight_placing_button(btn)
	_on_tower_button_pressed(td)


func _flash_button_red(btn: Button) -> void:
	if btn == null or not is_instance_valid(btn):
		return
	var orig: Color = btn.modulate
	var tw := btn.create_tween()
	tw.tween_property(btn, "modulate", Color(1.5, 0.4, 0.4), 0.08)
	tw.tween_property(btn, "modulate", orig, 0.18)


func _highlight_placing_button(btn: Button) -> void:
	# Restore the previous button's normal style first.
	if _placing_button and is_instance_valid(_placing_button):
		if _placing_button.has_meta("shop_base_style"):
			_placing_button.add_theme_stylebox_override("normal", _placing_button.get_meta("shop_base_style"))
	_placing_button = btn
	if btn == null:
		return
	# Gold border to mark the row actively being placed.
	var sel := StyleBoxFlat.new()
	sel.bg_color = Color(0.38, 0.26, 0.02, 0.95)
	sel.border_color = Color(1.0, 0.75, 0.0, 1.0)
	sel.border_width_top = 2
	sel.border_width_bottom = 2
	sel.border_width_left = 3
	sel.border_width_right = 2
	sel.corner_radius_top_left = 8
	sel.corner_radius_top_right = 8
	sel.corner_radius_bottom_left = 8
	sel.corner_radius_bottom_right = 8
	sel.content_margin_left = 8
	sel.content_margin_right = 6
	sel.content_margin_top = 4
	sel.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal", sel)


func _on_tower_button_pressed(td: TowerData) -> void:
	hide_tower_info()
	tower_selected_for_placement.emit(td)
	set_placing(true)


func _on_next_wave_button_pressed() -> void:
	next_wave_requested.emit()
	show_next_wave_button(false)


func _on_cancel_button_pressed() -> void:
	set_placing(false)
	placement_cancelled.emit()


func _on_pause_button_pressed() -> void:
	pause_requested.emit()


func _on_auto_button_toggled(toggled_on: bool) -> void:
	auto_wave_toggled.emit(toggled_on)
	# ASCII-only suffix — the bundled web font renders many unicode bullets
	# as tofu boxes (user reported "AUTO 💵" — that's actually U+25CF tofu).
	# Brackets + plain text are universally rendered.
	var btn: Button = $TopBar/HBox/AutoButton if has_node("TopBar/HBox/AutoButton") else null
	if btn:
		btn.modulate = Color(0.4, 1.0, 0.5) if toggled_on else Color.WHITE
		btn.text = "[AUTO]" if toggled_on else "AUTO"
	SfxManager.play_click()


func _on_speed_button_pressed() -> void:
	if _game_speed == 1.0:
		_game_speed = 2.0
	elif _game_speed == 2.0:
		_game_speed = 3.0
	else:
		_game_speed = 1.0
	Engine.time_scale = _game_speed
	if speed_button:
		speed_button.text = "%d×" % int(_game_speed)  # proper × character, not lowercase x
		# Tint by speed so the current mode is visible at a glance:
		# 1x = white, 2x = warm yellow, 3x = red-hot fast-forward.
		match int(_game_speed):
			2:
				speed_button.modulate = Color(1.0, 0.85, 0.3)
			3:
				speed_button.modulate = Color(1.0, 0.4, 0.25)
			_:
				speed_button.modulate = Color.WHITE
	SfxManager.play_click()


func _on_upgrade_button_pressed() -> void:
	if _selected_tower:
		_selected_tower.upgrade()
		_refresh_tower_info()


var _sell_armed: bool = false
var _sell_arm_timer: SceneTreeTimer = null


func _on_sell_button_pressed() -> void:
	if not _selected_tower:
		return
	# Two-tap sell to prevent accidental taps from nuking an expensive
	# tower. First tap arms the button + changes text to "Sicher? ✖",
	# the arm expires after 2s. Second tap within the window sells.
	var sell_btn: Button = tower_info.get_node_or_null("VBox/HBox/SellButton") if tower_info else null
	if _sell_armed:
		_sell_armed = false
		if _sell_arm_timer and is_instance_valid(_sell_arm_timer):
			_sell_arm_timer = null
		_selected_tower.sell()
		hide_tower_info()
		return
	_sell_armed = true
	if sell_btn:
		_paint_sell_button(sell_btn)
	# Auto-disarm after 2s
	_sell_arm_timer = get_tree().create_timer(2.0)
	_sell_arm_timer.timeout.connect(_disarm_sell)


func _disarm_sell() -> void:
	_sell_armed = false
	_sell_arm_timer = null
	if tower_info and tower_info.visible:
		var sell_btn: Button = tower_info.get_node_or_null("VBox/HBox/SellButton") as Button
		if sell_btn:
			_paint_sell_button(sell_btn)


func _on_close_button_pressed() -> void:
	hide_tower_info()


func clear_toast() -> void:
	# Dismiss any in-flight placement toast. Called when placement is
	# cancelled — the error context is gone, so the toast shouldn't
	# linger through its fade delay. Playtest-feedback #104.
	for prior in get_tree().get_nodes_in_group("hud_toast"):
		if is_instance_valid(prior):
			prior.modulate.a = 0.0
			prior.queue_free()


func show_toast(message: String) -> void:
	# Single-toast policy: free any prior toast(s) before adding a new
	# one. Playtest-feedback #104 — rapid-fire invalid placements stacked
	# Labels. An earlier name-based dedup was still racy because
	# `queue_free()` is deferred: between the free call and the new
	# add_child, the prior node still exists with name "HudToast" and
	# Godot auto-suffixes the new name. Group-based iteration handles
	# the race cleanly.
	clear_toast()
	var toast := Label.new()
	toast.add_to_group("hud_toast")
	toast.text = message
	toast.add_theme_font_size_override("font_size", 30)
	toast.add_theme_color_override("font_color", Color(1, 0.35, 0.2))
	toast.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0))
	toast.add_theme_constant_override("outline_size", 6)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.anchor_left = 0.5
	toast.anchor_top = 0.55
	toast.anchor_right = 0.5
	toast.anchor_bottom = 0.55
	toast.offset_left = -220
	toast.offset_right = 220
	toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(toast)
	var tween := toast.create_tween()
	tween.tween_property(toast, "modulate:a", 0.0, 1.2).set_delay(0.4)
	tween.tween_callback(toast.queue_free)
