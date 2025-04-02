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

## Flow 2: Compaction

After Iceberg tables are created in last test, insert a few rows using `spark-sql`
```shell
INSERT INTO demo.clickhouse.trips VALUES
(1, TIMESTAMP '2023-06-01 08:15:00', TIMESTAMP '2023-06-01 08:30:00', -73.9857, 40.7484, -73.9819, 40.7433, 1, 2.1, 10.5, 0.5, 2.0, 0.0, 13.0, 1, 'Midtown', 'Chelsea'),
(2, TIMESTAMP '2023-06-01 09:10:00', TIMESTAMP '2023-06-01 09:25:00', -73.9822, 40.7527, -73.9711, 40.7612, 2, 3.4, 14.0, 1.0, 1.5, 0.0, 16.5, 2, 'Times Square', 'Upper East Side'),
(3, TIMESTAMP '2023-06-01 10:45:00', TIMESTAMP '2023-06-01 11:10:00', -73.9948, 40.7505, -74.0059, 40.7453, 1, 1.8, 8.0, 0.5, 1.0, 0.0, 9.5, 3, 'Penn Station', 'Meatpacking'),
(4, TIMESTAMP '2023-06-01 12:00:00', TIMESTAMP '2023-06-01 12:25:00', -73.9681, 40.7853, -73.9581, 40.8001, 3, 4.2, 18.0, 1.5, 2.5, 0.0, 22.0, 1, 'Upper East Side', 'Harlem'),
(5, TIMESTAMP '2023-06-01 13:30:00', TIMESTAMP '2023-06-01 13:50:00', -73.9772, 40.7520, -73.9690, 40.7601, 2, 2.0, 9.0, 0.5, 1.2, 0.0, 10.7, 2, 'Midtown East', 'Turtle Bay'),
(6, TIMESTAMP '2023-06-01 14:15:00', TIMESTAMP '2023-06-01 14:40:00', -73.9915, 40.7301, -73.9854, 40.7441, 1, 2.9, 11.0, 0.5, 2.0, 0.0, 13.5, 3, 'East Village', 'Gramercy'),
(7, TIMESTAMP '2023-06-01 15:45:00', TIMESTAMP '2023-06-01 16:05:00', -73.9849, 40.7392, -73.9811, 40.7503, 1, 1.5, 7.0, 0.5, 1.0, 0.0, 8.5, 1, 'Flatiron', 'Kips Bay'),
(8, TIMESTAMP '2023-06-01 17:10:00', TIMESTAMP '2023-06-01 17:35:00', -73.9715, 40.7643, -73.9650, 40.7751, 2, 3.2, 13.0, 1.0, 2.2, 0.0, 16.2, 4, 'Lincoln Square', 'Central Park'),
(9, TIMESTAMP '2023-06-01 18:50:00', TIMESTAMP '2023-06-01 19:15:00', -73.9610, 40.7777, -73.9511, 40.7888, 1, 2.5, 10.0, 0.5, 1.3, 0.0, 11.8, 1, 'Upper West Side', 'Harlem'),
(10, TIMESTAMP '2023-06-01 20:30:00', TIMESTAMP '2023-06-01 20:50:00', -73.9810, 40.7333, -73.9777, 40.7433, 2, 2.1, 9.5, 0.5, 1.8, 0.0, 11.8, 2, 'Greenwich Village', 'Chelsea');
```

Now, run the compaction call
```shell
CALL demo.system.rewrite_data_files('demo.clickhouse.trips');
```

You will be able to see a new parquet file created that has compacted the previous multiple parquet files in S3.
