#!/bin/bash

PORT="/dev/ttyUSB0"
BAUD_RATE="9600"
INITIAL_VOLUME=50
TIMEOUT=1  # секунд без данных для завершения команды

if [ ! -c "$PORT" ]; then
    echo "Ошибка: Порт $PORT не найден." >&2
    exit 1
fi

if [ ! -r "$PORT" ] || [ ! -w "$PORT" ]; then
    echo "Ошибка: Нет доступа к $PORT" >&2
    exit 1
fi

NN=$INITIAL_VOLUME
[[ $NN -lt 1 ]] && NN=1
[[ $NN -gt 99 ]] && NN=99

echo "Порт: $PORT, Скорость: $BAUD_RATE"
echo "Начальная громкость: $NN"
echo "Ожидание команд VP / VM / VNnn (через \\r или паузу)"
echo "--- Лог ---"

stty_orig=$(stty -g -F "$PORT")
stty -F "$PORT" "$BAUD_RATE" raw -echo cs8 -cstopb -parenb min 1 time 0 || exit 1

trap 'stty -F "$PORT" "$stty_orig"; echo -e "\nВыход"; exit 0' SIGINT SIGTERM EXIT

exec 3<> "$PORT"

buffer=""
last_input_time=$(date +%s)

process_buffer() {
    local command="$1"
    [[ -z "$command" ]] && return

    echo -n " [Команда: $command] "

    response=""

    case "$command" in
        "VP")
            (( NN < 99 )) && ((NN++))
            echo "→ Громкость: $NN"
            response=$'\r'"VOLUME    $(printf "%02d" $NN)"$'\r'
            ;;

        "VM")
            (( NN > 1 )) && ((NN--))
            echo "→ Громкость: $NN"
            response=$'\r'"VOLUME    $(printf "%02d" $NN)"$'\r'
            ;;

        VN[0-9][0-9])
            nn="${command:2:2}"
            if [[ "$nn" =~ ^[0-9]{2}$ && $nn -ge 1 && $nn -le 99 ]]; then
                NN="$nn"
                echo "→ Установлена: $NN"
            else
                echo "→ Некорректное значение: $nn"
            fi
            response=$'\r'"VOLUME    $(printf "%02d" $NN)"$'\r'
            ;;

        *)
            echo "→ Неизвестная команда"
            ;;
    esac

    if [[ -n "$response" ]]; then
        printf "%s" "$response" >&3
        echo "Отправлен ответ: VOLUME    $(printf "%02d" $NN)"
    fi
}

while true; do
    if read -r -n 1 -t 0.1 char <&3; then
        buffer+="$char"
        printf "%s" "$char"
        last_input_time=$(date +%s)

        if [[ "$char" == $'\r' ]]; then
            command="${buffer%$'\r'}"
            process_buffer "$command"
            buffer=""
        fi
    else
        now=$(date +%s)
        delta=$((now - last_input_time))
        if [[ $delta -ge $TIMEOUT && -n "$buffer" ]]; then
            process_buffer "$buffer"
            buffer=""
        fi
    fi
done
