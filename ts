sed -i 's|gov [0-9]* taskset|gov 2000 taskset|; s|taskset -c [0-9-]* ||; s|\./\$CUSTOM_MINERBIN|gov 2000\ntaskset -c 1-27 \./\$CUSTOM_MINERBIN|' /hive/miners/custom/golden-miner/h-run.sh
