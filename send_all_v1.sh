#!/bin/bash
set -euo pipefail

# Конфиг
LOCAL_PK="2c9rAQWHo1GzAnFkHT5jDzcenEnidxG7G7akmuWHUk54op9GaUzeyvMXEtP2TTzgYzbZcypEnAfVnLjexmSP4HzAphnX6kbWPGYg1awKeG6E3NV8C7bQmen6a28mxmtEPN4G"
RECIPIENT_PK="3WYJJDBU2YTyYco84JH3RbF5aAKEAdNZMkKnKXtsJMxsLcSqHTyBXgXXDiHsiVsKvJCcx2SAbbiG3gaZZxHLrAxdkW5CCjQWvKNpzraY75SikKiJdU2qs6SkvvjXSvW6utT6"
FEE=111
SEP="-------------------------------------------------------------------------------------------------------------------------------------------------"

pause() {
    echo "➤ Нажмите ENTER или ПРОБЕЛ для продолжения (Ctrl+C для выхода)..."
    while true; do
        read -rsn1 key
        [[ -z "$key" || "$key" == " " ]] && break
    done
    echo
}

# 1. Получаем инфу о нотах
echo -e "\n🚦 ШАГ 1: Получение информации о нотах"
CMD1="./nockchain-wallet list-notes-by-address \"$LOCAL_PK\""
echo "🔧 Команда: $CMD1"

NOTE_INFO=$(eval "$CMD1" | tr -d '\000')
echo "$SEP"
echo "$NOTE_INFO"
echo "$SEP"

# Извлекаем все имена нот и балансы
NOTE_NAMES=()
BALANCES=()
TOTAL_BALANCE=0

# Парсим вывод, извлекая Name и Assets для каждой ноты
while IFS= read -r line; do
    if [[ "$line" =~ "Name:" ]]; then
        note_name=$(echo "$line" | sed -n 's/.*Name: *\[\(.*\)\].*/\1/p')
        if [[ -n "$note_name" ]]; then
            NOTE_NAMES+=("$note_name")
        fi
    elif [[ "$line" =~ "Assets:" ]]; then
        balance=$(echo "$line" | sed -n 's/.*Assets: *\([0-9]\+\).*/\1/p')
        if [[ -n "$balance" ]]; then
            BALANCES+=("$balance")
            TOTAL_BALANCE=$((TOTAL_BALANCE + balance))
        fi
    fi
done <<< "$NOTE_INFO"

if [[ ${#NOTE_NAMES[@]} -eq 0 || ${#BALANCES[@]} -eq 0 ]]; then
    echo "❌ Не удалось извлечь данные о нотах"
    exit 1
fi

# Проверяем, что количество нот и балансов совпадает
if [[ ${#NOTE_NAMES[@]} -ne ${#BALANCES[@]} ]]; then
    echo "❌ Несоответствие количества нот и балансов"
    exit 1
fi

echo "✅ Найдено нот: ${#NOTE_NAMES[@]}"
for i in "${!NOTE_NAMES[@]}"; do
    coins=$(echo "scale=2; ${BALANCES[$i]} / 65536" | bc -l)
    echo "   📝 Нота $((i+1)): ${NOTE_NAMES[$i]}"
    echo "   💰 Баланс: ${BALANCES[$i]} ($coins монет)"
done

TOTAL_COINS=$(echo "scale=2; $TOTAL_BALANCE / 65536" | bc -l)
echo "💰 ОБЩИЙ БАЛАНС: $TOTAL_BALANCE ($TOTAL_COINS монет)"

# Рассчитываем сумму для отправки
SEND_AMOUNT=$((TOTAL_BALANCE - FEE))
if (( SEND_AMOUNT <= 0 )); then
    echo "❌ Недостаточно средств (Общий баланс=$TOTAL_BALANCE, Комиссия=$FEE)"
    exit 1
fi

echo "📊 Будет отправлено: $SEND_AMOUNT (комиссия $FEE)"
echo "📝 Используются ноты: ${#NOTE_NAMES[@]} шт."

# Формируем список нот для транзакции
NAMES_STRING=""
for note_name in "${NOTE_NAMES[@]}"; do
    if [[ -n "$NAMES_STRING" ]]; then
        NAMES_STRING="${NAMES_STRING},[${note_name}]"
    else
        NAMES_STRING="[${note_name}]"
    fi
done

# echo "📋 Список нот для транзакции:"
# echo "$NAMES_STRING"
pause

# 4. Создаём транзакцию
echo "🚦 ШАГ 2: Создание транзакции..."
#echo "Используемые ноты: ${#NOTE_NAMES[@]}"
#echo "Общая сумма: $TOTAL_BALANCE"
#echo "Сумма отправки: $SEND_AMOUNT"
#echo "Комиссия: $FEE"

CMD2="./nockchain-wallet create-tx --names \"$NAMES_STRING\" --recipients \"[1 $RECIPIENT_PK]\" --gifts $SEND_AMOUNT --fee $FEE"
echo "🔧 Команда: $CMD2"

TX_OUTPUT=$(eval "$CMD2" | tr -d '\000')

echo "$SEP"
echo "$TX_OUTPUT"
echo "$SEP"

TX_NAME=$(echo "$TX_OUTPUT" | awk '/Name:/ {print $2}')
TX_FILE="txs/${TX_NAME}.tx"

if [[ -z "$TX_NAME" ]]; then
    echo "❌ Ошибка: не удалось извлечь имя транзакции"
    exit 1
fi

if [[ ! -f "$TX_FILE" ]]; then
    echo "❌ Ошибка: файл транзакции не найден: $TX_FILE"
    echo "Проверьте наличие директории 'txs/' и права доступа"
    exit 1
fi

echo "✅ Транзакция $TX_NAME создана ($TX_FILE)"
pause

# 5. Отправляем
echo "🚦 ШАГ 3: Отправка транзакции..."
CMD3="./nockchain-wallet send-tx \"$TX_FILE\""
echo "🔧 Команда: $CMD3"

SEND_OUTPUT=$(eval "$CMD3" | tr -d '\000')

echo "$SEP"
echo "$SEND_OUTPUT"
echo "$SEP"

echo "🎉 УСПЕХ: отправлено $SEND_AMOUNT монет (комиссия $FEE) с использованием ${#NOTE_NAMES[@]} нот"
