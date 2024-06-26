extends Node2D
# ===============================================
# メインシーン.
# ===============================================

# -----------------------------------------------
# const.
# -----------------------------------------------
## 動物落下の高さ.
const DROP_POS_Y = 60.0

## NEXT抽選用テーブル.
const NEXT_TBL = [
	Animal.eAnimal.AMOEBA, # 0
	Animal.eAnimal.JELLYFISH, # 1
	Animal.eAnimal.SQUID, # 2
	Animal.eAnimal.CRAYFISH, # 3
	Animal.eAnimal.SHARK, # 4
]

## 状態.
enum eState {
	INIT, # 初期化.
	MAIN, # メイン.
	DROP_WAIT, # 落下完了待ち.
	GAME_OVER, # ゲームオーバー.
}

# -----------------------------------------------
# onready.
# -----------------------------------------------
# ゲームオーバーの線.
@onready var _deadline = $DeadLine
# 左右の移動可能範囲.
@onready var _marker_left = $Marker/Left
@onready var _marker_right = $Marker/Right
# 補助線.
@onready var _spr_line = $Line
# CanvasLayer.
@onready var _wall_layer = $WallLayer
@onready var _animal_layer = $AnimalLayer
@onready var _particle_layer = $ParticleLayer
@onready var _ui_layer = $UILayer
# UI.
@onready var _ui_now_animal = $UILayer/NowAnimal
@onready var _ui_dbg_label = $UILayer/DbgLabel
@onready var _ui_evolution_label = $UILayer/Evolution/Label
@onready var _ui_caption = $UILayer/Caption
@onready var _ui_gauge = $UILayer/ProgressBar
@onready var _ui_next = $UILayer/Next/Sprite2D
@onready var _ui_score = $UILayer/Score
@onready var _ui_score_sub = $UILayer/Score/SubLabel
@onready var _ui_hi_score = $UILayer/HiScore
# サウンド.
@onready var _bgm = $Bgm

# -----------------------------------------------
# var.
# -----------------------------------------------
## 状態.
var _state := eState.INIT
## 現在の動物.
var _now_animal = Animal.eAnimal.AMOEBA
## 次の動物.
var _next_animal = Animal.eAnimal.AMOEBA
## 落下させた動物.
var _animal:Animal = null
## BGMの状態.
var _bgm_id = 0
## 進化の輪.
var _evolution_sprs = {}
## 進化の輪のスケール.
var _evolution_scales = {}

# -----------------------------------------------
# private function.
# -----------------------------------------------
## 開始.
func _ready() -> void:
	# レイヤーテーブル.
	var layers = {
		"wall": _wall_layer,
		"animal": _animal_layer,
		"particle": _particle_layer,
		"ui": _ui_layer,
	}
	# セットアップ.
	Common.setup(layers)

	# 進化画像のセットアップ.
	_setup_evolution()
	
	# BGM再生.
	_bgm.play()

## 進化画像のセットアップ.
func _setup_evolution() -> void:
	# 進化画像.
	_evolution_sprs[Animal.eAnimal.AMOEBA] = $UILayer/Evolution/Amoeba
	_evolution_sprs[Animal.eAnimal.JELLYFISH] = $UILayer/Evolution/Jellyfish
	_evolution_sprs[Animal.eAnimal.SQUID] = $UILayer/Evolution/Squid
	_evolution_sprs[Animal.eAnimal.CRAYFISH] = $UILayer/Evolution/Crayfish
	_evolution_sprs[Animal.eAnimal.SHARK] = $UILayer/Evolution/Shark
	_evolution_sprs[Animal.eAnimal.FROG] = $UILayer/Evolution/Frog
	_evolution_sprs[Animal.eAnimal.CROCODILE] = $UILayer/Evolution/Crocodile
	_evolution_sprs[Animal.eAnimal.OWL] = $UILayer/Evolution/Owl
	_evolution_sprs[Animal.eAnimal.PLATYPUS] = $UILayer/Evolution/Platypus
	_evolution_sprs[Animal.eAnimal.CAT] = $UILayer/Evolution/Cat
	_evolution_sprs[Animal.eAnimal.MONKEY] = $UILayer/Evolution/Monkey
	_evolution_sprs[Animal.eAnimal.FUTURE_PERSON] = $UILayer/Evolution/FuturePerson
	# 基準スケール値を保持.
	for id in _evolution_sprs.keys():
		_evolution_scales[id] = _evolution_sprs[id].scale

