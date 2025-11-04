#!/bin/bash
set -euo pipefail

# Конфиг
LOCAL_PK=""
RECIPIENT_PK=""
FEE=300
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

# Парсим новый формат вывода
current_note=""
current_balance=""

while IFS= read -r line; do
    # Ищем строку с Name (новый формат)
    if [[ "$line" =~ "Name:" ]]; then
        # Извлекаем имя ноты из формата: - Name: [4VMMQKK8BG38MKWLTUv2bnxzzgjiMdhPkUnFrET3fqfEBXLSJzhNgJA 7zLFwvAPWCZGqCTWybmLaySCTPFY8Br3d3UqZKdxvpsYWg83sLxfDFm]
        note_name=$(echo "$line" | sed -n 's/.*Name: \[\([^]]*\)\].*/\1/p')
        if [[ -n "$note_name" ]]; then
            current_note="$note_name"
        fi
    # Ищем строку с Assets (новый формат)
    elif [[ "$line" =~ "Assets" && "$line" =~ "nicks" ]]; then
        # Извлекаем баланс из формата: - Assets (nicks): 95635031
        balance=$(echo "$line" | sed -n 's/.*Assets (nicks): \([0-9]*\).*/\1/p')
        if [[ -n "$balance" && -n "$current_note" ]]; then
            NOTE_NAMES+=("$current_note")
            BALANCES+=("$balance")
            TOTAL_BALANCE=$((TOTAL_BALANCE + balance))
            current_note=""
        fi
    fi
done <<< "$NOTE_INFO"

if [[ ${#NOTE_NAMES[@]} -eq 0 || ${#BALANCES[@]} -eq 0 ]]; then
    echo "❌ Не удалось извлечь данные о нотах"
    echo "⚠️ Возможно, изменился формат вывода команды"
    exit 1
fi

# Проверяем, что количество нот и балансов совпадает
if [[ ${#NOTE_NAMES[@]} -ne ${#BALANCES[@]} ]]; then
    echo "❌ Несоответствие количества нот и балансов"
    echo "⚠️ Найдено нот: ${#NOTE_NAMES[@]}, балансов: ${#BALANCES[@]}"
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

pause

# 2. Создаём транзакцию
echo "🚦 ШАГ 2: Создание транзакции..."
CMD2="./nockchain-wallet create-tx --names \"$NAMES_STRING\" --recipient \"$RECIPIENT_PK:$SEND_AMOUNT\" --fee $FEE"
echo "🔧 Команда: $CMD2"

TX_OUTPUT=$(eval "$CMD2" | tr -d '\000')
echo "$SEP"
echo "$TX_OUTPUT"
echo "$SEP"

# Надёжное извлечение имени транзакции
TX_NAME=$(
    echo "$TX_OUTPUT" \
    | awk '
        /Transaction Information/ {inblock=1; next}
        inblock && /Output Notes/ {exit}
        inblock && /[[:space:]-]+Name:/ {
            # Удаляем всё до "Name:" и пробелы после
            sub(/.*Name:[[:space:]]*/, "", $0)
            # Берём первое "слово" после двоеточия
            print $1
            exit
        }'
)

if [[ -z "$TX_NAME" ]]; then
    echo "❌ Ошибка: не удалось извлечь имя транзакции"
    echo "=== ОТЛАДОЧНЫЙ ВЫВОД ==="
    echo "$TX_OUTPUT"
    echo "=========================="
    exit 1
fi

echo "📋 Извлечённое имя транзакции: '$TX_NAME'"

# Проверяем существование файла транзакции
TX_FILE="./txs/${TX_NAME}.tx"
if [[ ! -f "$TX_FILE" ]]; then
    echo "❌ Ошибка: файл транзакции не найден: $TX_FILE"
    echo "Проверьте наличие директории 'txs/' и права доступа"
    exit 1
fi

echo "✅ Транзакция $TX_NAME создана ($TX_FILE)"
pause

# 3. Отправляем транзакцию
echo "🚦 ШАГ 3: Отправка транзакции..."
CMD3="./nockchain-wallet send-tx ./txs/${TX_NAME}.tx"
echo "🔧 Команда: $CMD3"

SEND_OUTPUT=$(eval "$CMD3" | tr -d '\000')
echo "$SEP"
echo "$SEND_OUTPUT"
echo "$SEP"

echo "🎉 УСПЕХ: отправлено $SEND_AMOUNT монет (комиссия $FEE) с использованием ${#NOTE_NAMES[@]} нот"
