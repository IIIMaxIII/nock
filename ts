sed -i 's|taskset -c [0-9-]* ||; s|\./\$CUSTOM_MINERBIN|taskset -c 1-27 \./\$CUSTOM_MINERBIN|' /hive/miners/custom/golden-miner/h-run.sh