# 次の動物を抽選する.
func _lot_animal() -> void:
	_now_animal = _next_animal
	# コピー.
	var tbl = NEXT_TBL.duplicate()
	# シャッフル.
	tbl.shuffle()
	# NEXTの動物を設定.
	_next_animal = tbl[0]
	_ui_next.texture = Animal.get_animal_tex(_next_animal)
	_ui_next.scale = Common.get_animal_scale(_next_animal)
	
	# 落下させる動物を設定.
	_ui_now_animal.texture = Animal.get_animal_tex(_now_animal)	
	_ui_now_animal.scale = Common.get_animal_scale(_now_animal)
	_ui_now_animal.modulate.a = 0.5

## 更新.
func _process(delta: float) -> void:
	# 状態に合わせた更新.
	match _state:
		eState.INIT:
			_update_init()
		eState.MAIN:
			_update_main(delta)
		eState.DROP_WAIT:
			_update_drop_wait(delta)
		eState.GAME_OVER:
			_update_game_over()

	# UIの更新.
	_update_ui(delta)
	# デバッグの更新.
	_update_debug()

## 更新 > 初期化.
func _update_init() -> void:
	# 動物を抽選.
	_lot_animal()
	_state = eState.MAIN

## 更新 > メイン.	
func _update_main(delta) -> void:
	# ゲームオーバーゲージの更新.
	_update_dead_line_gauge()
	
	# ゲームオーバーチェック.
	if _is_gameoveer(delta):		
		# ゲームオーバー処理へ.
		_start_gameover()
		_state = eState.GAME_OVER
		return
	
	# カーソルの更新.
	_update_cursor()
	
	if Input.is_action_just_pressed("click"):
		# クリックした.
		Common.play_se("drop", 1)
		# UIとしての動物を非表示.
		_ui_now_animal.visible = false
		_spr_line.visible = false
		
		# @note 生成すると内部でレイヤーへの追加もしてくれる.
		var animal = Common.create_animal(_now_animal)
		animal.position = _ui_now_animal.position
		
		# 落下中の動物を保持 (落下完了判定用).
		_animal = animal
		# 落下完了待ち.
		_state = eState.DROP_WAIT

## 更新 > 落下完了待ち.
func _update_drop_wait(delta:float) -> void:
	
	# ゲームオーバーゲージの更新.
	_update_dead_line_gauge()

	# ゲームオーバーチェック.
	if _is_gameoveer(delta):		
		# ゲームオーバー処理へ.
		_start_gameover()
		_state = eState.GAME_OVER
		return	
	
	if _is_dropped(_animal) == false:
		return # 落下完了待ち.
	
	# 落下完了した.
	_animal = null # 参照を消しておく.
	# 動物を抽選.
	_lot_animal()
	_state = eState.MAIN

## 更新 > ゲームオーバー.
func _update_game_over() -> void:
	pass

## 更新 > カーソル.
func _update_cursor() -> void:
	# カーソル位置の計算.
	var px = get_global_mouse_position().x
	# 移動可能範囲でclamp.
	px = clamp(px, _marker_left.position.x, _marker_right.position.x)
	
	# 動物カーソルを表示.
	_ui_now_animal.visible = true
	_ui_now_animal.position.x = px	
	_ui_now_animal.position.y = DROP_POS_Y
	# 落下補助線を表示.
	_spr_line.visible = true
	_spr_line.position.x = px
	_spr_line.modulate.a = 0.5

## 指定の動物が落下完了したかどうか.
## @note 引数の型を指定するとnullのときに実行時エラーとなる.
func _is_dropped(node) -> bool:
	if is_instance_valid(node) == false:
		return true # 無効なインスタンスであれば完了したことにする.
		
	var animal = node as Animal
	if animal.is_hit_even_once():
		return true # 一度でも他のオブジェクトに接触した.
	
	# 落下完了していない.
	return false

## ゲームオーバーかどうか.
func _is_gameoveer(delta:float) -> bool:
	for obj in _animal_layer.get_children():
		var animal = obj as Animal
		if animal.check_gameover(_deadline.position.y, delta):
			# ゲームオーバー猶予時間を超えた.
			return true
	
	# ゲームオーバーでない.
	return false

## ゲームオーバー開始処理.
func _start_gameover() -> void:
	# BGMを止める.
	#_bgm.stop()
	# 物理挙動を止める.
	PhysicsServer2D.set_active(false)
	for obj in _animal_layer.get_children():
		# 動物の更新をすべて止める.
		obj.set_physics_process(false)
	
	# キャプション表示.
	_ui_caption.visible = true
	# カーソルを非表示.
	_spr_line.visible = false
	_ui_now_animal.visible = false


