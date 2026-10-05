extends CharacterBody2D

var player_in_range: bool
var dialogue_num = 0


func _physics_process(delta: float) -> void:
	if player_in_range and Input.is_action_just_pressed("Interact"):
		dialogue_num += 1

		if dialogue_num == 1:
			$ColorRect/MarginContainer/RichTextLabel.text = "Hello!"

		elif dialogue_num == 2:
			$ColorRect/MarginContainer/RichTextLabel.text = "Your job is to protect the king from assasins while making sure he doesn't get distracted."

		elif dialogue_num == 3:
			$ColorRect/MarginContainer/RichTextLabel.text = "Good luck!"

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body == Global.player_node:
		player_in_range = true
		$ColorRect.show()
		$ColorRect/MarginContainer/RichTextLabel.text = "Press E to interact"


func _on_area_2d_body_exited(body: Node2D) -> void:
	if body == Global.player_node:
		player_in_range = false
		dialogue_num = 0
		$ColorRect.hide()
