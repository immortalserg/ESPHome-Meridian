# ESPHome-Meridian

20241627.png

Прошивка esp32 для управления усилителем Meridian 561 через порт RS232
Реализованы кнопки громкости, громкость и выбор источника.

Meridian.yaml - файл прошивки ESP32

meridian.sh - bash скрипт для прослушивания порта эмулирует ответы меридиана по изменению громкости и источника

Meridian_emulator_node_red - поток для Node-red эмулирует ответы меридиана по изменению громкости и источника

Если надо в HomeAssistant устройство медиаплеер которое будет управлять громкостью (например для умного дома Яндекс так как просто передать в УДЯ number не получиться) то в configuration.yaml надо добавить:
```
media_player:
  - platform: universal
    name: "Meridian Media Player"
    unique_id: meridian_player
    commands:
      turn_on:
        service: switch.turn_on
        target:
          entity_id: switch.play_pause
      turn_off:
        service: switch.turn_off
        target:
          entity_id: switch.play_pause
      volume_set:
        service: number.set_value
        data:
          entity_id: number.meridian_esp32_volume_control
          value: "{{ (volume_level * 99) | round(0) }}"
    attributes:
      volume_level: "{{ (states('number.meridian_esp32_volume_control') | float(default=50)) / 99 }}"
    state_template: "on"
    supported_features: 4
```
