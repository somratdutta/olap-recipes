### Queries
Source1: https://www.e6data.com/blog/iceberg-metadata-evolution-after-compaction

The NYC Yellow Taxi trip data for January and February 2022. You do not need to download the dataset, as it has already been baked into the container stored as parquet files.

Note: This requires a bit more memory so it is advised to increase your colima memory limits.

## Flow 1: Clickhouse -> S3 Parquet

### Step 1: Data from clickhouse tables into S3 as a parquet file

Fire up clickhouse client

```shell
docker exec -it clickhouse clickhouse-client
```
The pre created table is within default database. We will write this table as a parquet file into s3 bucket.

```sql
INSERT INTO FUNCTION s3(
  'http://minio:9000/lakehouse/clickhouse_generated/trips.parquet',
  'admin', 'password',
  'Parquet'
)
SELECT * FROM trips;
```

This parquet file can be then queried using clickhouse itself.

Top 3 rows from parquet file
```sql
SELECT * FROM s3('http://minio:9000/lakehouse/clickhouse_generated/trips.parquet','admin','password') LIMIT 3;
```

### Step 2: Creating iceberg table using this parquet file
Fire up spark sql: For some reason spark sql is not inheriting the configs passed 
in the env variables in docker compose file. Hence we are hard coding it here.

```shell
docker exec -it spark-iceberg spark-sql \
  --conf spark.driver.extraClassPath="/opt/spark-extra-jars/*" \
  --conf spark.executor.extraClassPath="/opt/spark-extra-jars/*" \
  --conf spark.hadoop.fs.s3a.access.key=admin \
  --conf spark.hadoop.fs.s3a.secret.key=password \
  --conf spark.hadoop.fs.s3a.endpoint=http://minio:9000 \
  --conf spark.hadoop.fs.s3a.path.style.access=true
```
Create table
```sql
CREATE TABLE demo.clickhouse.trips (
                                       trip_id             INT,
                                       pickup_datetime     TIMESTAMP,
                                       dropoff_datetime    TIMESTAMP,
                                       pickup_longitude    DOUBLE,
                                       pickup_latitude     DOUBLE,
                                       dropoff_longitude   DOUBLE,
                                       dropoff_latitude    DOUBLE,
                                       passenger_count     INT,
                                       trip_distance       FLOAT,
                                       fare_amount         FLOAT,
                                       extra               FLOAT,
                                       tip_amount          FLOAT,
                                       tolls_amount        FLOAT,
                                       total_amount        FLOAT,
                                       payment_type        STRING,
                                       pickup_ntaname      STRING,
                                       dropoff_ntaname     STRING
) USING ICEBERG
PARTITIONED BY (
    payment_type
);
```

Create a temporary table using this data
```sql
INSERT INTO demo.clickhouse.trips
SELECT * FROM parquet.`s3a://lakehouse/clickhouse_generated/trips.parquet`;
```

Querying back from clickhouse Top 3 rows from iceberg tables

Fire up clickhouse client

```shell
docker exec -it clickhouse clickhouse-client
```

```sql
SELECT count(*) FROM icebergS3('http://minio:9000/lakehouse/clickhouse/trips','admin','password') LIMIT 3;
```