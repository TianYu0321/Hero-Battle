import pathlib

path = pathlib.Path('scenes/run_main/battle_animation_panel.gd')
text = path.read_text(encoding='utf-8')

old1 = (
    '\t\t\t\t\t\tif is_crit:\n'
    '\t\t\t\t\t\t\tVFX.critical_hit(hero_card.global_position + hero_card.size / 2)\n'
    '\t\t\t\t\t\t\tHitPause.trigger(80.0)\n'
    '\t\t\t\t\t\telse:\n'
    '\t\t\t\t\t\t\tHitPause.trigger(50.0)'
)
new1 = (
    '\t\t\t\t\t\tif is_crit:\n'
    '\t\t\t\t\t\t\tVFX.critical_hit(hero_card.global_position + hero_card.size / 2)\n'
    '\t\t\t\t\t\telse:\n'
    '\t\t\t\t\t\t\tHitPause.trigger(50.0)'
)

old2 = (
    '\t\t\t\t\t\tif is_crit:\n'
    '\t\t\t\t\t\t\tVFX.critical_hit(enemy_card.global_position + enemy_card.size / 2)\n'
    '\t\t\t\t\t\t\tHitPause.trigger(80.0)\n'
    '\t\t\t\t\t\telse:\n'
    '\t\t\t\t\t\t\tHitPause.trigger(50.0)'
)
new2 = (
    '\t\t\t\t\t\tif is_crit:\n'
    '\t\t\t\t\t\t\tVFX.critical_hit(enemy_card.global_position + enemy_card.size / 2)\n'
    '\t\t\t\t\t\telse:\n'
    '\t\t\t\t\t\t\tHitPause.trigger(50.0)'
)

if old1 in text:
    text = text.replace(old1, new1, 1)
    print('Fixed hero branch')
else:
    print('Hero branch NOT found')

if old2 in text:
    text = text.replace(old2, new2, 1)
    print('Fixed enemy branch')
else:
    print('Enemy branch NOT found')

path.write_text(text, encoding='utf-8')
