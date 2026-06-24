awk -F, 'NR>1 {count[$14]++} END {for (c in count) print c, count[c]}' dataset_features.csv
