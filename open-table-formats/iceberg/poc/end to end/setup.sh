#!/bin/bash

set -e  # Exit on error

echo "📁 Creating required directories..."
mkdir -p ./lakehouse
mkdir -p ./notebooks
mkdir -p ./minio/data
mkdir -p ./clickhouse/data_import

echo "Copying database setup files..."
cp ./init-clickhouse.sh ./clickhouse
chmod +x ./clickhouse/init-clickhouse.sh

echo "📥 Downloading and extracting dataset..."
BASE_URL="https://datasets-documentation.s3.eu-west-3.amazonaws.com/nyc-taxi"
DATA_IMPORT_DIR="./clickhouse/data_import"
FILES=( "trips_0" )
mkdir -p "$DATA_IMPORT_DIR"

for FILE in "${FILES[@]}"; do
    echo "Downloading $FILE..."
    curl -o "$DATA_IMPORT_DIR/$FILE.gz" "$BASE_URL/$FILE.gz"

    echo "Extracting $FILE..."
    gunzip -c "$DATA_IMPORT_DIR/$FILE" > "$DATA_IMPORT_DIR/$FILE.tsv"
done

echo "🔐 Setting full access permissions..."
sudo chmod -R 777 ./lakehouse
sudo chmod -R 777 ./notebooks
sudo chmod -R 777 ./minio/data
sudo chmod -R 777 ./clickhouse/data_import

echo "🐳 Starting Docker Compose..."
docker-compose up -d

echo "Inserting data into clickhouse table"
docker exec -it clickhouse /bin/sh -c "cd /var/lib/clickhouse && chmod +x ./init-clickhouse.sh && ./init-clickhouse.sh"

