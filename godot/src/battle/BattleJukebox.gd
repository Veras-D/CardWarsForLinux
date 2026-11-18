extends Node
class_name BattleJukebox

## Audio manager for Battle phases matching Unity's BattleJukeboxScript.
## Sequence:
##   1. Battle Intro starts -> stop map BGM, play SFX_Intro_Battle.wav
##   2. Intro finishes      -> play Opponent's BattleMusic from db_Characters.json
##   3. Match ends (KO)     -> crossfade to BattleEndTheme (LSP.wav)

const INTRO_SFX_PATH := "res://assets/audio/sfx/SFX_Intro_Battle.wav"
const BATTLE_END_BGM_PATH := "res://assets/audio/bgm/LSP.wav"
const DEFAULT_BATTLE_BGM_PATH := "res://assets/audio/bgm/Finn.wav"

const TRACK_ALIASES: Dictionary = {
	"BMO": "BMO",
	"Bubblegum": "Bubblegum",
	"Finn": "Finn",
	"IceKing": "IceKing",
	"Jake": "Jake",
	"Lemongrab": "Lemongrab",
	"Marceline": "Marceline",
	"LSP": "LSP",
	"Fire": "Finn",
}


func play_intro_sequence() -> void:
	if Audio:
		Audio.stop_bgm(0.25)
		if ResourceLoader.exists(INTRO_SFX_PATH):
			Audio.play_sfx(load(INTRO_SFX_PATH), -2.0)


func resolve_battle_bgm_path(opponent_id: String, quest_type: String = "") -> String:
	var track_key := ""
	if Database:
		var ch: Dictionary = Database.get_character(opponent_id)
		track_key = str(ch.get("battle_music", "")).strip_edges()
	if track_key == "":
		track_key = TRACK_ALIASES.get(opponent_id, "Finn")
	var mapped: String = TRACK_ALIASES.get(track_key, track_key)
	var candidate := "res://assets/audio/bgm/%s.wav" % mapped
	if ResourceLoader.exists(candidate):
		return candidate
	if quest_type == "fc" and ResourceLoader.exists("res://assets/audio/bgm/FC_MapMenu.wav"):
		return "res://assets/audio/bgm/FC_MapMenu.wav"
	return DEFAULT_BATTLE_BGM_PATH


func play_battle_theme(opponent_id: String, quest_type: String = "") -> void:
	if not Audio:
		return
	var bgm_path := resolve_battle_bgm_path(opponent_id, quest_type)
	if ResourceLoader.exists(bgm_path):
		Audio.play_bgm(load(bgm_path), 0.7)


func play_battle_end_theme() -> void:
	if not Audio:
		return
	if ResourceLoader.exists(BATTLE_END_BGM_PATH):
		Audio.play_bgm(load(BATTLE_END_BGM_PATH), 0.6)
