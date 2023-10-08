extends Node2D
# ===============================================
# メインシーン.
# ===============================================

# -----------------------------------------------
# const.
# -----------------------------------------------
## フルーツ落下の高さ.
const DROP_POS_Y = 120.0

## NEXT抽選用テーブル.
const NEXT_TBL = [
	Fruit.eFruit.BULLET, # 0:敵弾.
	Fruit.eFruit.CARROT, # 1:人参.
	Fruit.eFruit.RADISH, # 2:大根.
	Fruit.eFruit.POCKY, # 3:ポッキー.
	Fruit.eFruit.BANANA, # 4:バナナ.
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
@onready var _deadline = $DeadLine
@onready var _marker_left = $Marker/Left
@onready var _marker_right = $Marker/Right
@onready var _wall_layer = $WallLayer
@onready var _fruit_layer = $FruitLayer
@onready var _spr_line = $Line
@onready var _ui_layer = $UILayer
@onready var _ui_now_fruit = $UILayer/NowFruit
@onready var _ui_dbg_label = $UILayer/DbgLabel
@onready var _ui_evolution_label = $UILayer/Evolution/Label
@onready var _ui_caption = $UILayer/Caption
@onready var _ui_gauge = $UILayer/ProgressBar

# -----------------------------------------------
# var.
# -----------------------------------------------
## 状態.
var _state := eState.INIT
## 現在のフルーツ.
var _now_fruit = Fruit.eFruit.BULLET
## 次のフルーツ.
var _next_fruit = Fruit.eFruit.BULLET
## 落下させたフルーツ.
var _fruit:Fruit = null

# -----------------------------------------------
# private function.
# -----------------------------------------------
## 開始.
func _ready() -> void:
	# レイヤーテーブル.
	var layers = {
		"wall": _wall_layer,
		"fruit": _fruit_layer,
		"ui": _ui_layer,
	}
	# セットアップ.
	Common.setup(layers)
	
# 次のフルーツを抽選する.
# ※正確には次の次のフルーツ.
func _lot_fruit() -> void:
	_now_fruit = _next_fruit
	# コピー.
	var tbl = NEXT_TBL.duplicate()
	# シャッフル.
	tbl.shuffle()
	# 設定.
	_next_fruit = tbl[0]
	
	_ui_now_fruit.texture = Fruit.get_fruit_tex(_now_fruit)	
	_ui_now_fruit.scale = Common.get_fruit_scale(_now_fruit)
	_ui_now_fruit.modulate.a = 0.5

## 更新.
func _process(delta: float) -> void:
	match _state:
		eState.INIT:
			_update_init()
		eState.MAIN:
			_update_main(delta)
		eState.DROP_WAIT:
			_update_drop_wait(delta)
		eState.GAME_OVER:
			_update_game_over()

	_update_ui()
	_update_debug()

## 更新 > 初期化.
func _update_init() -> void:
	# フルーツを抽選.
	_lot_fruit()
	_state = eState.MAIN

## 更新 > メイン.	
func _update_main(delta) -> void:
	# ゲームオーバーチェック.
	if _is_gameoveer(delta):		
		# ゲームオーバー処理へ.
		_start_gameover()
		_state = eState.GAME_OVER
		return
	
	# カーソルの更新.
	_update_cursor()
	
	if Input.is_action_just_pressed("click"):
		# UIとしてのフルーツを非表示.
		_ui_now_fruit.visible = false
		_spr_line.visible = false
		
		# @note 生成すると内部でレイヤーへの追加もしてくれる.
		var fruit = Common.create_fruit(_now_fruit)
		fruit.position = _ui_now_fruit.position
		
		# 落下中のフルーツを保持 (落下完了判定用).
		_fruit = fruit
		# 落下完了待ち.
		_state = eState.DROP_WAIT

## 更新 > 落下完了待ち.
func _update_drop_wait(delta:float) -> void:
	# ゲームオーバーチェック.
	if _is_gameoveer(delta):		
		# ゲームオーバー処理へ.
		_start_gameover()
		_state = eState.GAME_OVER
		return	
	
	if _is_dropped(_fruit) == false:
		return # 落下完了待ち.
	
	# 落下完了した.
	_fruit = null # 参照を消しておく.
	# フルーツを抽選.
	_lot_fruit()
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
	
	# フルーツカーソルを表示.
	_ui_now_fruit.visible = true
	_ui_now_fruit.position.x = px	
	_ui_now_fruit.position.y = DROP_POS_Y
	# 落下補助線を表示.
	_spr_line.visible = true
	_spr_line.position.x = px
	_spr_line.modulate.a = 0.5

## 指定のフルーツが落下完了したかどうか.
## @note 引数の型を指定するとnullのときに実行時エラーとなる.
func _is_dropped(node) -> bool:
	if is_instance_valid(node) == false:
		return true # 無効なインスタンスであれば完了したことにする.
		
	var fruit = node as Fruit
	if fruit.is_hit_even_once():
		return true # 一度でも他のオブジェクトに接触した.
	
	# 落下完了していない.
	return false

## ゲームオーバーかどうか.
func _is_gameoveer(delta:float) -> bool:
	var max_rate = 0.0
	var max_obj:Fruit = null
	_ui_gauge.visible = false
	
	for obj in _fruit_layer.get_children():
		var fruit = obj as Fruit
		if fruit.check_gameover(_deadline.position.y, delta):
			return true
		# 少し強引だけれどもゲームオーバータイマーが最大のオブジェクトにゲージをつける.
		var rate = fruit.get_gameover_timer_rate()
		if rate > max_rate:
			# 最大時間の更新.
			max_rate = rate
			max_obj = fruit
	
	if max_obj:
		# ゲームオーバーゲージの表示.
		_ui_gauge.visible = true
		_ui_gauge.value = 100 * max_rate
		_ui_gauge.position = max_obj.position
	
	return false

## ゲームオーバー開始処理.
func _start_gameover() -> void:
	# 物理挙動を止める.
	PhysicsServer2D.set_active(false)
	for obj in _fruit_layer.get_children():
		# フルーツの更新をすべて止める.
		obj.set_physics_process(false)
	
	# キャプション表示.
	_ui_caption.visible = true
	# カーソルを非表示.
	_spr_line.visible = false
	_ui_now_fruit.visible = false


## 更新 > UI.
func _update_ui() -> void:
	# フルーツの生成数をカウントする.
	var tbl = {}
	for obj in _fruit_layer.get_children():
		var fruit = obj as Fruit
		var id = fruit.id
		if id in tbl:
			tbl[id] += 1 # 登録済みならカウントアップ.
		else:
			tbl[id] = 1 # 未登録なら登録する.
	_ui_evolution_label.text = ""
	var values = Fruit.eFruit.values()
	values.reverse()
	for id in values:
		var s = Fruit.get_fruit_name(id)
		if id in tbl:
			_ui_evolution_label.text += s + ":%d\n"%tbl[id]
		else:
			_ui_evolution_label.text += "\n"
	
## 更新 > デバッグ.
func _update_debug() -> void:
	if Input.is_action_just_pressed("reset"):
		# リセット.
		# 物理を有効に戻す.
		PhysicsServer2D.set_active(true)
		get_tree().change_scene_to_file("res://Main.tscn")
