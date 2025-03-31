#!/bin/bash
PORT="/dev/ttyUSB1"
BAUD_RATE="9600"
INITIAL_VOLUME=50 
if [ ! -c "$PORT" ]; then
    echo "Ошибка: Последовательный порт $PORT не найден." >&2
    echo "Убедитесь, что устройство подключено и порт указан верно." >&2
    exit 1
fi
if [ ! -r "$PORT" ] || [ ! -w "$PORT" ]; then
    echo "Ошибка: Недостаточно прав для чтения/записи в $PORT." >&2
    echo "Попробуйте запустить скрипт с sudo или добавьте пользователя в группу 'dialout' (или аналогичную):" >&2
    echo "sudo usermod -a -G dialout \$USER" >&2
    echo "После этого может потребоваться перезайти в систему." >&2
    exit 1
fi
NN=$INITIAL_VOLUME
if [[ $NN -lt 1 ]]; then NN=1; fi
if [[ $NN -gt 99 ]]; then NN=99; fi

echo "Инициализация порта $PORT со скоростью $BAUD_RATE..."
echo "Начальная громкость: $(printf "%02d" $NN)"
echo "Ожидание команд VP\\r (Volume+) или VM\\r (Volume-)..."
echo "Нажмите Ctrl+C для выхода."
echo "--- Лог приема ---"
stty_orig=$(stty -g -F "$PORT")
stty -F "$PORT" "$BAUD_RATE" raw -echo cs8 -cstopb -parenb min 1 time 0
if [[ $? -ne 0 ]]; then
    echo "Ошибка: Не удалось настроить порт $PORT" >&2
    exit 1
fi
cleanup() {
    echo -e "\nВосстановление настроек порта $PORT..."
    stty -F "$PORT" "$stty_orig"
    echo "Скрипт завершен."
    exit 0
}
trap cleanup SIGINT SIGTERM EXIT
exec 3<> "$PORT"
while true; do
    if read -r -n 1 -t 1 char <&3; then
        printf "%s" "$char"
        buffer+="$char"
        if [[ "$char" == $'\r' ]]; then
            command="${buffer%$'\r'}"
             printf " [Команда: %s]\n" "$command"
            response="" 
            case "$command" in
                "VP")
                    if [[ $NN -lt 99 ]]; then
                        ((NN++))
                        echo "Громкость увеличена до: $(printf "%02d" $NN)"
                    else
                        echo "Громкость на максимуме (99)."
                    fi
                    NN_formatted=$(printf "%02d" $NN)
                    response=$'\r'"VOLUME    $NN_formatted"$'\r'
                    ;;
                "VM")
                    if [[ $NN -gt 1 ]]; then
                        ((NN--))
                        echo "Громкость уменьшена до: $(printf "%02d" $NN)"
                    else
                        echo "Громкость на минимуме (01)."
                    fi
                    NN_formatted=$(printf "%02d" $NN)
                    response=$'\r'"VOLUME    $NN_formatted"$'\r'
                    ;;
                VN[0-9][0-9]) 
	                nn="${command:2:2}" # Извлекаем значение nn
	                   if [[ "$nn" =~ ^[0-9]{2}$ && "$nn" -ge 1 && "$nn" -le 99 ]]; then
	                     NN="$nn" 
	                     echo "Громкость установлена на: $(printf "%02d" $NN)"
	                   else
	                     echo "Некорректное значение для команды VN: $nn"
	                   fi
	                  response=$'\r'"VOLUME    $NN"$'\r'
	                   ;;
                *)
                    ;;
            esac
            if [[ -n "$response" ]]; then
                printf "%s" "$response" >&3
                echo "Отправлен ответ: VOLUME    $(printf "%02d" $NN)"
            fi
            buffer=""
        fi
    else
         : 
    fi
done
exec 3>&-
cleanup
