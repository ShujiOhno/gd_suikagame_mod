extends Node
# ===============================================
# 共通スクリプト.
# ===============================================
# ----------------------------------------
# consts
# ----------------------------------------
## 同時再生可能なサウンドの数.
const MAX_SOUND = 8

## 動物登場タイマー.
const TIMER_ANIMAL_APPEAR = 1.0

### SEテーブル.
var _snd_tbl = {
	"drop": "res://assets/sound/se/drop.wav",
	"merge": "res://assets/sound/se/merge.wav",
}

# -----------------------------------------------
# preload.
# -----------------------------------------------
## 動物テーブル.
const ANIMAL_TBL = {
	Animal.eAnimal.AMOEBA: preload("res://src/animal/AnimalAmoeba.tscn"),
	Animal.eAnimal.JELLYFISH: preload("res://src/animal/AnimalJellyfish.tscn"),
	Animal.eAnimal.SQUID: preload("res://src/animal/AnimalSquid.tscn"),
	Animal.eAnimal.CRAYFISH: preload("res://src/animal/AnimalCrayfish.tscn"),
	Animal.eAnimal.SHARK: preload("res://src/animal/AnimalShark.tscn"),
	Animal.eAnimal.FROG: preload("res://src/animal/AnimalFrog.tscn"),
	Animal.eAnimal.CROCODILE: preload("res://src/animal/AnimalCrocodile.tscn"),
	Animal.eAnimal.OWL: preload("res://src/animal/AnimalOwl.tscn"),
	Animal.eAnimal.PLATYPUS: preload("res://src/animal/AnimalPlatypus.tscn"),
	Animal.eAnimal.CAT: preload("res://src/animal/AnimalCat.tscn"),
	Animal.eAnimal.MONKEY: preload("res://src/animal/AnimalMonkey.tscn"),
	Animal.eAnimal.FUTURE_PERSON: preload("res://src/animal/AnimalFuturePerson.tscn"),	
}

# -----------------------------------------------
# var.
# -----------------------------------------------
var _snds:Array = []

## CanvasLayer.
var _layers = {}

## 動物のスケールテーブル.
var _scale_tbl = {}

## 動物の登場タイマーテーブル.
var _animal_timers = {}

## スコア.
var score:int = 0
## ハイスコア.
var hi_score:int = 0
## 表示用加算スコア.
var disp_add_score:int = 0

# -----------------------------------------------
# public function.
# -----------------------------------------------
## セットアップ.
func setup(layers) -> void:
	# スコア初期化.
	score = 0
	# 動物タイマー初期化.
	_animal_timers.clear()
	_layers = layers
	
	# AudioStreamPlayerをあらかじめ作っておく.
	## SE.
	for i in range(MAX_SOUND):
		var snd = AudioStreamPlayer.new()
		snd.bus = "SE"
		#snd.volume_db = -4
		add_child(snd)
		_snds.append(snd)

## レイヤーの取得.
func get_layer(layer_name:String) -> CanvasLayer:
	return _layers[layer_name]
	
## スコア加算.
## @return 加算したスコアの値.
func add_score(id:Animal.eAnimal) -> int:
	# スコアの式は Σ(n-1)らしい....
	var v = 0
	for i in range(id, 0, -1):
		v += i
	score += v
	if score > hi_score:
		hi_score = score
	
	return v

## 動物の生成.
## @note ※遅延生成をする場合のみスコアが加算されます.
## @param id 動物ID.
## @param is_deferred 遅延生成するかどうか.
## @param particle/pos スコアパーティクルを生成するときの座標.
func create_animal(id:Animal.eAnimal, is_deferred:bool=false, particle_pos:Vector2=Vector2.ZERO) -> Animal:
	# PackedSceneを取得.
	var packed = ANIMAL_TBL[id]
	var animal = packed.instantiate()
	var layer = get_layer("animal")
	if is_deferred:
		# RigidBody2D の body_entered シグナルで
		# add_child()するとエラーとなるっぽい.
		# そのため遅延処理で対処する.
		layer.call_deferred("add_child", animal)
		# 動物タイマー設定.
		_animal_timers[id] = TIMER_ANIMAL_APPEAR
		# スコア加算.
		var score = add_score(id)
		# スコア演出生成.
		ParticleUtil.add_score(particle_pos, score)
		# 表示用加算スコア.
		disp_add_score += score
		# マージSE.
		Common.play_se("merge", 2)
	else:
		layer.add_child(animal)
	
	return animal
	
## 動物登場タイマーの更新.
func update_animal_timer(delta:float) -> void:
	for id in _animal_timers.keys():
		if _animal_timers[id] > 0:
			_animal_timers[id] -= delta
## 動物登場タイマーの取得.
func get_animal_timer(id:Animal.eAnimal) -> float:
	var ret = 0.0
	if id in _animal_timers:
		ret = _animal_timers[id]
	return max(ret, 0)

## 動物の基準スケール値を取得する.
func get_animal_scale(id:Animal.eAnimal) -> Vector2:
	if id in _scale_tbl:
		# すでに登録済みならその値を使う.
		return _scale_tbl[id]
	
	# PackedSceneを取得.
	var packed:PackedScene = ANIMAL_TBL[id]
	var animal = packed.instantiate()
	# 登録してすぐに消す.
	add_child(animal)
	animal.queue_free()
	var scale = animal.get_sprite_scale()
	# テーブルに登録.
	_scale_tbl[id] = scale
	return scale

## SEの再生.
## @note _sndsに事前登録が必要.
## @param 再生するSEの名前
func play_se(key:String, id:int=0) -> void:
	if id < 0 or MAX_SOUND <= id:
		push_error("不正なサウンドID %d"%id)
		return
	
	if not key in _snd_tbl:
		push_error("存在しないサウンド %s"%key)
		return
	
	var snd = _snds[id]
	snd.stream = load(_snd_tbl[key])
	snd.play()

# -----------------------------------------------
# private function.
# -----------------------------------------------
