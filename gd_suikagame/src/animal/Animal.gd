extends RigidBody2D
# ===============================================
# 動物オブジェクト.
# ===============================================
class_name Animal

# -----------------------------------------------
# const.
# -----------------------------------------------
const TIMER_HIT = 0.5 # ヒット時の点滅時間.
const TIMER_SCALE = 0.3 # 出現時のスケール.
# ライン超えのリミット.
# (_progress()で減算されるので実質3秒)
const TIMER_GAMEOVER = 3.0 * 2

## 動物の種類.
## このIDの並び＝進化テーブル
enum eAnimal {
	AMOEBA,       # 0: 単細胞生物 アメーバ
	JELLYFISH,    # 1: 多細胞生物 クラゲ
	SQUID,        # 2: 軟体動物 イカ
	CRAYFISH,     # 3: 節足動物 ザリガニ
	SHARK,        # 4: 魚類 サメ
	FROG,         # 5: 両生類 カエル
	CROCODILE,    # 6: 爬虫類 ワニ
	OWL,          # 7: 鳥類 フクロウ
	PLATYPUS,     # 8: 原始哺乳類 カモノハシ
	CAT,          # 9: 哺乳類 ネコ
	MONKEY,       # 10: 霊長類 サル
	FUTURE_PERSON # 11: 未来人 とりあえずサイバーな感じで
}

## 名前テーブル.
const NAMES = {
	eAnimal.AMOEBA: "アメーバ", # 0
	eAnimal.JELLYFISH: "クラゲ", # 1
	eAnimal.SQUID: "イカ", # 2
	eAnimal.CRAYFISH: "ザリガニ", # 3
	eAnimal.SHARK: "サメ", # 4
	eAnimal.FROG: "カエル", # 5
	eAnimal.CROCODILE: "ワニ", # 6
	eAnimal.OWL: "フクロウ", # 7
	eAnimal.PLATYPUS: "カモノハシ", # 8
	eAnimal.CAT: "ネコ", # 9
	eAnimal.MONKEY: "サル", # 10
	eAnimal.FUTURE_PERSON: "未来人", # 11
}

## テクスチャテーブル.
const TEXTURES = {
	eAnimal.AMOEBA: "res://assets/images/animals/amoeba.png", # 0
	eAnimal.JELLYFISH: "res://assets/images/animals/jellyfish.png", # 1
	eAnimal.SQUID: "res://assets/images/animals/squid.png", # 2
	eAnimal.CRAYFISH: "res://assets/images/animals/crayfish.png", # 3
	eAnimal.SHARK: "res://assets/images/animals/shark.png", # 4
	eAnimal.FROG: "res://assets/images/animals/frog.png", # 5
	eAnimal.CROCODILE: "res://assets/images/animals/crocodile.png", # 6
	eAnimal.OWL: "res://assets/images/animals/owl.png", # 7
	eAnimal.PLATYPUS: "res://assets/images/animals/platypus.png", # 8
	eAnimal.CAT: "res://assets/images/animals/cat.png", # 9
	eAnimal.MONKEY: "res://assets/images/animals/monkey.png", # 10
	eAnimal.FUTURE_PERSON: "res://assets/images/animals/future_person.png", # 11
}

# -----------------------------------------------
# export.
# -----------------------------------------------
## 動物ID.
@export var id:eAnimal

# -----------------------------------------------
# onready.
# -----------------------------------------------
@onready var _spr = $Sprite

# -----------------------------------------------
# var.
# -----------------------------------------------
var _base_scale:Vector2
var _gameover_timer = 0.0 # ゲームオーバータイマー.
var _hit_count = 0 # 他のオブジェクトと衝突した回数.
var _scale_timer = 0.0 # 拡大縮小タイマー.

# -----------------------------------------------
# static functions.
# -----------------------------------------------
## 動物の名前を取得.
static func get_animal_name(id:eAnimal) -> String:
	return NAMES[id]

## 動物の画像を取得.
static func get_animal_tex(id:eAnimal) -> Texture:
	return load(TEXTURES[id])

# -----------------------------------------------
# public functions.
# -----------------------------------------------
## スプライトのスケール値を取得する.
func get_sprite_scale() -> Vector2:
	return _spr.scale

## 一度でもヒットしたかどうか.
func is_hit_even_once() -> bool:
	return _hit_count > 0

## 出現時のスケール開始.
func start_scale() -> void:
	_scale_timer = TIMER_SCALE

## ゲームオーバーのラインを超えているかどうか.
func check_gameover(y:float, delta:float) -> bool:
	if is_hit_even_once() == false:
		return false # ヒットしていなければ対象外.
		
	if position.y < y:
		# ライン超えしている
		# 猶予時間.
		_gameover_timer += (delta * 2)
		if _gameover_timer > TIMER_GAMEOVER:
			# ライン超え.
			return true
	
	# セーフ.
	return false

## ライン超え時間の割合 (0.0〜1.0)
func get_gameover_timer_rate() -> float:
	return _gameover_timer / (TIMER_GAMEOVER)

# -----------------------------------------------
# private functions.
# -----------------------------------------------
## 開始.
func _ready() -> void:
	# 基準のスケール値を保存.
	_base_scale = get_sprite_scale()

## 更新.
func _physics_process(delta: float) -> void:
	
	# 拡大縮小演出.
	_spr.scale = _base_scale
	if _scale_timer > 0:
		_scale_timer -= delta
		var rate = _scale_timer / TIMER_SCALE
		rate = 1 + 0.1 * Ease.back_out(1 - rate)
		_spr.scale *= Vector2(rate, rate)
	
	# ゲームオーバー赤点滅演出.
	_spr.modulate = Color.WHITE
	if _gameover_timer > 0:
		var rate = 1 - (_gameover_timer / TIMER_HIT)
		_gameover_timer -= delta
		var color = Color.RED
		_spr.modulate = color.lerp(Color.WHITE, rate)
		
# -----------------------------------------------
# signal.
# -----------------------------------------------

## 他の剛体と衝突した.
func _on_body_entered(body: Node) -> void:
	# ヒット回数をカウント.
	_hit_count += 1
	
	if not body is Animal:
		return # 動物でない
	if self.is_queued_for_deletion():
		return # すでに破棄要求されている.
	if body.is_queued_for_deletion():
		return # すでに破棄要求されている.
		
	# 動物とヒットした.
	var other = body as Animal
	if id != other.id:
		return # 一致していないので何も起こらない.
	
	# IDが一致していたら合成可能.
	if id < eAnimal.FUTURE_PERSON:
		# とりあえず中間地点に動物を生成する.
		var pos = (position + other.position)/2
		# このシグナル内で生成する場合は
		# 遅延処理をしなければならない.
		var is_deferred = true
		# 進化するのでid+1
		var animal = Common.create_animal(id+1, is_deferred, pos)
		animal.position = pos
		animal.start_scale()
	else:
		# FuturePerson同士は消せない.
		return
	
	# お互いに消滅する.
	queue_free()
	other.queue_free()
