extends Control

# LabelVolumeノードへの参照を保持する変数
@onready var label_volume: Label = $LabelVolume

# オーディオバスのindexを格納する変数
var bus_index: int

# ゲーム開始時に実行される処理
func _ready():
	# オーディオバスのindexを取得
	bus_index = AudioServer.get_bus_index('Master')
	# 初期音量を0に設定
	_on_volume_slider_value_changed(0)

# ボタンが押されたときに呼び出されるメソッド
func _on_button_start_pressed():
	# メインゲーム画面へ遷移
	get_tree().change_scene_to_file("res://Main.tscn")

# スライダーの値が変更されたときに呼び出されるメソッド
func _on_volume_slider_value_changed(value):
	# オーディオバスの音量を設定
	# value は 0 から 1 の範囲の線形値で、デシベル値に変換
	AudioServer.set_bus_volume_db(
		bus_index,
		linear_to_db(value)
	)
	# LabelVolumeのテキストを更新
	# 音量の値を0から100の範囲で表示
	label_volume.text = "音量: %d" % round(value * 100)
