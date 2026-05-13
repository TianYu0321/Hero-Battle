## res://autoload/event_bus.gd
## 模块: EventBus
## 职责: 全局信号总线，承载所有跨模块信号声明与发射
## 依赖: 无
## 被依赖: 所有模块
## class_name: EventBus

extends Node

# --- 养成循环信号 (Run & Node Lifecycle) ---
signal run_started(run_config: Dictionary)
signal run_continued(save_data: Dictionary)
signal run_ended(ending_type: String, final_score: int, archive: Dictionary)
signal scene_state_changed(from_state: String, to_state: String, transition_data: Dictionary)
signal game_paused(reason: String)
signal game_resumed

signal round_changed(current_round: int, max_round: int, phase: String)
signal floor_changed(current_floor: int, max_floor: int, floor_type: String)
signal node_options_presented(node_options: Array[Dictionary])
signal node_entered(node_type: String, node_config: Dictionary)
signal node_resolved(node_type: String, result_data: Dictionary)
signal turn_advanced(new_turn: int, phase: String, is_fixed_node: bool)
signal floor_advanced(new_floor: int, floor_type: String, is_special: bool)
signal node_selected(node_index: int)

signal training_completed(attr_code: int, attr_name: String, gain_value: int, new_total: int, proficiency_stage: String, bonus_applied: int)
signal proficiency_stage_changed(attr_code: int, attr_name: String, new_stage: String, train_count: int)

signal shop_entered(shop_inventory: Array[Dictionary])
signal shop_item_purchased(item_id: String, item_type: String, target_id: String, price: int, remaining_gold: int, new_level: int)
signal shop_exited(purchased_count: int, total_spent: int)
signal gold_changed(new_amount: int, delta: int, reason: String)

signal rescue_encountered(candidates: Array[Dictionary], rescue_turn: int)
signal partner_unlocked(partner_id: String, partner_name: String, slot: int, join_turn: int, role: String)
signal enemy_encountered(enemy_data: Dictionary)

## 局外商店信号 (Outgame Shop)
signal mojo_coin_spent(amount: int, item_id: String)
signal outgame_shop_opened
signal outgame_shop_closed

signal pvp_match_found(opponent_data: Dictionary)
signal pvp_battle_started(allies: Array, enemies: Array, playback_mode: String)
signal pvp_result(result: Dictionary)
signal pvp_lobby_requested
signal mocheng_coin_changed(current: int, delta: int, reason: String)

# --- 战斗信号 (Battle Lifecycle) ---
signal battle_started(allies: Array, enemies: Array, battle_config: Dictionary)
signal battle_ended(battle_result: Dictionary)
signal battle_state_changed(new_state: String, prev_state: String)

signal battle_turn_started(turn_number: int, round_effects: Array, playback_mode: String)
signal action_order_calculated(action_sequence: Array[Dictionary])
signal battle_turn_ended(turn_number: int, turn_chain_count: int, chain_total: int)
signal unit_turn_started(unit_id: String, unit_name: String, is_player_controlled: bool, unit_type: String)

signal action_executed(action_data: Dictionary)
signal unit_damaged(unit_id: String, amount: int, current_hp: int, max_hp: int, damage_type: String, is_crit: bool, is_miss: bool, attacker_id: String)
signal unit_healed(unit_id: String, amount: int, current_hp: int, max_hp: int, heal_type: String)
signal unit_died(unit_id: String, unit_name: String, unit_type: String, killer_id: String)
signal damage_number_spawned(position: Dictionary, amount: int, damage_type: String, is_crit: bool, is_miss: bool, chain_count: int)

signal partner_assist_triggered(partner_id: String, partner_name: String, trigger_type: String, assist_result: Dictionary, assist_count_this_battle: int)
signal partner_assist_skipped(reason: String, checked_count: int)

signal chain_triggered(chain_count: int, partner_id: String, partner_name: String, damage: int, chain_multiplier: float, total_chains_this_battle: int)
signal chain_ended(total_chains_this_turn: int, total_chains_this_battle: int, interrupt_reason: String)
signal chain_interrupted(reason: String, current_chain_count: int, partner_limit_status: Dictionary)

signal ultimate_triggered(hero_class: String, hero_name: String, trigger_turn: int, trigger_condition: String, ultimate_name: String)
signal ultimate_executed(hero_class: String, ultimate_name: String, execution_log: Array[Dictionary])
signal ultimate_condition_checked(hero_class: String, condition_results: Dictionary, was_triggered: bool, already_used: bool)

signal frenzy_triggered(turn_number: int)

signal buff_applied(unit_id: String, buff_id: String, buff_name: String, duration: int, effect_desc: String, buff_type: String)
signal buff_removed(unit_id: String, buff_id: String, buff_name: String, reason: String)
signal status_ticked(unit_id: String, tick_type: String, value: int, remaining_duration: int)
signal enemy_action_decided(enemy_id: String, enemy_name: String, action_type: String, target_id: String, target_name: String, skill_name: String, enemy_template: String)

# --- 角色管理信号 (Character & Stats) ---
signal stats_changed(unit_id: String, stat_changes: Dictionary)
signal hero_level_changed(old_level: int, new_level: int)
signal partner_evolved(partner_id: String, partner_name: String, new_level: int, unlocked_skill: String, evolution_tier: String)
signal partner_level_changed(partner_id: String, old_level: int, new_level: int)
signal skill_milestone_reached(partner_id: String, milestone: int, effect: String)
signal hero_skill_milestone_reached(milestone: int, effect: String)
signal skill_learned(unit_id: String, skill_id: String, skill_name: String, skill_type: String)
signal skill_triggered(unit_id: String, skill_id: String, skill_name: String, trigger_context: Dictionary)

# --- UI 控制信号 ---
signal panel_opened(panel_name: String, panel_data: Dictionary)
signal panel_closed(panel_name: String, close_reason: String)
signal panel_stack_changed(stack: Array[String], top_panel: String)
signal all_panels_closed(trigger: String)

signal new_game_requested(hero_id: String)
signal continue_game_requested
signal back_to_menu_requested
signal back_to_hero_select
signal hero_selected(hero_id: String)
signal team_confirmed(partner_ids: Array[String])
signal archive_view_requested(archive_id: String)
signal shop_requested
signal rescue_partner_selected(candidate_index: int, partner_id: String)
signal shop_purchase_requested(item_index: int, item_id: String, target_id: String)
signal shop_exit_requested
signal tavern_confirmed(selected_partner_ids: Array[String])
signal player_action_selected(action_type: String, target_id: String, skill_id: String)
signal battle_speed_changed(speed: float)
signal skip_animation_requested
signal abandon_run_requested

signal hud_stats_refresh(hero_data: Dictionary, partners: Array[Dictionary], gold: int, current_turn: int, phase: String)
signal hud_log_appended(message: String, log_type: String, timestamp: int)
signal hud_partner_list_changed(partners: Array[Dictionary])

# --- 系统信号 (System) ---
signal game_saved(save_slot: int, save_timestamp: int, turn: int, is_auto: bool)
signal save_loaded(save_data: Dictionary)
signal game_loaded(save_data: Dictionary)
signal save_failed(error_code: int, error_message: String, save_context: Dictionary)
signal load_failed(error_code: int, error_message: String, save_slot: int)
signal archive_generated(archive: Dictionary)
signal archive_saved(archive_data: Dictionary)
signal leaderboard_updated(leaderboard: Array[Dictionary])
signal error_occurred(error_code: String, error_message: String, source_module: String)
signal warning_issued(warning_code: String, message: String, source_module: String)
signal audio_play_requested(audio_type: String, audio_name: String, volume: float)
