#!/bin/bash

# Usage: ./generate_markdown.sh <queries_file> <results_file>
# Description: This script reads a list of SQL queries from a file and execution times from another file,
# then generates a Markdown table summarizing the execution times for each query.
#
# Example:
# queries.sql:
# SELECT * FROM users;
# SELECT * FROM orders;
#
# results.txt with each run (same as ClickBench output format):
# [0.123,0.115,0.110],
# [0.245,0.238,0.230]
#
# Running:
# ./generate_markdown.sh queries.sql results.txt
#
# Output (query_times.md):
# | Query                | Run 1 (seconds) | Run 2 (seconds) | Run 3 (seconds) |
# |----------------------|----------------|----------------|----------------|
# | SELECT * FROM users; | 0.123          | 0.115          | 0.110          |
# | SELECT * FROM orders;| 0.245          | 0.238          | 0.230          |
# Place this in your benchmark.md file

# Check if correct number of arguments are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <queries_file> <results_file>"
    exit 1
fi

queries_file="$1"
results_file="$2"
output_file="query_times.md"

# Check if files exist
if [ ! -f "$queries_file" ]; then
    echo "Error: Queries file '$queries_file' not found."
    exit 1
fi

if [ ! -f "$results_file" ]; then
    echo "Error: Results file '$results_file' not found."
    exit 1
fi

# Read queries into an array using a while loop
queries=()
while IFS= read -r line || [[ -n "$line" ]]; do
    queries+=("$line")
done < "$queries_file"

# Start the Markdown table
echo "| Query | Run 1 (seconds) | Run 2 (seconds) | Run 3 (seconds) |" > "$output_file"
echo "|-------|----------------|----------------|----------------|" >> "$output_file"

# Read results and process each line
index=0
while IFS= read -r line || [[ -n "$line" ]]; do
    # Remove brackets and split values
    clean_line=$(echo "$line" | tr -d '[]')
    IFS=',' read -r -a times <<< "$clean_line"

    # Get the corresponding query
    query="${queries[$index]}"
    ((index++))

    # Append to Markdown table
    echo "| $query | ${times[0]} | ${times[1]} | ${times[2]} |" >> "$output_file"
done < "$results_file"

echo "Markdown table saved to $output_file"
