### Queries

Once all the containers are up, we’ll enter a spark-sql prompt to create our table and write.

Source1: https://iceberg.apache.org/spark-quickstart/
Source2: https://www.e6data.com/blog/apache-iceberg-snapshots-time-travel

```shell
docker exec -it spark-iceberg spark-sql
```

Create table using spark sql

```sql
CREATE TABLE demo.nyc.taxis
(
  vendor_id bigint,
  trip_id bigint,
  trip_distance float,
  fare_amount double,
  store_and_fwd_flag string
)
PARTITIONED BY (vendor_id);
```

Write data to table using:

```sql
INSERT INTO demo.nyc.taxis
VALUES (1, 1000371, 1.8, 15.32, 'N'), (2, 1000372, 2.5, 22.15, 'N'), (2, 1000373, 0.9, 9.01, 'N'), (1, 1000374, 8.4, 42.13, 'Y');
```

Reading from table

```sql
SELECT * FROM demo.nyc.taxis;
```


Listing Manifest list:
```sql
select snapshot_id, manifest_list from demo.nyc.taxis.snapshots;
```

Contents of manifest list:
```sql
select * from demo.nyc.taxis.manifests;
```

Contents of manifest file:
```sql
select * from demo.nyc.taxis.files;;
```

List actual data files:
```sql
select * from demo.nyc.taxis.files;
```
### Time travel through snapshots:
You can use snapshot ids with as clause to query the earlier snapshots.

Add a row to create a new snapshot
```sql
INSERT INTO demo.nyc.taxis VALUES (3, 1000671, 2.1, 11.67, 'W');
```

Get the snapshot id using the following query:
```sql
select snapshot_id, manifest_list from demo.nyc.taxis.snapshots;
```

To view snapshot at a given id:
```sql
select * from demo.nyc.taxis version as of 8253356480484172902;
```