## 更新 > UI.
func _update_ui(delta:float) -> void:
	# スコア更新.
	_ui_score.text = "SCORE: %d"%Common.score
	_ui_hi_score.text = "HI-SCORE: %d"%Common.hi_score
	
	# 加算スコア.
	if _count_score_particle() == 0:
		# スコア演出が消えたらリセット.
		Common.disp_add_score = 0
		_ui_score_sub.visible = false
	if Common.disp_add_score > 0:
		# 加算スコアを表示.
		_ui_score_sub.visible = true
		_ui_score_sub.text = "(+%d)"%Common.disp_add_score
	
	# 動物登場タイマー反映.
	Common.update_animal_timer(delta)
	for id in _evolution_sprs.keys():
		var t = Common.get_animal_timer(id)
		var scale = _evolution_scales[id]
		if t > 0:
			var rate = 1 + Ease.elastic_out(1 - t)
			scale *= (Vector2.ONE * rate)
		_evolution_sprs[id].scale = scale
	
	# 動物の生成数をカウントする.
	var tbl = {}
	var max_id = Animal.eAnimal.AMOEBA
	for obj in _animal_layer.get_children():
		var animal = obj as Animal
		var id = animal.id
		if id in tbl:
			tbl[id] += 1 # 登録済みならカウントアップ.
		else:
			tbl[id] = 1 # 未登録なら登録する.
		if max_id < id:
			# 最のIDを更新.
			max_id = id
	
	# BGMの更新.
	if max_id >= Animal.eAnimal.FUTURE_PERSON:
		if _bgm_id < 4:
			# XBOXが出たらBGM変更.
			_bgm.stream = load("res://assets/sound/bgm/bgm05_140.mp3")
			_bgm.play()
			_bgm_id = 5
	elif max_id >= Animal.eAnimal.MONKEY:
		if _bgm_id < 3:
			# プリンが出たらBGM変更.
			_bgm.stream = load("res://assets/sound/bgm/bgm04_110.mp3")
			_bgm.play()
			_bgm_id = 3 
	elif max_id >= Animal.eAnimal.CAT:
		if _bgm_id < 2:
			# 牛乳が出たらBGM変更.
			_bgm.stream = load("res://assets/sound/bgm/bgm03_140.mp3")
			_bgm.play()
			_bgm_id = 2
	elif max_id >= Animal.eAnimal.PLATYPUS:
		if _bgm_id < 1:
			# 5箱が出たらBGM変更.
			_bgm.stream = load("res://assets/sound/bgm/bgm02_140.mp3")
			_bgm.play()
			_bgm_id = 1
	
	# 進化の輪の更新.
	_ui_evolution_label.text = ""
	var values = Animal.eAnimal.values()
	values.reverse()
	for id in values:
		var s = Animal.get_animal_name(id)
		if id in tbl:
			_ui_evolution_label.text += s + ":%d\n"%tbl[id]
		else:
			_ui_evolution_label.text += "\n"

## ゲームオーバーのラインを超えているときに表示するゲージの更新.
func _update_dead_line_gauge() -> void:
	var max_rate = 0.0 # 最大の割合.
	var max_obj:Animal = null # ゲームオーバーのライン超えしている動物.
	
	# ゲームオーバータイマーが最大のオブジェクトを探す.
	for obj in _animal_layer.get_children():
		var animal = obj as Animal
		# ゲームオーバータイマーが最大のオブジェクトにゲージをつける.
		var rate = animal.get_gameover_timer_rate()
		if rate > max_rate:
			# 最大時間の更新.
			max_rate = rate
			max_obj = animal
	
	if max_obj:
		# ゲームオーバーゲージの表示.
		var pitch = 1 - (0.5 * max_rate)
		pitch = max(0.75, pitch) # ピッチの最低値は "0.75"
		_bgm.pitch_scale = pitch # ピッチを下げる.
		AudioServer.set_bus_effect_enabled(1, 0, true) # ローパスフィルタを有効にする.
		_ui_gauge.visible = true
		_ui_gauge.value = 100 * max_rate
		_ui_gauge.position = max_obj.position
	else:
		# ゲージを消しておく.
		_ui_gauge.visible = false
		AudioServer.set_bus_effect_enabled(1, 0, false) # ローパスフィルタを無効にする.
		_bgm.pitch_scale = 1.0 # ピッチを戻す.

## スコア演出オブジェクトをカウントする.
func _count_score_particle() -> int:
	var ret = 0
	for obj in _particle_layer.get_children():
		if obj is ParticleScore:
			ret += 1
	return ret

## 更新 > デバッグ.
func _update_debug() -> void:
	if Input.is_action_just_pressed("reset"):
		# リセット.
		# 物理を有効に戻す.
		PhysicsServer2D.set_active(true)
		get_tree().change_scene_to_file("res://Main.tscn")
