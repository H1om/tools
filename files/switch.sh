#!/bin/bash


: ' INFA
1) КОМАНДА ДЛЯ CRONTAB
*/5 * * * * /etc/script/switch.sh

2) ВЫДАТЬ ПРАВА ДЛЯ ФАЙЛА
chmod +x /etc/script/switch.sh

3) ЗАПУСК ЧЕРЕЗ КОНСОЛЬ
sh /etc/script/switch.sh
'

BOT_TOKEN="1970248816:AAFcWPoqqMyZgMnz5jEw3ItSh_SAIyrs3vc"
CHAT_ID="435607916"

CONFIG_FILE="/etc/script/switch_config.txt"
ssid_config="config.json"

model=$(ubus call system board | jsonfilter -e '@.model')
if [ "$model" == "Xiaomi Mi Router 3G" ]; then

  echo '[
  {"name": "Fisher_5G",       "values": ["2garin2000",  "Fisher_5G",        "78:24:AF:98:B4:AC",  "radio1" ] },
  {"name": "TP_Link_9FE9_5G", "values": ["99075910",    "TP-Link_9FE9_5G",  "10:27:F5:B8:9F:EB",  "radio1" ] },
  {"name": "Nazarius",        "values": ["Suzuki1978",  "Nazarius",         "C0:A5:DD:08:D3:6C",  "radio0" ] }, 
  {"name": "netis_5B0443",    "values": ["password13",  "netis_5B0443",     "04:5E:A4:5B:04:43",  "radio0" ] }
  ]' > "$ssid_config"
elif [ "$model" == "Xiaomi Mi Router R3" ]; then

  echo '[
  {"name": "TP_Link_7AC0",      "values": ["70736564",      "TP-Link_7AC0",     "78:24:AF:98:B4:AC",  "radio1" ] },
  {"name": "All_DR",            "values": ["1qaz2wsx3edc",  "All_DR",           "10:27:F5:B8:9F:EB",  "radio1" ] },
  {"name": "pasha118",          "values": ["54169999",      "pasha118",         "C0:A5:DD:08:D3:6C",  "radio0" ] }, 
  {"name": "Kyivstar_tatiana",  "values": ["55879117",      "Kyivstar_tatiana", "04:5E:A4:5B:04:43",  "radio0" ] }
  ]' > "$ssid_config"
else
	echo "[ERROR] Ошибка в распознавании модели. Сверьте данные: $model"
fi


FirstSSID=$(jq -r '.[0].name' "$ssid_config") # Узнаем имя приоритетной сети

GetDisabled=$(uci get wireless.$FirstSSID.disabled) # Статус сети, выключена или отключена

switch_ssid() { # Функция для переключения SSID
  local value="$1"  # Получаем значение аргумента

  for device in $(jq -r '.[] | @base64' "$ssid_config"); do
    decoded_device=$(echo "$device" | base64 -d)
    name=$(echo "$decoded_device" | jq -r '.name')
	  uci set wireless.$name.disabled='1'
    uci commit wireless
  done

  for device in $(jq -r '.[] | @base64' "$ssid_config"); do
    decoded_device=$(echo "$device" | base64 -d)
    ssid=$(echo "$decoded_device" | jq -r '.name')
    
    echo "Подключаюсь к сети: $ssid"

    uci set wireless.$ssid.disabled='0'
    uci commit wireless

    wifi up

    sleep 30 # Ждем, пока роутер подключится к беспроводной сети

    if check_internet; then # Проверяем доступность интернета
      echo "Интернет доступен, остаюсь на $ssid"

	  if [ "$value" == "1" ] && [ "$FirstSSID" == "$ssid" ]; then
		  send_telegram "[Смена на приоритетную сеть] : $ssid. Router: $model" 
      else
		  send_telegram "[Смена сети]: $ssid. Router: $model"
	  fi

      exit 0
    fi

    echo "Нет интернета или нет подключения к $ssid, пробуем дальше..."
    uci set wireless.$ssid.disabled='1'
    uci commit wireless
  done

  echo "[ERROR] Не удалось подключиться к сети Wi-Fi с доступом в интернет"
  wifi up
}

current_datetime() { # Функция проверки времени
  date +"%Y-%m-%d %H"
}

connect_first_WIFI() { # Переподключение к первому SSID

  current_time=$(echo "$(current_datetime)" | cut -d ' ' -f2 | cut -d ':' -f1) # Узнаем текущий час

  if [ "$GetDisabled" == "1" ] && [ "$current_time" == "14" ]; then

	if [ "$(cat "$CONFIG_FILE")" != "$(current_datetime)" ]; then # Проверка, были ли уже попытки подключения в текущем дне
		echo "Пробую подключится к приоритетной сети..."

		echo "$(current_datetime)" > "$CONFIG_FILE" # Обновляем дату в конфиге
		switch_ssid "1"
	else
		echo "Попытки подключения уже были в текущем дне. Пропускаем переключение."
	fi

  else
	echo "SSID: $FirstSSID Время: $current_time value: $GetDisabled"
  fi
}

check_config() { # Проверка на наличие данных в конфиге

  for device in $(jq -r '.[] | @base64' "$ssid_config"); do
      decoded_device=$(echo "$device" | base64 -d)
      name=$(echo "$decoded_device" | jq -r '.name')
      
      for i in $(seq 1 4); do
          eval "value$i=\$(echo \"\$decoded_device\" | jq -r \".values[$((i-1))]\")"
      done

      if [ "$(uci show wireless | grep -c "$name" )" -eq 0 ]; then

        uci set wireless.$name=wifi-iface
        uci set wireless.$name.device=$value4
        uci set wireless.$name.mode=sta
        uci set wireless.$name.network=wwan
        uci set wireless.$name.ssid=$value2
        uci set wireless.$name.bssid=$value3
        uci set wireless.$name.encryption=psk2
        uci set wireless.$name.key=$value1
        uci set wireless.$name.disabled=1

        echo "[ERROR] $value2 не найден - добавляем.."
      fi
  done

  uci commit wireless
  wifi up
}

check_internet() { # Функция для проверки доступности интернета
  curl -s --head http://example.com | grep "200 OK" > /dev/null;
}

send_telegram() { # Функция для отправки уведомления в Telegram
    local message="$1"
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" -d "chat_id=$CHAT_ID" -d "text=$message"
}

install_module() {
  # Функция для установки модуля
  required_modules="curl base64 jq"

  update_done=false 

  for module in $required_modules; do
    if ! command -v "$module" > /dev/null; then
      echo "[ERROR] $module не установлен, устанавливаю..."

      if [ "$update_done" = false ]; then
        opkg update
        update_done=true
      fi    
      if [ "$module" == "base64" ]; then
          opkg install coreutils-base64
      else
          opkg install "$module"
      fi

      if [ $? -eq 0 ]; then
        echo "[INFO] Установка модуля $module выполнена успешно."
        send_telegram "Установка модуля $module выполнена успешно на: $model"
      else
        echo "[ERROR] Ошибка при установке модуля $module."
      fi
    fi
  done
}

install_module
check_config
: ' '

if ! check_internet; then # Проверяем доступность интернета
  echo "[ERROR] Интернет недоступен. Переключаю SSID..."
  logger "[ERROR] Internet is not available. Switching SSID."
  switch_ssid "0"
else
  connect_first_WIFI
  
  echo "Интернет доступен. Нет необходимости переключать SSID."
fi
