# Benchmarking pg_mooncake for an OLAP Use Case

## **Introduction**

Benchmarking **pg_mooncake**, a Postgres extension for columnar storage and vectorized execution, for an **OLAP (Online Analytical Processing) use case** serves as a critical performance evaluation. The goal is to demonstrate how pg_mooncake enhances PostgreSQL's analytical query performance by leveraging:

- Columnar storage using Iceberg or Delta Lake tables
- Vectorized execution engine (DuckDB-powered)
- Seamless integration with local and cloud storage
- Advanced analytics capabilities

This analysis helps understand how pg_mooncake transforms PostgreSQL into a high-performance analytical database platform.

## **Methodology**

We used **ClickBench pg_mooncake** benchmark ([GitHub](https://github.com/ClickHouse/ClickBench/tree/main/pg_mooncake)) for performance testing, utilizing a Docker-based setup for consistent and reproducible results.

### **Benchmark Environment**

- **Deployment Method:** Docker container
- **Docker Image:** `mooncakelabs/pg_mooncake`
- **Dataset:** `hits.parquet` from ClickBench
- **Data Format:** Parquet (columnar storage format)

Key benchmark script components:
```sh
# Docker run command
docker run -d --name pg_mooncake -p 5432:5432 \
    -e POSTGRES_HOST_AUTH_METHOD=trust \
    -v ./hits.parquet:/tmp/hits.parquet \
    mooncakelabs/pg_mooncake

# Dataset preparation
wget https://datasets.clickhouse.com/hits_compatible/athena/hits.parquet

# Enable pg_mooncake extension
psql -c "CREATE EXTENSION pg_mooncake;"

# Create columnstore table
psql -c "CREATE TABLE hits USING columnstore AS SELECT * FROM parquet_scan('/tmp/hits.parquet');"
```

The benchmark includes **43 queries** that test pg_mooncake's performance on:
- **Complex aggregations**
- **Text search**
- **Multi-source data analytics**
- **Storage-efficient querying**


## **Benchmark Machine Specifications**

The entire benchmark was run on a virtual machine with the following specifications:

| Component  | Specification  |
|------------|---------------|
| **CPU**    | 16 vCPUs      |
| **Memory** | 32 GB         |
| **Storage**| 500 GB        |



## **Results**

### **Table Size**

Storage breakdown for the pg_mooncake Docker container:

```sh
# Docker container storage analysis
/var/lib/postgresql/data: 14,698,261,637 bytes
/tmp/hits.parquet:        14,779,976,446 bytes
Total:                    29,478,238,083 bytes

# Parquet file size: ~14.8 GB
# PostgreSQL data size: ~14.7 GB
```


### **Query Performance**
| Query | Run 1 (seconds) | Run 2 (seconds) | Run 3 (seconds) |
|-------|----------------|----------------|----------------|
| SELECT COUNT(*) FROM hits; | 0.715031 | 0.273308 | 0.263852 |
| SELECT COUNT(*) FROM hits WHERE AdvEngineID <> 0; | 0.69146 | 0.260753 | 0.250867 |
| SELECT SUM(AdvEngineID), COUNT(*), AVG(ResolutionWidth) FROM hits; | 0.766147 | 0.286573 | 0.264287 |
| SELECT AVG(UserID) FROM hits; | 0.829435 | 0.278332 | 0.266382 |
| SELECT COUNT(DISTINCT UserID) FROM hits; | 1.07649 | 0.464777 | 0.475721 |
| SELECT COUNT(DISTINCT SearchPhrase) FROM hits; | 1.36986 | 0.563037 | 0.553916 |
| SELECT MIN(EventDate), MAX(EventDate) FROM hits; | 0.702037 | 0.241161 | 0.240044 |
| SELECT AdvEngineID, COUNT(*) FROM hits WHERE AdvEngineID <> 0 GROUP BY AdvEngineID ORDER BY COUNT(*) DESC; | 0.689842 | 0.246233 | 0.249384 |
| SELECT RegionID, COUNT(DISTINCT UserID) AS u FROM hits GROUP BY RegionID ORDER BY u DESC LIMIT 10; | 1.33963 | 0.504571 | 0.578472 |
| SELECT RegionID, SUM(AdvEngineID), COUNT(*) AS c, AVG(ResolutionWidth), COUNT(DISTINCT UserID) FROM hits GROUP BY RegionID ORDER BY c DESC LIMIT 10; | 1.92001 | 0.699657 | 0.735502 |
| SELECT MobilePhoneModel, COUNT(DISTINCT UserID) AS u FROM hits WHERE MobilePhoneModel <> '' GROUP BY MobilePhoneModel ORDER BY u DESC LIMIT 10; | 0.910795 | 0.301355 | 0.287154 |
| SELECT MobilePhone, MobilePhoneModel, COUNT(DISTINCT UserID) AS u FROM hits WHERE MobilePhoneModel <> '' GROUP BY MobilePhone, MobilePhoneModel ORDER BY u DESC LIMIT 10; | 1.0052 | 0.304407 | 0.303963 |
| SELECT SearchPhrase, COUNT(*) AS c FROM hits WHERE SearchPhrase <> '' GROUP BY SearchPhrase ORDER BY c DESC LIMIT 10; | 1.33525 | 0.505976 | 0.521863 |
| SELECT SearchPhrase, COUNT(DISTINCT UserID) AS u FROM hits WHERE SearchPhrase <> '' GROUP BY SearchPhrase ORDER BY u DESC LIMIT 10; | 1.97965 | 0.790764 | 0.796082 |
| SELECT SearchEngineID, SearchPhrase, COUNT(*) AS c FROM hits WHERE SearchPhrase <> '' GROUP BY SearchEngineID, SearchPhrase ORDER BY c DESC LIMIT 10; | 1.4623 | 0.593997 | 0.614626 |
| SELECT UserID, COUNT(*) FROM hits GROUP BY UserID ORDER BY COUNT(*) DESC LIMIT 10; | 1.09135 | 0.453449 | 0.474405 |
| SELECT UserID, SearchPhrase, COUNT(*) FROM hits GROUP BY UserID, SearchPhrase ORDER BY COUNT(*) DESC LIMIT 10; | 2.18485 | 1.18249 | 1.13416 |
| SELECT UserID, SearchPhrase, COUNT(*) FROM hits GROUP BY UserID, SearchPhrase LIMIT 10; | 1.93627 | 1.04923 | 1.03469 |
| SELECT UserID, extract(minute FROM EventTime) AS m, SearchPhrase, COUNT(*) FROM hits GROUP BY UserID, m, SearchPhrase ORDER BY COUNT(*) DESC LIMIT 10; | 3.62828 | 2.38597 | 2.3171 |
| SELECT UserID FROM hits WHERE UserID = 435090932899640449; | 0.708148 | 0.246417 | 0.233862 |
| SELECT COUNT(*) FROM hits WHERE URL LIKE '%google%'; | 2.76259 | 1.24435 | 1.22815 |
| SELECT SearchPhrase, MIN(URL), COUNT(*) AS c FROM hits WHERE URL LIKE '%google%' AND SearchPhrase <> '' GROUP BY SearchPhrase ORDER BY c DESC LIMIT 10; | 3.19203 | 1.12066 | 1.12744 |
| SELECT SearchPhrase, MIN(URL), MIN(Title), COUNT(*) AS c, COUNT(DISTINCT UserID) FROM hits WHERE Title LIKE '%Google%' AND URL NOT LIKE '%.google.%' AND SearchPhrase <> '' GROUP BY SearchPhrase ORDER BY c DESC LIMIT 10; | 4.41717 | 1.90286 | 1.8917 |
| SELECT * FROM hits WHERE URL LIKE '%google%' ORDER BY EventTime LIMIT 10; | 10.7985 | 8.24611 | 8.22931 |
| SELECT SearchPhrase FROM hits WHERE SearchPhrase <> '' ORDER BY EventTime LIMIT 10; | 1.90954 | 0.425532 | 0.426398 |
| SELECT SearchPhrase FROM hits WHERE SearchPhrase <> '' ORDER BY SearchPhrase LIMIT 10; | 1.15307 | 0.351918 | 0.341515 |
| SELECT SearchPhrase FROM hits WHERE SearchPhrase <> '' ORDER BY EventTime, SearchPhrase LIMIT 10; | 1.83772 | 0.438489 | 0.426018 |
| SELECT CounterID, AVG(length(URL)) AS l, COUNT(*) AS c FROM hits WHERE URL <> '' GROUP BY CounterID HAVING COUNT(*) > 100000 ORDER BY l DESC LIMIT 25; | 2.98378 | 1.30706 | 1.29614 |
| SELECT REGEXP_REPLACE(Referer, '^https?://(?:www\.)?([^/]+)/.*$', '\1') AS k, AVG(length(Referer)) AS l, COUNT(*) AS c, MIN(Referer) FROM hits WHERE Referer <> '' GROUP BY k HAVING COUNT(*) > 100000 ORDER BY l DESC LIMIT 25; | 5.1207 | 4.06316 | 4.0167 |
| SELECT SUM(ResolutionWidth), SUM(ResolutionWidth + 1), SUM(ResolutionWidth + 2), SUM(ResolutionWidth + 3), SUM(ResolutionWidth + 4), SUM(ResolutionWidth + 5), SUM(ResolutionWidth + 6), SUM(ResolutionWidth + 7), SUM(ResolutionWidth + 8), SUM(ResolutionWidth + 9), SUM(ResolutionWidth + 10), SUM(ResolutionWidth + 11), SUM(ResolutionWidth + 12), SUM(ResolutionWidth + 13), SUM(ResolutionWidth + 14), SUM(ResolutionWidth + 15), SUM(ResolutionWidth + 16), SUM(ResolutionWidth + 17), SUM(ResolutionWidth + 18), SUM(ResolutionWidth + 19), SUM(ResolutionWidth + 20), SUM(ResolutionWidth + 21), SUM(ResolutionWidth + 22), SUM(ResolutionWidth + 23), SUM(ResolutionWidth + 24), SUM(ResolutionWidth + 25), SUM(ResolutionWidth + 26), SUM(ResolutionWidth + 27), SUM(ResolutionWidth + 28), SUM(ResolutionWidth + 29), SUM(ResolutionWidth + 30), SUM(ResolutionWidth + 31), SUM(ResolutionWidth + 32), SUM(ResolutionWidth + 33), SUM(ResolutionWidth + 34), SUM(ResolutionWidth + 35), SUM(ResolutionWidth + 36), SUM(ResolutionWidth + 37), SUM(ResolutionWidth + 38), SUM(ResolutionWidth + 39), SUM(ResolutionWidth + 40), SUM(ResolutionWidth + 41), SUM(ResolutionWidth + 42), SUM(ResolutionWidth + 43), SUM(ResolutionWidth + 44), SUM(ResolutionWidth + 45), SUM(ResolutionWidth + 46), SUM(ResolutionWidth + 47), SUM(ResolutionWidth + 48), SUM(ResolutionWidth + 49), SUM(ResolutionWidth + 50), SUM(ResolutionWidth + 51), SUM(ResolutionWidth + 52), SUM(ResolutionWidth + 53), SUM(ResolutionWidth + 54), SUM(ResolutionWidth + 55), SUM(ResolutionWidth + 56), SUM(ResolutionWidth + 57), SUM(ResolutionWidth + 58), SUM(ResolutionWidth + 59), SUM(ResolutionWidth + 60), SUM(ResolutionWidth + 61), SUM(ResolutionWidth + 62), SUM(ResolutionWidth + 63), SUM(ResolutionWidth + 64), SUM(ResolutionWidth + 65), SUM(ResolutionWidth + 66), SUM(ResolutionWidth + 67), SUM(ResolutionWidth + 68), SUM(ResolutionWidth + 69), SUM(ResolutionWidth + 70), SUM(ResolutionWidth + 71), SUM(ResolutionWidth + 72), SUM(ResolutionWidth + 73), SUM(ResolutionWidth + 74), SUM(ResolutionWidth + 75), SUM(ResolutionWidth + 76), SUM(ResolutionWidth + 77), SUM(ResolutionWidth + 78), SUM(ResolutionWidth + 79), SUM(ResolutionWidth + 80), SUM(ResolutionWidth + 81), SUM(ResolutionWidth + 82), SUM(ResolutionWidth + 83), SUM(ResolutionWidth + 84), SUM(ResolutionWidth + 85), SUM(ResolutionWidth + 86), SUM(ResolutionWidth + 87), SUM(ResolutionWidth + 88), SUM(ResolutionWidth + 89) FROM hits; | 3.11582 | 2.59802 | 2.58808 |
| SELECT SearchEngineID, ClientIP, COUNT(*) AS c, SUM(IsRefresh), AVG(ResolutionWidth) FROM hits WHERE SearchPhrase <> '' GROUP BY SearchEngineID, ClientIP ORDER BY c DESC LIMIT 10; | 1.95885 | 0.633494 | 0.633022 |
| SELECT WatchID, ClientIP, COUNT(*) AS c, SUM(IsRefresh), AVG(ResolutionWidth) FROM hits WHERE SearchPhrase <> '' GROUP BY WatchID, ClientIP ORDER BY c DESC LIMIT 10; | 2.65821 | 0.673572 | 0.638082 |
| SELECT WatchID, ClientIP, COUNT(*) AS c, SUM(IsRefresh), AVG(ResolutionWidth) FROM hits GROUP BY WatchID, ClientIP ORDER BY c DESC LIMIT 10; | 6.53265 | 5.32153 | 5.14941 |
| SELECT URL, COUNT(*) AS c FROM hits GROUP BY URL ORDER BY c DESC LIMIT 10; | 6.06495 | 4.61858 | 4.91464 |
| SELECT 1, URL, COUNT(*) AS c FROM hits GROUP BY 1, URL ORDER BY c DESC LIMIT 10; | 6.10825 | 4.66579 | 4.53988 |
| SELECT ClientIP, ClientIP - 1, ClientIP - 2, ClientIP - 3, COUNT(*) AS c FROM hits GROUP BY ClientIP, ClientIP - 1, ClientIP - 2, ClientIP - 3 ORDER BY c DESC LIMIT 10; | 1.26253 | 0.592772 | 0.555177 |
| SELECT URL, COUNT(*) AS PageViews FROM hits WHERE CounterID = 62 AND EventDate >= '2013-07-01' AND EventDate <= '2013-07-31' AND DontCountHits = 0 AND IsRefresh = 0 AND URL <> '' GROUP BY URL ORDER BY PageViews DESC LIMIT 10; | 0.532916 | 0.077698 | 0.077185 |
| SELECT Title, COUNT(*) AS PageViews FROM hits WHERE CounterID = 62 AND EventDate >= '2013-07-01' AND EventDate <= '2013-07-31' AND DontCountHits = 0 AND IsRefresh = 0 AND Title <> '' GROUP BY Title ORDER BY PageViews DESC LIMIT 10; | 0.480084 | 0.055298 | 0.058033 |
| SELECT URL, COUNT(*) AS PageViews FROM hits WHERE CounterID = 62 AND EventDate >= '2013-07-01' AND EventDate <= '2013-07-31' AND IsRefresh = 0 AND IsLink <> 0 AND IsDownload = 0 GROUP BY URL ORDER BY PageViews DESC LIMIT 10 OFFSET 1000; | 0.471862 | 0.066315 | 0.074293 |
| SELECT TraficSourceID, SearchEngineID, AdvEngineID, CASE WHEN (SearchEngineID = 0 AND AdvEngineID = 0) THEN Referer ELSE '' END AS Src, URL AS Dst, COUNT(*) AS PageViews FROM hits WHERE CounterID = 62 AND EventDate >= '2013-07-01' AND EventDate <= '2013-07-31' AND IsRefresh = 0 GROUP BY TraficSourceID, SearchEngineID, AdvEngineID, Src, Dst ORDER BY PageViews DESC LIMIT 10 OFFSET 1000; | 0.534725 | 0.153167 | 0.11616 |
| SELECT URLHash, EventDate, COUNT(*) AS PageViews FROM hits WHERE CounterID = 62 AND EventDate >= '2013-07-01' AND EventDate <= '2013-07-31' AND IsRefresh = 0 AND TraficSourceID IN (-1, 6) AND RefererHash = 3594120000172545465 GROUP BY URLHash, EventDate ORDER BY PageViews DESC LIMIT 10 OFFSET 100; | 0.485633 | 0.046541 | 0.046596 |
| SELECT WindowClientWidth, WindowClientHeight, COUNT(*) AS PageViews FROM hits WHERE CounterID = 62 AND EventDate >= '2013-07-01' AND EventDate <= '2013-07-31' AND IsRefresh = 0 AND DontCountHits = 0 AND URLHash = 2868770270353813622 GROUP BY WindowClientWidth, WindowClientHeight ORDER BY PageViews DESC LIMIT 10 OFFSET 10000; | 0.439417 | 0.040227 | 0.041005 |
| SELECT DATE_TRUNC('minute', EventTime) AS M, COUNT(*) AS PageViews FROM hits WHERE CounterID = 62 AND EventDate >= '2013-07-14' AND EventDate <= '2013-07-15' AND IsRefresh = 0 AND DontCountHits = 0 GROUP BY DATE_TRUNC('minute', EventTime) ORDER BY DATE_TRUNC('minute', EventTime) LIMIT 10 OFFSET 1000; | 0.458626 | 0.03865 | 0.03712 |



---
This benchmark demonstrates pg_mooncake's potential to transform PostgreSQL into a high-performance analytical database platform. 🥮